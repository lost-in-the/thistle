# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/map/find_presenter'

class FindPresenterTest < Minitest::Test
  def test_model_entry_and_capture_coverage_are_explicit_and_escaped
    presenter = Thistle::Map::FindPresenter.new(generation: 'old')
    families = { 'inventory' => 'partial', 'columns' => { 'observed' => 1, 'unavailable' => 1, 'unknown' => 0 },
      'associations' => { 'observed' => 2, 'unavailable' => 0, 'unknown' => 0 } }
    result = { 'generation' => 'old', 'status' => 'complete', 'truncated' => false,
      'search_coverage' => { 'metadata_facts_searched' => 2, 'metadata_facts_not_searched' => 0,
        'metadata_fields_omitted' => 0, 'model_capture_families' => families },
      'results' => [{ 'origin' => 'metadata', 'name' => '<Order>', 'fact_id' => 'abc', 'path' => nil,
        'field' => 'attributes.model.columns.entries[].name', 'entry_index' => 1, 'entry_name' => '<state>' }] }
    html = presenter.render(result)
    assert_includes html, '/source?generation=old&amp;id=abc'
    assert_includes html, '&lt;Order&gt;'
    assert_includes html, 'attributes.model.columns.entries[].name · entry 1: &lt;state&gt;'
    assert_includes html, 'Source unavailable'
    assert_includes html, 'Saved model inventory: partial'
    assert_includes html, 'unavailable 1; unknown 0'
    assert_includes html, 'No match concerns searched saved names only'
    empty = presenter.render(result.merge('results' => []))
    assert_includes empty, 'Observed empty metadata differs from unavailable metadata'
    assert_includes empty, 'No result rows returned'
  end

  def test_escapes_snippet_and_pins_captured_file_and_line
    presenter = Thistle::Map::FindPresenter.new(generation: 'old', mount: '/map')
    html = presenter.render('generation' => 'old', 'status' => 'partial', 'truncated' => true,
      'results' => [{ 'origin' => 'source', 'path' => 'spec/<case>.rb', 'snippet' => '<script>bad</script>',
                      'span' => { 'start_line' => 3 } }])
    reference = Thistle::Map::FindPresenter.file_reference('spec/<case>.rb')
    assert_includes html, "generation=old&amp;file=#{reference}#L3"
    assert_includes html, '&lt;script&gt;bad&lt;/script&gt;'
    refute_includes html, '<script>'
    assert_includes html, 'Search is incomplete'
    assert_includes html, 'Results were truncated'
  end

  def test_metadata_navigation_and_generation_mismatch
    presenter = Thistle::Map::FindPresenter.new(generation: 'old', search: {
      'q' => 'A & B', 'domain' => 'metadata', 'kind' => 'class', 'prefix' => 'app/', 'id' => 'discarded' })
    html = presenter.render('generation' => 'old', 'status' => 'complete', 'truncated' => false,
      'results' => [{ 'origin' => 'metadata', 'name' => 'A', 'fact_id' => 'abc' }])
    assert_includes html, '/source?generation=old&amp;id=abc'
    assert_includes html, '&amp;q=A+%26+B&amp;domain=metadata&amp;kind=class&amp;prefix=app%2F'
    refute_includes html, 'discarded'
    assert_raises(ArgumentError) do
      presenter.render('generation' => 'new', 'status' => 'complete', 'truncated' => false, 'results' => [])
    end
  end

  def test_oversized_search_context_is_explicit_without_breaking_pinned_source
    presenter = Thistle::Map::FindPresenter.new(generation: 'a' * 64,
      search: { 'q' => 'needle', 'prefix' => 'x' * 4000 })
    html = presenter.render('generation' => 'a' * 64, 'status' => 'complete', 'truncated' => false,
      'results' => [{ 'origin' => 'source', 'path' => 'spec/file.rb', 'span' => { 'start_line' => 2 } }])
    href = html[/data-result-link href="([^"]+)"/, 1].gsub('&amp;', '&')
    params = URI.decode_www_form(URI.parse(href).query).to_h
    assert_equal 'a' * 64, params['generation']
    assert_equal Thistle::Map::FindPresenter.file_reference('spec/file.rb'), params['file']
    refute params.key?('prefix')
    assert_operator URI.parse(href).query.bytesize, :<=, Thistle::Map::FindPresenter::MAX_QUERY_BYTES
    assert_includes html, 'Search context exceeds the link budget; use Back'
  end
end
