# frozen_string_literal: true

# Pure URL/presentation checks: deliberately no thistle/native/framework require.
require 'minitest/autorun'
require 'cgi'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/investigation_presenter'
require_relative '../lib/thistle/map/investigation_evidence'

class InvestigationTest < Minitest::Test
  Selection = Thistle::Map::Investigation
  Presenter = Thistle::Map::InvestigationPresenter
  GENERATION = 'a' * 64
  IDS = (1..25).map { |number| '%064x' % number }.freeze

  def selection(ids = IDS.first(2))
    Selection.new(generation: GENERATION, ids: ids)
  end

  def test_empty_collection_needs_no_identity_seam_but_selected_evidence_still_does
    reader = Object.new
    reader.define_singleton_method(:generation) { GENERATION }
    empty = Thistle::Map::InvestigationEvidence.new(reader: reader, selection: selection([]))
    assert_raises(Selection::Limit) { empty.fetch(IDS.first) }
    assert_raises(Selection::Limit) do
      Thistle::Map::InvestigationEvidence.new(reader: reader, selection: selection)
    end
  end

  def identity(id, **changes)
    { 'id' => id, 'name' => 'A<&>', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'lib/a.rb', 'location' => { 'start_line' => 3, 'end_line' => 4 } }.merge(changes.transform_keys(&:to_s))
  end

  def test_ordered_token_free_focus_roundtrip_add_remove_and_immutable_caller_values
    generation = GENERATION.dup
    ids = IDS.first(2).map(&:dup)
    saved = Selection.new(generation: generation, ids: ids)
    generation.clear; ids.first.clear; ids.clear
    uri = URI.parse(saved.url('/map'))
    assert_equal '/map/investigation', uri.path
    assert_equal %w[generation selection], URI.decode_www_form(uri.query).map(&:first)
    reopened = Selection.from_params(URI.decode_www_form(uri.query).to_h)
    assert_equal IDS.first(2), reopened.ids
    assert_equal GENERATION, reopened.generation
    assert_equal [IDS[1], IDS[2]], reopened.remove(IDS[0]).add(IDS[2]).ids
    assert_same reopened, reopened.add(IDS[0])
    assert reopened.ids.frozen?
    assert reopened.ids.all?(&:frozen?)
  end

  def test_refuses_malformed_duplicate_missing_generation_and_oversize_state
    [nil, '', 'CURRENT', 'a' * 63, '../store', 'A' * 64].each do |generation|
      assert_raises(Selection::Invalid) { Selection.new(generation: generation) }
    end
    ['', 'g' * 64, "#{IDS[0]},", "#{IDS[0]},#{IDS[0]}"].drop(1).each do |text|
      assert_raises(Selection::Invalid) { Selection.from_params('generation' => GENERATION, 'selection' => text) }
    end
    assert_raises(Selection::Invalid) { Selection.new(generation: GENERATION, ids: [IDS[0], IDS[0]]) }
    assert_raises(Selection::Limit) { selection(IDS) }
    assert_raises(Selection::Limit) { Selection.from_params('generation' => GENERATION, 'selection' => 'x' * 1560) }
    assert_raises(Selection::Limit) { selection(IDS.first(24)).add(IDS.last) }
    assert_equal [], Selection.from_params('generation' => GENERATION, 'selection' => '').ids
    assert_operator URI.parse(selection(IDS.first(24)).url).query.bytesize, :<=, Selection::MAX_QUERY_BYTES
  end

  def test_partial_and_missing_selections_remain_visible_with_no_eager_expansion
    calls = []
    html = Presenter.new(selection: selection, mount: '/map').render do |id|
      calls << id
      identity(id) if id == IDS.first
    end
    assert_equal IDS.first(2), calls
    assert_includes html, 'Missing selection'
    assert_includes html, IDS[1]
    assert_includes html, 'A&lt;&amp;&gt;'
    refute_includes html, 'A<&>'
    assert_includes html, 'partial or unavailable'
    assert_includes html, 'no replacement or binding was inferred'
    source = html.scan(/href="([^"]+)"/).flatten.map { |href| URI.parse(CGI.unescapeHTML(href)) }.find { |uri| uri.path == '/map/source' }
    params = URI.decode_www_form(source.query).to_h
    assert_equal GENERATION, params['generation']
    assert_equal IDS.first(2).join(','), params['selection']
    assert_equal IDS[0], params['id']
    refute params.key?('path')
    refute_match(/<(?:script|input|textarea)\b/, html)
    refute_match(/on(?:click|load)=/, html)
    assert_includes html, 'Remove A&lt;&amp;&gt; from investigation'
  end

  def test_runtime_identity_has_links_without_invented_source
    html = Presenter.new(selection: selection(IDS.first(1))).render do |id|
      identity(id, path: nil, location: nil)
    end
    assert_includes html, 'No captured file or line'
    assert_includes html, 'Links for'
    refute_includes html, '/source?'
  end

  def test_escaped_output_growth_and_identity_size_refuse_instead_of_truncating
    assert_raises(Selection::Limit) do
      Presenter.new(selection: selection(IDS.first(1))).render { |id| identity(id, name: '<' * 100_000) }
    end
    calls = 0
    assert_raises(Selection::Limit) do
      Presenter.new(selection: selection(IDS.first(24))).render do |id|
        calls += 1
        identity(id, name: '&' * 20_000)
      end
    end
    assert_operator calls, :<, 24
  end

  class CompactReader
    attr_reader :generation, :calls
    attr_accessor :result
    def initialize(generation, &result)
      @generation, @result, @calls = generation, result, []
    end
    def fact_identity(id)
      @calls << id
      @result.call(id)
    end
    def fact(*) = raise('Expanded fact requested')
    def source(*) = raise('Source requested')
    def facts = raise('Inventory requested')
    def references(*) = raise('References requested')
  end

  def compact_identity(id)
    identity(id).merge('location' => { 'start_line' => 3, 'end_line' => 4, 'start_byte' => 0, 'end_byte' => 8 })
  end

  def test_compact_reader_requests_exact_order_and_keeps_missing_id_without_fallback
    reader = CompactReader.new(GENERATION) do |id|
      raise Thistle::NotFound if id == IDS[1]
      { 'generation' => GENERATION, 'fact' => compact_identity(id) }
    end
    evidence = Thistle::Map::InvestigationEvidence.new(reader: reader, selection: selection)
    html = Presenter.new(selection: selection).render { |id| evidence.fetch(id) }
    assert_equal IDS.first(2), reader.calls
    assert_includes html, 'Missing selection'
    assert_raises(Selection::Limit) { evidence.fetch(IDS.first) }
    assert_equal 2, reader.calls.length
  end

  def test_compact_lookup_refuses_wrong_generation_identity_and_limits_without_fallback
    reader = CompactReader.new(GENERATION) { |id| { 'generation' => 'f' * 64, 'fact' => compact_identity(id) } }
    evidence = Thistle::Map::InvestigationEvidence.new(reader: reader, selection: selection)
    assert_raises(Thistle::InvalidSnapshot) { evidence.fetch(IDS.first) }
    reader.result = ->(id) { { 'generation' => GENERATION, 'fact' => compact_identity(id).merge('id' => IDS.last) } }
    evidence = Thistle::Map::InvestigationEvidence.new(reader: reader, selection: selection)
    assert_raises(Thistle::InvalidSnapshot) { evidence.fetch(IDS.first) }
    reader.result = ->(_id) { raise Thistle::LimitExceeded }
    evidence = Thistle::Map::InvestigationEvidence.new(reader: reader, selection: selection)
    assert_raises(Thistle::LimitExceeded) { evidence.fetch(IDS.first) }
    assert_equal 3, reader.calls.length
  end

  def test_encoded_reader_response_is_charged_including_escape_expansion
    reader = CompactReader.new(GENERATION) do |id|
      { 'generation' => GENERATION, 'fact' => compact_identity(id).merge('name' => "\n" * 20_000) }
    end
    evidence = Thistle::Map::InvestigationEvidence.new(reader: reader, selection: selection)
    assert_raises(Selection::Limit) { evidence.fetch(IDS.first) }
  end

  def test_saved_control_character_name_is_visible_and_collection_remains_removable
    reader = CompactReader.new(GENERATION) do |id|
      { 'generation' => GENERATION, 'fact' => compact_identity(id).merge('name' => "Order\t<script>\u0001") }
    end
    saved = selection(IDS.first(1))
    evidence = Thistle::Map::InvestigationEvidence.new(reader: reader, selection: saved)
    html = Presenter.new(selection: saved).render { |id| evidence.fetch(id) }
    assert_includes html, 'Order\\u0009&lt;script&gt;\\u0001'
    assert_includes html, 'Remove Order\\u0009&lt;script&gt;\\u0001 from investigation'
    refute_includes html, '<script>'
    href = html.scan(/href="([^"]+)"/).flatten.map { |url| URI.parse(CGI.unescapeHTML(url)) }.last
    assert_equal '', URI.decode_www_form(href.query).to_h.fetch('selection', '')
  end

  def test_total_identity_work_is_at_most_24_indexed_lookups
    reader = CompactReader.new(GENERATION) { |id| { 'generation' => GENERATION, 'fact' => compact_identity(id) } }
    saved = selection(IDS.first(24))
    evidence = Thistle::Map::InvestigationEvidence.new(reader: reader, selection: saved)
    saved.ids.each { |id| assert_equal id, evidence.fetch(id)['id'] }
    assert_raises(Selection::Limit) { evidence.fetch(IDS.last) }
    assert_equal saved.ids, reader.calls
  end

  def test_full_24_fact_collection_fits_and_preserves_all_ids_in_evidence_links
    saved = selection(IDS.first(24))
    html = Presenter.new(selection: saved).render { |id| identity(id) }
    assert_equal 24, html.scan('<li><article>').length
    assert_operator html.bytesize, :<=, Presenter::MAX_OUTPUT_BYTES
    hrefs = html.scan(/href="([^"]+)"/).flatten.map { |href| URI.parse(CGI.unescapeHTML(href)) }
    evidence = hrefs.select { |uri| %w[/source /links].include?(uri.path) }
    assert_equal 48, evidence.length
    evidence.each do |uri|
      assert_equal saved.ids.join(','), URI.decode_www_form(uri.query).to_h['selection']
    end
  end
end
