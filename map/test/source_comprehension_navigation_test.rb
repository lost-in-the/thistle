# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../lib/thistle/map/navigation_context'

class SourceComprehensionNavigationTest < Minitest::Test
  Navigation = Thistle::Map::NavigationContext
  Investigation = Thistle::Map::Investigation
  G = 'a' * 64
  ID = 'b' * 64

  def cursor(family = 'contributions', generation = G)
    JSON.generate(['recorded-v1', generation, Digest::SHA256.hexdigest(JSON.generate(['source_comprehension', ID, family])), 0, 1])
  end

  def test_both_real_routes_keep_id_cursor_generation_search_and_selection
    selection = Investigation.new(generation: G, ids: [ID])
    search = { 'q' => 'Order', 'domain' => 'source', 'kind' => 'class', 'prefix' => 'app/' }
    nav = Navigation.new(generation: G, mount: '/map', params: search, selection: selection)
    %w[contributions methods].each do |family|
      path = "/comprehension/#{family}"
      url = nav.url(path, 'id' => ID, 'cursor' => cursor(family))
      uri = URI(url)
      values = URI.decode_www_form(uri.query).to_h
      assert_equal '/map' + path, uri.path
      assert_equal search, values.slice(*search.keys)
      assert_equal [G, ID, ID, cursor(family)], values.values_at('generation', 'id', 'selection', 'cursor')
      refute values.key?('family')
      assert_operator uri.query.bytesize, :<=, 4096
      assert_operator values.length, :<=, 9
      assert_equal({ comprehension: family }, Navigation.continuation(path, values))
    end
  end

  def test_malformed_scope_is_refused_before_any_mock_reader_factory
    valid = { 'generation' => G, 'id' => ID, 'cursor' => cursor }
    invalid = [valid.merge('generation' => 'c' * 64), valid.merge('id' => 'd' * 64), valid.merge('cursor' => cursor('methods')),
      valid.merge('cursor' => '{'), valid.merge('cursor' => 'x' * 513), valid.merge('candidate' => '0'), valid.reject { |key, _| key == 'generation' }]
    calls = 0
    invalid.each do |params|
      assert_raises(Investigation::Invalid) do
        Navigation.continuation('/comprehension/contributions', params)
        calls += 1 # mock factory follows the normalized route control
      end
    end
    assert_equal 0, calls
    assert_raises(Investigation::Invalid) { Navigation.new(generation: G).url('/comprehension/other', 'id' => ID) }
  end

  def test_source_and_incoming_links_use_the_same_authority_and_clear_cursor
    selection = Investigation.new(generation: G, ids: [ID])
    nav = Navigation.new(generation: G, params: { 'id' => ID, 'cursor' => cursor, 'q' => 'Order' }, selection: selection)
    ['/source', '/links'].each do |path|
      values = URI.decode_www_form(URI(nav.url(path, 'id' => 'c' * 64, 'direction' => 'incoming')).query).to_h
      assert_equal [G, 'c' * 64, ID, 'Order'], values.values_at('generation', 'id', 'selection', 'q')
      refute values.key?('cursor')
      assert_equal 'incoming', values['direction'] if path == '/links'
    end
  end

  def test_cursor_expansion_drops_search_atomically_with_notice_without_losing_selection
    ids = [ID] + (1..23).map { |n| n.to_s(16).rjust(64, '0') }
    selection = Investigation.new(generation: G, ids: ids)
    search = { 'q' => '雪' * 80, 'domain' => 'source', 'prefix' => 'x' * 1500 }
    initial = selection.parameters.merge(search).merge('id' => ID)
    assert_operator URI.encode_www_form(initial).bytesize, :<=, 4096
    nav = Navigation.new(generation: G, params: initial, selection: selection)
    uri = URI(nav.url('/comprehension/contributions', 'id' => ID, 'cursor' => cursor))
    params = URI.decode_www_form(uri.query).to_h
    assert nav.search_omitted
    assert_empty params.keys & Navigation::SEARCH_FIELDS
    assert_equal [G, ID, ids.join(','), cursor], params.values_at('generation', 'id', 'selection', 'cursor')
    assert_operator uri.query.bytesize, :<=, 4096
    assert_equal({ comprehension: 'contributions' }, Navigation.continuation('/comprehension/contributions', params))
  end
end
