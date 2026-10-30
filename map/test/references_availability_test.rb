# frozen_string_literal: true
require_relative 'test_helper'

class ThistleReferencesAvailabilityTest < Minitest::Test
  include MapTestSupport

  def incoming_reader
    reader = Reader.new
    def reader.fact(*) = raise('Incoming view expanded a fact')
    def reader.links(*) = raise('Incoming view expanded outgoing links')
    def reader.source(*) = raise('Incoming view read source')
    reader
  end

  def test_incoming_uses_only_the_pinned_compact_anchor
    reader = incoming_reader
    reader.define_singleton_method(:references) do |id, direction:|
      raise 'Wrong incoming query' unless id == FACT_ID && direction == 'incoming'
      { 'generation' => generation, 'anchor' => {
          'id' => id, 'name' => '<Demo>', 'kind' => 'class', 'evidence' => 'static',
          'path' => 'lib/demo.rb', 'location' => { 'start_line' => 1 }
        }, 'direction' => direction, 'relationships' => [],
        'coverage' => { 'known_matches' => 0, 'known_omitted' => 0, 'scan_complete' => true, 'capture_partial' => true } }
    end
    status, _, html = request(make_app(reader), '/links', query: "id=#{FACT_ID}&direction=incoming&generation=#{GENERATION}")
    assert_equal 200, status
    assert_includes html, 'Links for &lt;Demo&gt;'
    assert_includes html, "generation=#{GENERATION}"
    assert_includes html, 'No matching recorded relationships found in the searched evidence'
  end

  def test_incoming_refusal_and_unavailable_reader_never_fall_back_to_expanded_facts
    reader = incoming_reader
    def reader.references(*) = raise(Thistle::LimitExceeded, 'Reference reservation refused')
    status, _, html = request(make_app(reader), '/links', query: "id=#{FACT_ID}&direction=incoming")
    assert_equal 200, status
    assert_includes html, 'no reference result was returned'
    refute_includes html, 'No matching recorded relationships found'
    status, _, html = request(make_app(incoming_reader), '/links', query: "id=#{FACT_ID}&direction=incoming")
    assert_equal 200, status
    assert_includes html, 'unavailable with this Reader'
  end

  def test_incoming_runtime_anchors_explain_unloaded_details_without_invalid_metadata_notices
    %w[rails_model rails_save_callbacks].each do |kind|
      reader = incoming_reader
      reader.define_singleton_method(:references) do |id, direction:|
        { 'generation' => generation, 'anchor' => {
            'id' => id, 'name' => 'Demo', 'kind' => kind, 'evidence' => 'runtime', 'path' => nil, 'location' => nil
          }, 'direction' => direction, 'relationships' => [],
          'coverage' => { 'known_matches' => 0, 'known_omitted' => 0, 'scan_complete' => true, 'capture_partial' => true } }
      end
      status, _, html = request(make_app(reader), '/links', query: "id=#{FACT_ID}&direction=incoming")
      assert_equal 200, status
      assert_includes html, kind
      assert_includes html, 'Detailed fact evidence was not loaded for this incoming view'
      refute_includes html, 'unknown format'
      refute_includes html, 'invalid evidence shape'
    end
  end

  def test_incoming_rejects_substituted_anchor_identity
    reader = incoming_reader
    def reader.references(*) = { 'generation' => generation, 'anchor' => { 'id' => 'c' * 64 } }
    assert_equal 422, request(make_app(reader), '/links', query: "id=#{FACT_ID}&direction=incoming").first
  end

  def test_resource_refusal_keeps_existing_captured_links_without_claiming_empty_references
    reader = Reader.new
    def reader.references(*) = raise(Thistle::LimitExceeded, 'Reference reservation refused')
    status, _, html = request(make_app(reader), '/links', query: "id=#{FACT_ID}&generation=#{GENERATION}")
    assert_equal 200, status
    assert_includes html, 'Reference selection reached resource limits'
    assert_includes html, 'render'
    assert_includes html, "generation=#{GENERATION}"
    refute_includes html, 'No matching recorded relationships found'
  end

  def test_snapshot_failure_is_not_hidden_by_optional_reference_fallback
    reader = Reader.new
    def reader.references(*) = raise(Thistle::InvalidSnapshot, 'Invalid reference data')
    assert_equal 422, request(make_app(reader), '/links', query: "id=#{FACT_ID}").first
  end

  def test_presenter_generation_mismatch_still_refuses
    reader = Reader.new
    def reader.references(*) = { 'generation' => 'c' * 64 }
    assert_equal 422, request(make_app(reader), '/links', query: "id=#{FACT_ID}").first
  end
end
