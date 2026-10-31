# frozen_string_literal: true

# Request/view controls. Authored for the admitted Map lane; not a native proof.
require_relative 'test_helper'
require 'cgi'

class InvestigationAppTest < Minitest::Test
  include MapTestSupport

  class CompactReader < Reader
    attr_reader :identity_calls, :closed
    def initialize(*)
      super
      @identity_calls = []
      @closed = false
    end
    def fact_identity(id)
      @identity_calls << id
      fact = @facts.find { |entry| entry['id'] == id } || raise(Thistle::NotFound)
      { 'generation' => generation, 'fact' => fact.slice('id', 'kind', 'name', 'path', 'evidence').merge(
        'location' => { 'start_line' => 2, 'end_line' => 2, 'start_byte' => 11, 'end_byte' => 30 }) }
    end
    def fact(*) = raise('Investigation expanded fact')
    def facts = raise('Investigation scanned inventory')
    def source(*) = raise('Investigation expanded Source')
    def references(*) = raise('Investigation selected references')
    def close = @closed = true
  end

  def query(ids = [FACT_ID])
    URI.encode_www_form('generation' => GENERATION, 'selection' => ids.join(','))
  end

  def test_empty_focus_get_and_head_do_not_require_identity_or_expand_evidence
    %w[GET HEAD].each do |method|
      reader = Reader.new
      closed = false
      reader.define_singleton_method(:close) { closed = true }
      %i[fact facts source references].each do |operation|
        reader.define_singleton_method(operation) { |*| raise 'Empty focus expanded evidence' }
      end
      code, headers, html = request(make_app(reader), '/investigation', query: query([]), method: method)
      assert_equal 200, code
      assert closed
      assert_operator headers.fetch('content-length').to_i, :>, 0
      assert_empty html if method == 'HEAD'
    end
  end

  def test_collection_uses_only_compact_identity_and_keeps_missing_in_order
    reader = CompactReader.new
    code, headers, html = request(make_app(reader), '/investigation', query: query([FACT_ID, 'c' * 64]))
    assert_equal 200, code
    assert_equal [FACT_ID, 'c' * 64], reader.identity_calls
    assert reader.closed
    assert_operator html.index('Demo#show'), :<, html.index('Missing selection')
    assert_includes html, GENERATION
    assert_includes html, 'aria-current="page">Investigation (2)'
    assert_includes html, 'href="#main"'
    assert_includes html, '<noscript>'
    assert_includes headers['content-security-policy'], "connect-src 'none'"
    assert_equal 'no-referrer', headers['referrer-policy']
    assert_equal 'no-store', headers['cache-control']
    href = html.scan(/href="([^"]+)"/).flatten.map { |value| CGI.unescapeHTML(value) }.find { |value| value.start_with?('/source?') }
    params = URI.decode_www_form(URI.parse(href).query).to_h
    assert_equal GENERATION, params['generation']
    assert_equal [FACT_ID, 'c' * 64].join(','), params['selection']
    assert_equal FACT_ID, params['id']
  end

  def test_invalid_collection_refuses_before_reader_open
    opened = 0
    app = Thistle::Map::App.new(store: '/unused', reader_factory: ->(*) { opened += 1; raise 'Must not open' })
    invalid = ['', 'selection=', "selection=#{FACT_ID}", "generation=CURRENT", "generation=#{GENERATION}&selection=../file",
      "#{query}&selection=#{FACT_ID}", query([FACT_ID, FACT_ID]), "#{query}&note=private", "#{query}&q=secret", "#{query}&path=lib/a.rb",
      "#{query}&token=bearer", "#{query}&selection=%FF", "#{query}&bad=%ZZ", 'x' * 4097]
    invalid.each do |text|
      status, = request(app, '/investigation', query: text)
      assert_equal 400, status, text
    end
    oversized = (1..25).map { |id| '%064x' % id }
    assert_equal 422, request(app, '/investigation', query: query(oversized)).first
    assert_equal 0, opened
  end

  def test_access_and_methods_still_precede_reader_selection
    opened = 0
    app = Thistle::Map::App.new(store: '/unused', reader_factory: ->(*) { opened += 1; raise 'Must not open' })
    [{ 'REMOTE_ADDR' => '192.0.2.3' }, { 'HTTP_HOST' => 'hostile.example' },
      { 'HTTP_ORIGIN' => 'http://hostile.example' }, { 'HTTP_SEC_FETCH_SITE' => 'cross-site' }].each do |env|
      assert_equal 403, request(app, '/investigation', query: query, env: env).first
    end
    assert_equal 405, request(app, '/investigation', query: query, method: 'POST').first
    assert_equal 0, opened
    denied = make_app(CompactReader.new, allowed_hosts: ['code.example'], authorize: ->(_) { false })
    assert_equal 403, request(denied, '/investigation', query: query, env: { 'HTTP_HOST' => 'code.example' }).first
  end

  def test_head_closes_reader_and_reports_get_length_without_body
    reader = CompactReader.new
    code, headers, body = request(make_app(reader), '/investigation', query: query, method: 'HEAD')
    assert_equal 200, code
    assert_empty body
    assert_operator headers['content-length'].to_i, :>, 1000
    assert reader.closed
  end

  def test_missing_or_substituted_generation_never_falls_back_to_current
    seen = []
    absent = Thistle::Map::App.new(store: '/unused', reader_factory: ->(_, generation) { seen << generation; raise Thistle::NotFound })
    assert_equal 404, request(absent, '/investigation', query: query).first
    assert_equal [GENERATION], seen
    wrong = make_app(CompactReader.new('d' * 64))
    assert_equal 422, request(wrong, '/investigation', query: query).first
  end

  def test_identity_refusal_closes_reader_without_partial_success_or_expansion
    reader = CompactReader.new
    reader.define_singleton_method(:fact_identity) { |_| raise Thistle::LimitExceeded }
    code, _, body = request(make_app(reader), '/investigation', query: query)
    assert_equal 422, code
    assert reader.closed
    refute_includes body, '<ol>'
    refute_includes body, 'Demo#show'
  end

  def test_collect_remove_and_full_collection_controls_are_plain_pinned_links
    app = make_app
    _, _, source = request(app, '/source', query: "id=#{FACT_ID}&generation=#{GENERATION}")
    assert_includes source, 'Collect in investigation'
    href = source.scan(/href="([^"]+)"/).flatten.map { |value| CGI.unescapeHTML(value) }.find { |value| value.start_with?('/investigation?') && value.include?('selection=' + FACT_ID) }
    assert_equal({ 'generation' => GENERATION, 'selection' => FACT_ID }, URI.decode_www_form(URI.parse(href).query).to_h)
    _, _, selected = request(app, '/source', query: "id=#{FACT_ID}&#{query}")
    assert_includes selected, 'Remove from investigation'
    assert_includes selected, "name=\"selection\" value=\"#{FACT_ID}\""
    ids = (1..24).map { |id| '%064x' % id }
    _, _, full = request(app, '/source', query: "id=#{FACT_ID}&#{query(ids)}")
    assert_includes full, 'Collection full (24)'
    refute_includes full, 'Collect in investigation'
  end
end
