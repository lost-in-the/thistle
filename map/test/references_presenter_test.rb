# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/references_presenter'

class ThistleReferencesPresenterTest < Minitest::Test
  def test_empty_partial_no_source_escaping_and_generation_refusal
    fact = { 'id' => 'b' * 64, 'name' => '<img>', 'kind' => 'class', 'path' => nil, 'evidence' => 'runtime' }
    result = { 'generation' => 'a' * 64, 'direction' => 'incoming',
      'coverage' => { 'known_matches' => 1, 'known_omitted' => 0, 'scan_complete' => false, 'capture_partial' => true },
      'relationships' => [{ 'origin' => fact, 'link' => { 'relation' => '<script>', 'target' => '<svg>', 'resolution' => 'unresolved' },
        'detail_omitted' => false, 'candidates' => [fact], 'candidate_matches' => 1, 'candidate_search_complete' => false }] }
    presenter = Thistle::Map::ReferencesPresenter.new(generation: 'a' * 64, mount: '/map')
    html = presenter.render(result)
    assert_includes html, '&lt;script&gt;'
    assert_includes html, '&lt;img&gt;'
    refute_includes html, '<script>'
    assert_includes html, 'No captured source'
    assert_includes html, 'additional input was not searched'
    assert_includes html, 'Capture partial'
    result['relationships'][0]['detail_omitted'] = true
    omitted = presenter.render(result)
    assert_includes omitted, "origin's Links page"
    refute_includes omitted, 'outgoing details remain below'
    result['relationships'] = []
    assert_includes presenter.render(result), 'does not establish that the model has no references'
    result['generation'] = 'c' * 64
    assert_raises(Thistle::InvalidSnapshot) { presenter.render(result) }
  end
end
