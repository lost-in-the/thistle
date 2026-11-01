# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/map/navigation_context'

class ModelNeighborhoodNavigationTest < Minitest::Test
  G = 'a' * 64
  ID = 'b' * 64
  def token(family: 'edges', direction: 'outgoing', type: 'all', candidate: nil)
    JSON.generate(['recorded-v1', G, Digest::SHA256.hexdigest(JSON.generate(['model_neighborhood', ID, family, direction, type, candidate])), 1, 0])
  end
  def test_exact_family_direction_type_model_generation_and_candidate_scope
    params = { 'generation' => G, 'id' => ID, 'cursor' => token }
    klass = Thistle::Map::NavigationContext
    assert_equal 'edges', klass.continuation('/model-neighborhood/edges/outgoing/all', params).dig(:neighborhood, :family)
    %w[/model-neighborhood/edges/incoming/all /model-neighborhood/edges/outgoing/reference /model-neighborhood/columns/outgoing/all].each do |path|
      assert_raises(Thistle::Map::Investigation::Invalid) { klass.continuation(path, params) }
    end
    [{ 'id' => 'c' * 64 }, { 'generation' => 'd' * 64 }, { 'page' => '1' }, { 'candidate' => 'a:0' }].each do |extra|
      assert_raises(Thistle::Map::Investigation::Invalid) { klass.continuation('/model-neighborhood/edges/outgoing/all', params.merge(extra)) }
    end
    candidates = params.merge('candidate' => 'a:0', 'cursor' => token(family: 'candidates', candidate: 'a:0'))
    assert klass.continuation('/model-neighborhood/candidates/outgoing/all', candidates)
    assert_raises(Thistle::Map::Investigation::Invalid) { klass.continuation('/model-neighborhood/candidates/outgoing/all', candidates.merge('candidate' => 'a:1')) }
    assert_raises(Thistle::Map::Investigation::Invalid) { klass.continuation('/model-neighborhood/candidates/outgoing/reference', candidates.reject { |key, _| key == 'cursor' }) }
  end

  def test_full_collection_preserved_search_drops_atomically_and_controls_do_not_leak
    params = { 'generation' => G, 'id' => ID, 'selection' => (1..24).map { |n| n.to_s(16).rjust(64, '0') }.join(','),
      'q' => 'x' * 256, 'kind' => 'class', 'domain' => 'all', 'prefix' => 'app/', 'cursor' => token, 'candidate' => 'a:1' }
    selection = Thistle::Map::Investigation.from_params(params)
    nav = Thistle::Map::NavigationContext.new(generation: G, params: params, selection: selection)
    url = nav.url('/model-neighborhood/candidates/outgoing/all', 'candidate' => 'a:0', 'cursor' => token(family: 'candidates', candidate: 'a:0'))
    values = URI.decode_www_form(URI.parse(url).query).to_h
    assert_equal params['selection'], values['selection']
    assert_operator values.size, :<=, 9
    assert_operator URI.parse(url).query.bytesize, :<=, 4096
    assert_empty values.keys & %w[q kind domain prefix] if nav.search_omitted
    source = URI.decode_www_form(URI.parse(nav.url('/source', 'id' => ID)).query).to_h
    assert_empty source.keys & %w[candidate cursor direction]
    changed = URI.decode_www_form(URI.parse(nav.url('/model-neighborhood/edges/incoming/all', 'id' => 'e' * 64)).query).to_h
    refute changed.key?('cursor')
  end
end
