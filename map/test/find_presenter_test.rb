# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/map/find_presenter'

class FindPresenterTest < Minitest::Test
  def test_escapes_snippet_and_pins_captured_file_and_line
    presenter = Thistle::Map::FindPresenter.new(generation: 'old', mount: '/map')
    html = presenter.render('generation' => 'old', 'status' => 'partial', 'truncated' => true,
      'results' => [{ 'origin' => 'source', 'path' => 'spec/<case>.rb', 'snippet' => '<script>bad</script>',
                      'span' => { 'start_line' => 3 } }])
    assert_includes html, 'generation=old&amp;path=spec%2F%3Ccase%3E.rb#L3'
    assert_includes html, '&lt;script&gt;bad&lt;/script&gt;'
    refute_includes html, '<script>'
    assert_includes html, 'Search is incomplete'
    assert_includes html, 'Results were truncated'
  end

  def test_metadata_navigation_and_generation_mismatch
    presenter = Thistle::Map::FindPresenter.new(generation: 'old')
    html = presenter.render('generation' => 'old', 'status' => 'complete', 'truncated' => false,
      'results' => [{ 'origin' => 'metadata', 'name' => 'A', 'fact_id' => 'abc' }])
    assert_includes html, '/source?generation=old&amp;id=abc'
    assert_raises(ArgumentError) do
      presenter.render('generation' => 'new', 'status' => 'complete', 'truncated' => false, 'results' => [])
    end
  end
end
