# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/map/navigation_context'

class NavigationContextTest < Minitest::Test
  Context = Thistle::Map::NavigationContext
  Generation = 'a' * 64
  Fact = 'b' * 64
  Selected = 'c' * 64

  def context(params = {})
    Context.new(generation: Generation, mount: '/map', params: params,
      selection: Thistle::Map::Investigation.new(generation: Generation, ids: [Selected]))
  end

  def params(href)
    URI.decode_www_form(URI.parse(href).query).to_h
  end

  def cursor(scope, generation: Generation, position: 8)
    JSON.generate(['recorded-v1', generation, Digest::SHA256.hexdigest(JSON.generate(scope)), position, 0])
  end

  def test_callback_file_source_clears_current_id_and_retains_normalized_context
    search = { 'q' => 'Order', 'domain' => 'metadata', 'kind' => 'rails_model', 'prefix' => 'app/' }
    nav = context(search.merge('id' => Fact, 'direction' => 'incoming', 'cursor' => 'stale', 'token' => 'never-forward'))
    target = params(nav.url('/source', 'id' => nil, 'file' => 'd' * 64))
    assert_equal search, target.slice(*search.keys)
    assert_equal Selected, target['selection']
    assert_equal Generation, target['generation']
    assert_equal 'd' * 64, target['file']
    refute target.key?('id')
    refute target.key?('cursor')
    refute target.key?('token')
    new_selection = Thistle::Map::Investigation.new(generation: Generation, ids: [Selected, Fact])
    assert_equal [Selected, Fact].join(','), params(nav.url('/source', selection: new_selection))['selection']
    assert_equal Selected, params(nav.url('/'))['selection']
    wrong = Thistle::Map::Investigation.new(generation: 'e' * 64, ids: [Selected])
    assert_raises(ArgumentError) { nav.url('/source', selection: wrong) }
  end

  def test_drop_search_before_collection_on_byte_or_field_budget
    nav = context('q' => 'Order', 'prefix' => 'x' * 4000)
    target = nav.url('/source', 'id' => Fact)
    assert nav.search_omitted
    assert_equal Selected, params(target)['selection']
    refute params(target).key?('q')
    assert_operator URI.parse(target).query.bytesize, :<=, 4096
    nav = context('id' => Fact, 'cursor' => 'z' * 4100)
    assert_raises(Thistle::Map::Investigation::Limit) { nav.url('/brief/columns') }
  end

  def test_new_fact_clears_inherited_direction_and_position_but_explicit_controls_win
    nav = context('id' => Fact, 'direction' => 'incoming', 'page' => '3',
      'cursor' => 'old-position', 'candidate' => '2')
    changed = params(nav.url('/links', 'id' => Selected))
    assert_equal Selected, changed['id']
    refute changed.key?('direction')
    refute changed.key?('page')
    continued = params(nav.url('/references/outgoing', 'id' => Selected))
    refute continued.key?('cursor')
    refute continued.key?('candidate')
    same = params(nav.url('/links'))
    assert_equal 'incoming', same['direction']
    assert_equal '3', same['page']
    explicit = params(nav.url('/links', 'id' => Selected, 'direction' => 'incoming', 'page' => '2'))
    assert_equal 'incoming', explicit['direction']
    assert_equal '2', explicit['page']
  end

  def test_scope_checked_before_reader_and_route_fields_stay_at_most_nine
    scope = ['model_brief', Fact, 'columns']
    valid = { 'generation' => Generation, 'id' => Fact, 'selection' => Selected, 'cursor' => cursor(scope) }
    assert_equal 'columns', Context.continuation('/brief/columns', valid)[:family]
    [valid.merge('generation' => 'e' * 64), valid.merge('id' => 'e' * 64),
      valid.merge('cursor' => '{}'), valid.merge('cursor' => 'x' * 513),
      valid.merge('cursor' => cursor(['model_brief', Fact, 'associations'])),
      valid.merge('candidate' => '0')].each do |bad|
      assert_raises(Thistle::Map::Investigation::Invalid) { Context.continuation('/brief/columns', bad) }
    end
    ref_scope = ['references', Fact, false, 0]
    ref = { 'generation' => Generation, 'id' => Fact, 'cursor' => cursor(ref_scope), 'candidate' => '0' }
    assert_equal 0, Context.continuation('/references/outgoing', ref)[:candidate]
    assert_raises(Thistle::Map::Investigation::Invalid) { Context.continuation('/references/incoming', ref) }
    href = context('q' => 'Order', 'domain' => 'metadata', 'kind' => 'rails_model', 'prefix' => 'app/').url(
      '/references/outgoing', 'id' => Fact, 'cursor' => cursor(ref_scope), 'candidate' => '0')
    assert_equal 9, URI.decode_www_form(URI.parse(href).query).length
    assert_operator URI.parse(href).query.bytesize, :<=, 4096
  end
end
