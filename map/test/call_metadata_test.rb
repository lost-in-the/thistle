# frozen_string_literal: true

require_relative 'test_helper'

class MapCallMetadataTest < Minitest::Test
  include MapTestSupport

  def test_unknown_and_malformed_metadata_never_create_source_anchors
    fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => { 'start_line' => 1, 'end_line' => 2, 'start_byte' => 0, 'end_byte' => 30 }, 'attributes' => {} }
    base = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved' }
    [ { 'version' => 2, 'receiver' => { 'kind' => '<script>' } },
      { 'version' => 1, 'receiver' => { 'kind' => '<script>' }, 'call_location' => { 'start_line' => 999 } },
      { 'version' => 1, 4 => 'unexpected' } ].each do |metadata|
      reader = Reader.new(facts: [fact], links: [base.merge('attributes' => { 'thistle_call' => metadata })])
      status, _, body = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID))
      assert_equal 200, status
      assert_includes body, 'Receiver details unavailable'
      refute_includes body, '#L999'
      refute_includes body, '<script>'
    end
  end
end
