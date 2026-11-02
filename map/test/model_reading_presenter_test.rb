# frozen_string_literal: true

require 'minitest/autorun'
require 'cgi'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/model_reading'
require_relative '../lib/thistle/map/model_reading_presenter'

# Handwritten typed DTOs, never generated from UI or a native capture.
module ModelReadingAnswers
  G = 'a' * 64
  MODEL = 'b' * 64
  DECLARATION = 'c' * 64
  METHOD = 'd' * 64
  PATH = 'app/models/order.rb'
  CONTENT = "class Order\n  def schedule_receipt\n    '<script>saved_a 雪</script>'\n  end\nend\n"

  class Reader
    attr_reader :generation, :calls, :manifest, :closed
    attr_accessor :ambiguous, :oversized, :bad_generation
    def initialize
      @generation, @calls = G, []
      @content = CONTENT
      @manifest = { 'files' => [{ 'path' => PATH, 'bytes' => CONTENT.bytesize, 'sha256' => Digest::SHA256.hexdigest(CONTENT) }],
        'coverage' => [{ 'family' => 'source_ownership', 'status' => 'partial' }] }
    end
    def use_content(content)
      @content = content
      @manifest['files'][0].merge!('bytes' => content.bytesize, 'sha256' => Digest::SHA256.hexdigest(content))
    end
    def root = { 'id' => MODEL, 'name' => 'Order', 'kind' => 'rails_model', 'evidence' => 'runtime', 'path' => nil, 'location' => nil }
    def physical(id = DECLARATION)
      { 'id' => id, 'name' => id == METHOD ? 'Order#schedule_receipt' : 'Order', 'kind' => id == METHOD ? 'method' : 'class',
        'evidence' => 'static', 'path' => PATH, 'location' => { 'start_line' => id == METHOD ? 2 : 1, 'end_line' => @content.lines.length } }
    end
    def fact_identity(id)
      @calls << [:identity, id]
      { 'generation' => generation, 'fact' => root }
    end
    def source_comprehension(id, **options)
      @calls << [:comprehension, id, options]
      raise 'Wrong root or budget' unless id == MODEL && options[:limit] == 8 && options[:max_bytes] == 32768
      family = options.fetch(:family)
      fact = physical(family == 'methods' ? METHOD : DECLARATION)
      row = { 'fact' => fact, 'owner' => 'Order', 'observed_owner' => 'Order',
        'status' => family == 'methods' ? 'observed_loaded_owner_source_binding_unknown' : 'as_written_declaration',
        'source' => { 'operation' => 'source', 'generation' => G, 'id' => fact['id'] },
        'callers' => { 'operation' => 'references', 'generation' => G, 'id' => fact['id'], 'direction' => 'incoming' } }
      rows = [row]
      if ambiguous
        another = Marshal.load(Marshal.dump(row)); another['fact']['id'] = 'e' * 64
        another['source']['id'] = another['callers']['id'] = another['fact']['id']
        rows << another
        rows.each { |candidate| candidate['status'] = 'ambiguous_definitions' }
      end
      @manifest['files'][0]['bytes'] = 65537 if oversized
      { 'version' => 1, 'generation' => bad_generation ? 'f' * 64 : G, 'model' => root, 'owner' => 'Order', 'family' => family,
        'composition' => 'identified_contributions', 'source_runtime_coherence' => 'unknown',
        'ownership_status' => 'unique_label_candidate_binding_unknown', 'owners' => [{ 'index' => 0, 'name' => 'Order', 'kind' => 'class' }],
        'rows' => [], 'observed_only' => [], 'contributions' => rows, 'continuation' => nil,
        'coverage' => { 'returned' => rows.length, 'candidate_matches_seen' => rows.length, 'range_complete' => true, 'scope' => 'saved candidates' },
        'semantics' => 'Saved definitions are not a concatenated effective runtime class. Execution unknown.' }
    end
    def source(id)
      @calls << [:source, id]
      { 'generation' => G, 'fact' => physical(id), 'content' => @content, 'sha256' => Digest::SHA256.hexdigest(@content) }
    end
    def fact(*) = raise('Full fact expansion forbidden')
    def model_brief(*) = raise('Eager model brief forbidden')
    def references(*) = raise('Eager references forbidden')
    def callback_effects(*) = raise('Eager callbacks forbidden')
    def close = @closed = true
  end

  # Handwritten Core-shaped callback DTO. Position8 deliberately falls outside
  # the compact8; unknown preparations are not turned into supported effects.
  def self.callback_answer(id, limit:, partial: false)
    entries = (0..8).map do |position|
      target = position == 8
      filter = { 'kind' => 'method', 'name' => target ? 'schedule_receipt' : "prepare_#{position}",
        'owner' => target ? 'ReceiptPolicy' : 'Order', 'source' => { 'path' => PATH, 'line' => 2 } }
      explanation = if target
        { 'status' => 'supported_potential', 'reason' => 'recorded_constant_receiver_perform_later',
          'binding' => 'descriptor_matched_captured_declaration', 'coherence' => 'unknown', 'links_search_complete' => true,
          'method' => { 'id' => METHOD, 'name' => 'ReceiptPolicy#schedule_receipt', 'owner' => 'ReceiptPolicy',
            'method_name' => 'schedule_receipt', 'path' => PATH, 'span' => { 'start_byte' => 12, 'end_byte' => 60, 'start_line' => 2, 'end_line' => 4 } },
          'source' => { 'path' => PATH, 'sha256' => Digest::SHA256.hexdigest(CONTENT), 'lines' => 5, 'bytes' => CONTENT.bytesize },
          'known_effects_omitted' => partial ? 2 : 0, 'effects_non_exhaustive' => true,
          'effects' => [{ 'kind' => 'potential_enqueue_style_request', 'operation' => 'ReceiptJob.perform_later',
            'receiver' => 'ReceiptJob', 'selector' => 'perform_later', 'safe_navigation' => false,
            'provenance' => 'captured_source_potential', 'call_span' => { 'start_byte' => 20, 'end_byte' => 48, 'start_line' => 3, 'end_line' => 3 },
            'receiver_span' => { 'start_byte' => 20, 'end_byte' => 30, 'start_line' => 3, 'end_line' => 3 },
            'source_excerpt' => 'ReceiptJob.perform_later(id)', 'excerpt_truncated' => false }] }
      else
        { 'status' => 'unknown', 'reason' => 'opaque_or_incomplete_observed_method_descriptor',
          'binding' => 'unavailable', 'effects' => [], 'links_search_complete' => false }
      end
      { 'callback_id' => "#{id}:#{position}", 'registry_id' => id, 'registry_provenance' => 'registered_metadata',
        'position' => position, 'kind' => target ? 'after' : 'before', 'filter' => filter,
        'if' => target ? [{ 'kind' => 'method', 'name' => 'receipt_due?', 'owner' => 'Order' }] : [],
        'unless' => [], 'inherited' => false, 'explanation' => explanation }
    end
    { 'version' => 1, 'generation' => G, 'registry_id' => id, 'model' => 'Order', 'registry_status' => partial ? 'partial' : 'observed',
      'coherence' => 'unknown', 'execution' => 'unknown', 'limit' => limit, 'callbacks' => entries.first(limit),
      'semantics' => 'Registered metadata and source-supported potential; conditions, invocation and execution unknown.',
      'coverage' => { 'truncated' => partial || limit < entries.length, 'rows_attempted' => [limit, entries.length].min,
        'rows_not_searched' => [entries.length - limit, 0].max, 'rows_metadata_omitted' => 0, 'rows_output_omitted' => partial ? 1 : 0,
        'declaration_scan_complete' => !partial, 'candidate_ranges_complete' => !partial, 'capture_partial_or_unknown' => partial,
        'source_rows_not_searched' => partial ? 1 : 0, 'method_directory' => { 'status' => 'complete' } } }
  end
