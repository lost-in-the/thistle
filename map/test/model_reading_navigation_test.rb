# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../lib/thistle/map/navigation_context'

class ModelReadingNavigationTest < Minitest::Test
  G = 'a' * 64
  ID = 'b' * 64
  FILE = 'c' * 64
  def test_full_selection_query_and_supported_physical_position_survive_named_evidence
    selection = Thistle::Map::Investigation.new(generation: G, ids: (1..24).map { |n| n.to_s(16).rjust(64, '0') })
    search = { 'q' => 'Order', 'kind' => 'rails_model', 'prefix' => 'app/', 'domain' => 'metadata' }
    nav = Thistle::Map::NavigationContext.new(generation: G, mount: '/map', model_id: ID, source_position: [FILE, 4], params: search, selection: selection)
    ['/source', '/brief/registry_candidates', '/model-neighborhood/columns/outgoing/all'].each do |path|
      uri = URI(nav.url(path, 'id' => ID))
      assert_equal "/map/models/#{ID}/at/#{FILE}/4#{path}", uri.path
      params = URI.decode_www_form(uri.query).to_h
      assert_equal selection.ids.join(','), params['selection']
      assert_equal search, params.slice(*search.keys)
      assert_operator uri.query.bytesize, :<=, 4096
      assert_operator params.length, :<=, 9
    end
    assert_equal '/map/', URI(nav.url('/')).path
  end

  def test_callback_query_has_no_ambient_cursor_or_invented_model_binding
    nav = Thistle::Map::NavigationContext.new(generation: G, model_id: ID, params: { 'cursor' => 'old', 'id' => ID })
    params = URI.decode_www_form(URI(nav.url('/model-callbacks', 'id' => FILE)).query).to_h
    assert_equal({ model_callbacks: true }, Thistle::Map::NavigationContext.continuation('/model-callbacks', params))
    refute params.key?('cursor')
    assert_raises(Thistle::Map::Investigation::Invalid) { Thistle::Map::NavigationContext.new(generation: G, model_id: ID, source_position: [FILE, 10001]) }
  end
end

if $PROGRAM_NAME == __FILE__ || ENV['THISTLE_MAP_PURE'] == '1'
  Minitest.after_run { raise 'Pure nav loaded native/framework' if defined?(Thistle::Native) || defined?(Rails) || defined?(ActiveRecord) }
end
