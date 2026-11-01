# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/map/navigation_context'

class PassageNavigationTest < Minitest::Test
  def params = {'generation'=>'a'*64,'id'=>'b'*64,'action'=>'c'*64}
  def cursor(action: 'c'*64, family: 'sequence', offset: 1)
    JSON.generate(['recorded-v1','a'*64,Digest::SHA256.hexdigest(JSON.generate(['passage','b'*64,action,family])),offset,0])
  end
  def test_exact_scope_refused_before_factory_and_destination_resets
    klass = Thistle::Map::NavigationContext
    assert_equal({passage:'sequence'},klass.continuation('/passage/sequence',params.merge('cursor'=>cursor)))
    [params.merge('action'=>'d'*64,'cursor'=>cursor),params.merge('cursor'=>cursor(family:'export')),params.merge('page'=>'1'),params.reject { |k,_| k=='generation' }].each do |bad|
      assert_raises(Thistle::Map::Investigation::Invalid) {klass.continuation('/passage/sequence',bad)}
    end
    nav = klass.new(generation:'a'*64,params:params.merge('cursor'=>cursor))
    changed = URI.decode_www_form(URI.parse(nav.url('/passage/sequence','action'=>'d'*64)).query).to_h
    refute changed.key?('cursor')
    source = URI.decode_www_form(URI.parse(nav.url('/source','id'=>'e'*64)).query).to_h
    assert_equal %w[generation id],source.keys.sort
  end
  def test_full_collection_search_drop_and_nine_field_budget
    selection = Thistle::Map::Investigation.new(generation:'a'*64,ids:(1..24).map { |n| format('%064x',n) })
    nav = Thistle::Map::NavigationContext.new(generation:'a'*64,selection:selection,
      params:params.merge('q'=>'?'*256,'prefix'=>'?'*500,'kind'=>'route','domain'=>'all'))
    url = URI.parse(nav.url('/passage/sequence','id'=>'b'*64,'action'=>'c'*64,'cursor'=>cursor))
    fields = URI.decode_www_form(url.query).to_h
    assert nav.search_omitted
    assert_equal selection.ids,fields.fetch('selection').split(',')
    assert_operator url.query.bytesize,:<=,4096
    assert_operator fields.length,:<=,9
    refute fields.key?('q')
  end
end
