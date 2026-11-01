# frozen_string_literal: true

require 'minitest/autorun'
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
      @manifest = { 'files' => [{ 'path' => PATH, 'bytes' => CONTENT.bytesize, 'sha256' => Digest::SHA256.hexdigest(CONTENT) }],
        'coverage' => [{ 'family' => 'source_ownership', 'status' => 'partial' }] }
    end
    def root = { 'id' => MODEL, 'name' => 'Order', 'kind' => 'rails_model', 'evidence' => 'runtime', 'path' => nil, 'location' => nil }
    def physical(id = DECLARATION)
      { 'id' => id, 'name' => id == METHOD ? 'Order#schedule_receipt' : 'Order', 'kind' => id == METHOD ? 'method' : 'class',
        'evidence' => 'static', 'path' => PATH, 'location' => { 'start_line' => id == METHOD ? 2 : 1, 'end_line' => 5 } }
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
      { 'generation' => G, 'fact' => physical(id), 'content' => CONTENT, 'sha256' => Digest::SHA256.hexdigest(CONTENT) }
    end
    def fact(*) = raise('Full fact expansion forbidden')
    def model_brief(*) = raise('Eager model brief forbidden')
    def references(*) = raise('Eager references forbidden')
    def callback_effects(*) = raise('Eager callbacks forbidden')
    def close = @closed = true
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
end

if $PROGRAM_NAME == __FILE__ || ENV['THISTLE_MAP_PURE'] == '1'
  Minitest.after_run do
    raise 'Pure check loaded native or Rails' if defined?(Thistle::Native) || defined?(Rails) || defined?(ActiveRecord)
  end
end
