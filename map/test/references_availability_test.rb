# frozen_string_literal: true
require_relative 'test_helper'

class ThistleReferencesAvailabilityTest < Minitest::Test
  include MapTestSupport

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
