# frozen_string_literal: true

# Authored UNRUN in the source phase. Requires the later admitted Map lane;
# native/framework/installed/browser evidence remains separately required.
require_relative 'test_helper'
require 'cgi'

class SourceComprehensionAppTest < Minitest::Test
  include MapTestSupport
  MODEL = 'c' * 64

  class ComprehensionReader
    attr_reader :generation, :manifest, :calls, :closed
    attr_accessor :bad_envelope, :large_file
    def initialize
      @generation, @calls, @closed = MapTestSupport::GENERATION, [], false
      @content = "class Order\n  def label = '<script>雪</script>'\nend\n"
      @fact = { 'id' => MapTestSupport::FACT_ID, 'kind' => 'class', 'name' => 'Order', 'evidence' => 'static',
        'path' => 'order.rb', 'location' => { 'start_line' => 1, 'end_line' => 3, 'start_byte' => 0, 'end_byte' => @content.bytesize - 1 } }
      @model = { 'id' => MODEL, 'kind' => 'rails_model', 'name' => 'Order', 'evidence' => 'runtime', 'path' => nil, 'location' => nil }
      @manifest = { 'files' => [{ 'path' => 'order.rb', 'bytes' => @content.bytesize, 'sha256' => Digest::SHA256.hexdigest(@content) }],
        'coverage' => [{ 'family' => 'source_ownership', 'status' => 'partial' }] }
    end
    def fact_identity(id)
      @calls << [:identity, id]
      { 'generation' => generation, 'fact' => id == MODEL ? @model : @fact }
    end
    def source_comprehension(id, **options)
      @calls << [:comprehension, id, options]
      raise 'Unexpected query budget' unless options[:limit] == 8 && options[:max_bytes] == 32768
      @manifest['files'][0]['bytes'] = 65_537 if large_file
      { 'version' => 1, 'generation' => bad_envelope ? 'd' * 64 : generation, 'family' => options.fetch(:family), 'model' => @model,
        'owner' => 'Order', 'composition' => 'identified_contributions', 'source_runtime_coherence' => 'unknown',
        'ownership_status' => 'unique_label_candidate_binding_unknown', 'owners' => [], 'semantics' => 'Binding and execution unknown.',
        'coverage' => { 'returned' => 1, 'candidate_matches_seen' => 1, 'range_complete' => true, 'scope' => 'saved definition' },
        'observed_only' => [], 'continuation' => nil, 'contributions' => [{ 'fact' => @fact, 'status' => 'as_written_declaration',
          'source' => { 'operation' => 'source', 'generation' => generation, 'id' => @fact['id'] },
          'callers' => { 'operation' => 'references', 'generation' => generation, 'id' => @fact['id'], 'direction' => 'incoming' } }] }
    end
    def source(id)
      @calls << [:source, id]
      raise 'Runtime Source was read before admission' unless id == @fact['id']
      { 'generation' => generation, 'fact' => @fact, 'content' => @content, 'sha256' => Digest::SHA256.hexdigest(@content) }
    end
    def fact(*) = raise('Full fact expanded')
    def facts = raise('Fact inventory scanned')
    def model_brief(*) = raise('Marginalia queried eagerly')
    def references(*) = raise('References queried eagerly')
    def close = @closed = true
  end

  def query(extra = {})
    URI.encode_www_form({ 'generation' => GENERATION, 'id' => MODEL, 'selection' => MODEL, 'q' => 'Order', 'domain' => 'source' }.merge(extra))
  end

  def test_code_first_page_uses_one_projection_then_admitted_source_without_fact_or_family_fanout
    reader = ComprehensionReader.new
    status, _, html = request(make_app(reader), '/comprehension/contributions', query: query)
    assert_equal 200, status
    assert_equal [:comprehension, :source], reader.calls.map(&:first)
    assert reader.closed
    assert_operator html.index('class="cv codeview"'), :<, html.index('Recorded declarations and reference context')
    assert_includes html, '&lt;script&gt;雪&lt;/script&gt;'
    assert_includes html, '<noscript>'
    href = html.scan(/href="([^"]+)"/).flatten.map { |value| CGI.unescapeHTML(value) }.find { |value| URI(value).fragment == 'L1' }
    params = URI.decode_www_form(URI(href).query).to_h
    assert_equal [GENERATION, FACT_ID, MODEL, 'Order', 'source'], params.values_at('generation', 'id', 'selection', 'q', 'domain')
  end

  def test_runtime_model_source_uses_compact_identity_then_reading_surface
    reader = ComprehensionReader.new
    status, _, html = request(make_app(reader), '/source', query: query)
    assert_equal 200, status
    assert_equal [:identity, :comprehension, :comprehension, :source], reader.calls.map(&:first)
    assert_includes html, 'aria-label="Model reading"'
  end

  def test_bad_scope_access_method_and_query_are_refused_before_reader_factory
    opened = 0
    app = Thistle::Map::App.new(store: '/unused', reader_factory: ->(*) { opened += 1; raise 'Must not open' })
    cursor = JSON.generate(['recorded-v1', GENERATION, Digest::SHA256.hexdigest(JSON.generate(['source_comprehension', MODEL, 'methods'])), 0, 0])
    [query('cursor' => cursor), query('candidate' => '0'), query('generation' => 'd' * 64, 'cursor' => cursor), query('cursor' => '{')].each do |text|
      status, = request(app, '/comprehension/contributions', query: text)
      assert_equal 400, status
    end
    assert_equal 403, request(app, '/comprehension/methods', query: query, env: { 'REMOTE_ADDR' => '192.0.2.1' })[0]
    assert_equal 405, request(app, '/comprehension/methods', query: query, method: 'POST')[0]
    assert_equal 0, opened
  end

  def test_envelope_and_source_admission_precede_reads_and_head_still_closes
    reader = ComprehensionReader.new
    reader.bad_envelope = true
    assert_equal 422, request(make_app(reader), '/comprehension/methods', query: query)[0]
    assert_equal [:comprehension], reader.calls.map(&:first)
    reader = ComprehensionReader.new
    reader.large_file = true
    status, _, html = request(make_app(reader), '/comprehension/contributions', query: query)
    assert_equal 200, status
    assert_includes html, 'source not admitted'
    assert_equal [:comprehension], reader.calls.map(&:first)
    reader = ComprehensionReader.new
    status, headers, body = request(make_app(reader), '/comprehension/contributions', query: query, method: 'HEAD')
    assert_equal 200, status
    assert_empty body
    assert_operator headers.fetch('content-length').to_i, :>, 0
    assert reader.closed
  end
end