end

class ModelReadingPresenterTest < Minitest::Test
  include ModelReadingAnswers
  def render(reader)
    reading = Thistle::Map::ModelReading.new(reader: reader, id: MODEL, generation: G)
    selection = Thistle::Map::Investigation.new(generation: G, ids: [MODEL, METHOD])
    nav = Thistle::Map::NavigationContext.new(generation: G, mount: '/map', model_id: MODEL,
      params: { 'q' => 'Order', 'domain' => 'metadata' }, selection: selection)
    Thistle::Map::ModelReadingPresenter.new(reading: reading, navigation: nav,
      highlighter: ->(content, **) { content.lines.map { |line| ERB::Util.html_escape(line.chomp) } }).render
  end

  def test_full_physical_source_and_named_method_outline_without_eager_families
    reader = Reader.new
    html = render(reader)
    assert_equal [:comprehension, :comprehension, :source], reader.calls.map(&:first)
    assert_equal %w[contributions methods], reader.calls.first(2).map { |call| call[2][:family] }
    assert_equal 1, html.scan('class="cv codeview"').length
    assert_equal CONTENT.lines.length, html.scan('class="ln"').length
    assert_includes html, 'Order#schedule_receipt'
    assert_includes html, PATH
    assert_includes html, '&lt;script&gt;saved_a 雪&lt;/script&gt;'
    assert_includes html, "reading-file-#{Digest::SHA256.hexdigest(PATH)}-L5"
    assert_operator html.index('class="cv codeview"'), :<, html.index('Ownership, provenance and coverage')
    assert_includes html, "/models/#{MODEL}/at/#{Digest::SHA256.hexdigest(PATH)}/2/source?"
    assert_includes html, 'source binding, conditions and execution remain unknown'
  end

  def test_all_ambiguous_candidates_are_named_and_shared_file_is_read_once
    reader = Reader.new; reader.ambiguous = true
    html = render(reader)
    assert_equal 1, reader.calls.count { |call| call[0] == :source }
    assert_includes html, 'Ambiguous: multiple saved definitions'
    assert_includes html, 'id=' + METHOD
    assert_includes html, 'id=' + 'e' * 64
    refute_includes html, 'effective runtime body'
  end

  def test_manifest_reservation_precedes_source_and_bad_generation_refuses
    reader = Reader.new; reader.oversized = true
    assert_includes render(reader), 'source not admitted'
    assert_equal 0, reader.calls.count { |call| call[0] == :source }
    reader = Reader.new; reader.bad_generation = true
    assert_raises(Thistle::InvalidSnapshot) { render(reader) }
    assert_equal 1, reader.calls.length
  end

  def test_unrepresentable_source_choices_clear_old_physical_position_but_keep_method_context
    data = Reader.new.source_comprehension(MODEL, family: 'contributions', limit: 8, max_bytes: 32768)
    data['contributions'][0]['fact'].merge!('path' => nil, 'location' => nil)
    methods = Reader.new.source_comprehension(MODEL, family: 'methods', limit: 8, max_bytes: 32768)
    methods['contributions'][0]['fact']['location'] = { 'start_line' => 10001, 'end_line' => 10002 }
    reading = Struct.new(:projection, :methods, :admission).new(data, methods, Struct.new(:sources, :states).new({}, {}))
    cursor = JSON.generate(['recorded-v1', G, Digest::SHA256.hexdigest(JSON.generate(['source_comprehension', MODEL, 'methods'])), 1, 0])
    nav = Thistle::Map::NavigationContext.new(generation: G, model_id: MODEL, source_position: ['f' * 64, 5],
      reading_family: 'methods', reading_cursor: cursor, selection: Thistle::Map::Investigation.new(generation: G, ids: [MODEL]))
    html = Thistle::Map::ModelReadingPresenter.new(reading: reading, navigation: nav, highlighter: ->(*) { raise 'No source admitted' }).render
    source_links = html.scan(/href="([^"]+)"/).flatten.map { |href| URI(CGI.unescapeHTML(href)) }.select { |uri| uri.path.end_with?('/source') }
    targets = source_links.select { |uri| [DECLARATION, METHOD].include?(URI.decode_www_form(uri.query).to_h['id']) }
    refute_empty targets
    targets.each do |uri|
      refute_includes uri.path, '/at/'
      assert_includes uri.path, "/from/methods/#{cursor.unpack1('H*')}"
      assert_equal G, URI.decode_www_form(uri.query).to_h['generation']
    end
  end
end

if $PROGRAM_NAME == __FILE__ || ENV['THISTLE_MAP_PURE'] == '1'
  Minitest.after_run do
    raise 'Pure check loaded native/framework/highlighter SDK' if defined?(Thistle::Native) || defined?(Rails) || defined?(ActiveRecord) || defined?(Rouge)
  end
end
