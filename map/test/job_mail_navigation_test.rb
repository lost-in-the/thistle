# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/map/navigation_context'

class JobMailNavigationTest < Minitest::Test
  Navigation = Thistle::Map::NavigationContext
  Investigation = Thistle::Map::Investigation
  G = 'a' * 64
  ID = 'b' * 64

  def cursor(family, id = ID, generation = G)
    JSON.generate(['recorded-v1',generation,Digest::SHA256.hexdigest(JSON.generate(['job_mail',id,family])),1,0])
  end

  def test_all_actual_family_routes_preserve_normalized_state_and_only_destination_controls
    selection = Investigation.new(generation: G, ids: [ID])
    search = { 'q' => 'receipt', 'domain' => 'source', 'kind' => 'method', 'prefix' => 'app/' }
    nav = Navigation.new(generation: G, mount: '/map', params: search, selection: selection)
    Navigation::JOB_MAIL_FAMILIES.each do |family|
      uri = URI(nav.url("/job-mail/#{family}", 'id' => ID, 'cursor' => cursor(family)))
      params = URI.decode_www_form(uri.query).to_h
      assert_equal "/map/job-mail/#{family}", uri.path
      assert_equal [G,ID,ID,cursor(family)], params.values_at('generation','id','selection','cursor')
      assert_equal search, params.slice(*search.keys)
      assert_operator uri.query.bytesize, :<=, 4096
      assert_operator params.length, :<=, 9
      refute params.key?('family')
      assert_equal({ job_mail: family },Navigation.continuation("/job-mail/#{family}",params))
    end
  end

  def test_scope_and_field_refusals_precede_mock_reader_factory
    valid = { 'generation' => G,'id' => ID,'cursor' => cursor('handoff') }
    invalid = [valid.merge('generation' => 'c' * 64),valid.merge('id' => 'd' * 64),valid.merge('cursor' => cursor('policy')),
      valid.merge('cursor' => '{'),valid.merge('cursor' => 'x' * 513),valid.merge('candidate' => '0'),
      valid.merge('direction' => 'outgoing'),valid.merge('family' => 'handoff'),valid.merge('page' => '1'),valid.reject { |key,_| key == 'generation' }]
    opened = 0
    invalid.each do |params|
      assert_raises(Investigation::Invalid) do
        Navigation.continuation('/job-mail/handoff',params)
        opened += 1
      end
    end
    assert_equal 0,opened
    assert_raises(Investigation::Invalid) { Navigation.new(generation: G).url('/job-mail/evaluate','id' => ID) }
  end

  def test_full_collection_continuation_drops_search_atomically_without_losing_selection
    ids = [ID] + (1..23).map { |n| n.to_s(16).rjust(64,'0') }
    selection = Investigation.new(generation: G,ids: ids)
    search = { 'q' => '雪' * 80,'domain' => 'source','prefix' => 'x' * 1500 }
    params = selection.parameters.merge(search).merge('id' => ID)
    assert_operator URI.encode_www_form(params).bytesize, :<=,4096
    nav = Navigation.new(generation: G,params: params,selection: selection)
    uri = URI(nav.url('/job-mail/handoff','id' => ID,'cursor' => cursor('handoff')))
    values = URI.decode_www_form(uri.query).to_h
    assert nav.search_omitted
    assert_empty values.keys & Navigation::SEARCH_FIELDS
    assert_equal [G,ID,ids.join(','),cursor('handoff')],values.values_at('generation','id','selection','cursor')
    assert_operator uri.query.bytesize, :<=,4096
    assert_equal({job_mail:'handoff'},Navigation.continuation('/job-mail/handoff',values))
  end
end
