# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../../test/fixtures/route_actions/source_answers'
require_relative '../lib/thistle/map/route_actions_presenter'

class RouteActionsEvidenceTest < Minitest::Test
  def navigation
    Object.new.tap { |n| def n.url(*) = '/saved-source' }
  end

  def test_escape_inflation_is_an_explicit_map_budget_refusal
    page = RouteActionsAnswers.page
    page['route']['attributes']['large_constraint'] = '&' * 15_000
    Thistle::Map::RouteActionsPresenter.validate!(page, generation: RouteActionsAnswers::GENERATION, id: RouteActionsAnswers::ROUTE)
    presenter = Thistle::Map::RouteActionsPresenter.new(navigation: navigation)
    error = assert_raises(Thistle::Map::Investigation::Limit) { presenter.render(page) }
    assert_includes error.message, 'display budget'
  end
end
