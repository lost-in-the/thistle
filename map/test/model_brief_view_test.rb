# frozen_string_literal: true

require_relative 'test_helper'
require 'cgi'

# Presentation contracts only. These responses deliberately include partial and
# omitted evidence; Core tests own selection/analysis and response semantics.
class ModelBriefViewTest < Minitest::Test
  include MapTestSupport
  METHOD_ID = 'c' * 64
  REGISTRY_ID = 'd' * 64

  class BriefReader < MapTestSupport::Reader
    attr_accessor :brief, :failure
    attr_reader :brief_calls

    def initialize(brief)
      super(facts: [brief.fetch('root').merge('attributes' => {})])
      @brief, @brief_calls = brief, []
    end

    def model_brief(id, **options)
      @brief_calls << [id, options]
      raise @failure if @failure
      @brief
    end
  end

  def response
    root = { 'id' => FACT_ID, 'name' => 'Order<雪>', 'kind' => 'rails_model',
      'evidence' => 'observed', 'path' => nil, 'location' => nil }
    family = lambda do |status, items|
      { 'generation' => GENERATION, 'fact_id' => FACT_ID, 'status' => status, 'reason' => 'recorded_family_status',
        'provenance' => 'recorded_model_metadata', 'known_omitted' => 0, 'unsearched' => false, 'items' => items }
    end
    method = { 'id' => METHOD_ID, 'name' => 'Parent#deliver', 'owner' => 'Parent',
      'method_name' => 'deliver', 'path' => 'records.rb',
      'span' => { 'start_byte' => 20, 'end_byte' => 100, 'start_line' => 2, 'end_line' => 4 } }
    callback = { 'registry_id' => REGISTRY_ID, 'position' => 0, 'kind' => 'before',
      'registry_provenance' => 'registered_metadata', 'inherited' => true,
      'filter' => { 'kind' => 'method', 'name' => 'deliver', 'owner' => 'Parent' }, 'if' => [], 'unless' => nil,
      'explanation' => { 'status' => 'supported_potential', 'reason' => 'recorded_constant_receiver_perform_later',
        'binding' => 'descriptor_matched_captured_declaration', 'links_search_complete' => true, 'method' => method,
        'source' => { 'path' => 'records.rb', 'sha256' => 'e' * 64, 'bytes' => 101, 'lines' => 5 },
        'known_effects_omitted' => 1, 'effects_non_exhaustive' => true,
        'effects' => [{ 'operation' => 'DeliveryJob.perform_later', 'provenance' => 'captured_source_potential',
          'source_excerpt' => 'DeliveryJob.perform_later("<script>雪</script>")', 'excerpt_truncated' => true,
          'call_span' => { 'start_byte' => 30, 'end_byte' => 80, 'start_line' => 3, 'end_line' => 3 },
          'receiver_span' => { 'start_byte' => 30, 'end_byte' => 41, 'start_line' => 3, 'end_line' => 3 } }] } }
    relationship = { 'origin' => root, 'link' => { 'relation' => 'association_target_label',
      'target' => 'Item<script>', 'resolution' => 'unresolved' }, 'match_basis' => 'recorded_outgoing_binding_unknown',
      'candidate_matches' => 2, 'candidate_search_complete' => false, 'detail_omitted' => true, 'candidates' => [] }
    families = { 'columns' => family.call('observed', [{ 'name' => 'state<雪>', 'type' => 'string', 'null' => false }]),
      'associations' => family.call('unavailable', []), 'registry_candidates' => family.call('ambiguous', []),
      'callbacks' => family.call('partial', [callback]), 'outgoing' => family.call('not_searched', [relationship]),
      'incoming' => family.call('not_searched', []) }
    families['columns'].merge!('known_omitted' => 2, 'output_truncated' => true)
    families['associations'].merge!('known_omitted' => nil, 'unsearched' => true)
    families['callbacks']['coverage'] = { 'declaration_scan_complete' => false, 'source_rows_not_searched' => 1 }
    families['outgoing']['coverage'] = { 'scan_complete' => false, 'candidate_search_complete' => false }
    families['incoming']['followup'] = { 'operation' => 'references', 'generation' => GENERATION, 'id' => FACT_ID, 'direction' => 'incoming', 'cursor' => nil }
    families['columns']['followup'] = { 'operation' => 'model_brief', 'generation' => GENERATION, 'id' => FACT_ID, 'family' => 'columns', 'cursor' => nil }
    { 'version' => 1, 'generation' => GENERATION, 'root' => root, 'uncertainty' => 'Saved <unknown> binding; no execution evidence.',
      'coverage' => { 'capture_partial_or_unknown' => true, 'families_not_projected' => 1, 'families' => [] },
      'limits' => { 'items_per_family' => 8 }, 'usage' => { 'returned_items' => 3 }, 'families' => families }
  end

  def test_brief_preserves_evidence_distinctions_omissions_escaping_and_pinned_destinations
    reader = BriefReader.new(response)
    status, _, html = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID), env: { 'SCRIPT_NAME' => '/map' })
    assert_equal 200, status
    assert_equal [[FACT_ID, { limit: 8, max_bytes: 32768 }]], reader.brief_calls
    %w[Recorded\ columns Recorded\ associations Callback\ registry\ label\ candidates].each { |label| assert_includes html, label }
    assert_includes html, 'Source-supported potential request'
    assert_includes html, 'Invocation and delivery unknown'
    assert_includes html, 'Position is not execution order'
    assert_includes html, 'Known omitted: Unknown; unsearched: true'
    assert_includes html, 'Known omitted: 2; unsearched: false; output truncated: true'
    assert_includes html, 'No items returned in this brief family'
    assert_includes html, 'declaration_scan_complete'
    assert_includes html, 'candidate_search_complete'
    assert_includes html, 'receiver_span'
    assert_includes html, 'Saved &lt;unknown&gt;'
    assert_includes html, 'state&lt;雪&gt;'
    refute_includes html, '<script>雪</script>'
    assert_includes html, '&lt;script&gt;雪&lt;/script&gt;'
    assert_includes html, '/brief/columns?'
    hrefs = html.scan(/href="([^"]+)"/).flatten.map { |href| CGI.unescapeHTML(href) }
    assert hrefs.any? { |href| uri = URI.parse(href); uri.path == '/map/source' && uri.fragment == 'L3' && URI.decode_www_form(uri.query).to_h == { 'generation' => GENERATION, 'id' => METHOD_ID } }
    assert hrefs.any? { |href| href.include?('/references/incoming?') && href.include?("generation=#{GENERATION}") }
    assert_includes html, '<noscript>'
    assert_includes html, 'Skip to evidence'
  end

  def test_wrong_generation_root_or_family_is_refused_without_current_fallback
    [->(r) { r['generation'] = 'f' * 64 }, ->(r) { r['root']['id'] = 'f' * 64 },
      ->(r) { r['families']['columns']['generation'] = 'f' * 64 }].each do |corrupt|
      data = response
      reader = BriefReader.new(data)
      corrupt.call(data)
      status, _, html = request(make_app(reader), '/links', query: "id=#{FACT_ID}")
      assert_equal 422, status
      assert_includes html, 'No other capture has been substituted'
    end
  end

  def test_limit_and_old_reader_are_unknown_while_integrity_errors_propagate
    reader = BriefReader.new(response)
    reader.failure = Thistle::LimitExceeded.new('budget')
    status, _, html = request(make_app(reader), '/links', query: "id=#{FACT_ID}")
    assert_equal 200, status
    assert_includes html, 'no brief was returned'
    reader.failure = Thistle::InvalidInput.new('Unknown native operation')
    status, _, html = request(make_app(reader), '/links', query: "id=#{FACT_ID}")
    assert_equal 200, status
    assert_includes html, 'Native model brief API unavailable'
    reader.failure = Thistle::InvalidSnapshot.new('corrupt bytes')
    assert_equal 422, request(make_app(reader), '/links', query: "id=#{FACT_ID}").first
    old_reader = Reader.new(facts: [response.fetch('root').merge('attributes' => {})])
    status, _, html = request(make_app(old_reader), '/links', query: "id=#{FACT_ID}")
    assert_equal 200, status
    assert_includes html, 'Model brief unavailable with this Reader'
  end

  def test_source_display_budgets_keep_fallback_pinned_and_accept_the_exact_byte_boundary
    # Synthetic adapter responses exercise the View/destination contract. Current
    # native callback evidence already caps supported source at 256 KiB.
    [[{ 'lines' => 10_001 }, 10_001], [{ 'bytes' => 262_145 }, 3]].each do |metadata, line|
      data = response
      explanation = data.dig('families', 'callbacks', 'items', 0, 'explanation')
      explanation['source'].merge!(metadata)
      explanation['effects'][0]['call_span']['start_line'] = line
      status, _, html = request(make_app(BriefReader.new(data)), '/links', query: "id=#{FACT_ID}")
      assert_equal 200, status
      assert_includes html, 'Supporting source exceeds the web display budget'
      assert_includes html, "thistle source #{METHOD_ID} --store STORE --generation #{GENERATION}"
      refute_includes html, "#L#{line}"
    end

    data = response
    data.dig('families', 'callbacks', 'items', 0, 'explanation', 'source')['bytes'] = 262_144
    status, _, html = request(make_app(BriefReader.new(data)), '/links', query: "id=#{FACT_ID}")
    assert_equal 200, status
    assert_includes html, "href=\"/source?generation=#{GENERATION}&amp;id=#{METHOD_ID}#L3\""
    refute_includes html, 'Supporting source exceeds the web display budget'
  end

  def test_incoming_identity_only_view_and_denied_requests_do_not_select_a_brief
    reader = BriefReader.new(response)
    app = make_app(reader)
    status, _, html = request(app, '/links', query: "id=#{FACT_ID}&direction=incoming")
    assert_equal 200, status
    refute_includes html, 'Saved model investigation'
    assert_empty reader.brief_calls
    assert_equal 403, request(app, '/links', query: "id=#{FACT_ID}", env: { 'REMOTE_ADDR' => '192.0.2.1' }).first
    assert_empty reader.brief_calls
  end
end
