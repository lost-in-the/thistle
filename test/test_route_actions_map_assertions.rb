# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'test_route_actions_installed'

class RouteActionsMapAssertionsTest < Minitest::Test
  def test_generic_unknowns_do_not_prove_a_card_status
    assert_raises(RuntimeError) do
      RouteActionsMapAssertions.status!('<p>Binding unknown; target unresolved</p>', 'Multiple static candidates; no definition selected')
    end
    assert_raises(RuntimeError) do
      RouteActionsMapAssertions.status!('<p>One conventional static candidate; binding unknown</p>', 'Unsupported route or naming; target unresolved')
    end
    assert_nil RouteActionsMapAssertions.status!('<p class="notice ui">Multiple static candidates; no definition selected</p>', 'Multiple static candidates; no definition selected')
  end

  def test_two_lines_of_one_definition_are_not_two_source_witnesses
    a, b = 'a' * 64, 'b' * 64
    same = RouteActionsMapAssertions.source_targets(%(<a href="/map/source?id=#{a}#L2">Source</a><a href="/map/source?id=#{a}#L8">Source</a>))
    assert_raises(RuntimeError) { RouteActionsMapAssertions.distinct_sources!(same, 2) }
    other = RouteActionsMapAssertions.source_targets(%(<a href="/map/source?id=#{b}#L3">Source</a>))
    assert_equal [a, b], RouteActionsMapAssertions.distinct_sources!(same + other, 2)
  end

end
