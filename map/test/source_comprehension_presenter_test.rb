# frozen_string_literal: true

# Pure presentation test: no App, native, framework, Rouge or saved-store runtime.
require 'minitest/autorun'
require_relative '../lib/thistle/map/source_comprehension_presenter'

class SourceComprehensionPresenterTest < Minitest::Test
  Presenter = Thistle::Map::SourceComprehensionPresenter
  GENERATION = 'a' * 64
  ID = 'b' * 64

  def projection
    fact = { 'id' => ID, 'kind' => 'method', 'name' => 'Order#label', 'evidence' => 'static',
      'path' => 'app/models/order.rb', 'location' => { 'start_line' => 2, 'end_line' => 3 } }
    { 'version' => 1, 'generation' => GENERATION, 'owner' => 'Order', 'composition' => 'identified_contributions',
      'ownership_status' => 'unique_label_candidate_binding_unknown', 'owners' => [{ 'index' => 0, 'name' => 'Order', 'kind' => 'class' }],
      'semantics' => 'Loaded owner observed; invocation unknown.', 'observed_only' => [{ 'name' => 'native_hash' }],
      'coverage' => { 'returned' => 1, 'candidate_matches_seen' => 1, 'range_complete' => true, 'scope' => 'saved owner definitions' }, 'continuation' => nil,
      'contributions' => [{ 'fact' => fact, 'owner' => 'Order', 'method_name' => 'label',
        'status' => 'observed_loaded_owner_source_binding_unknown', 'observed_owner' => 'Order',
        'source' => { 'operation' => 'source', 'id' => ID, 'generation' => GENERATION },
        'callers' => { 'operation' => 'references', 'id' => ID, 'generation' => GENERATION, 'direction' => 'incoming' } }] }
  end

  def render(data = projection, sources: nil, states: {})
    content = "# header\ndef label\n  '<script>雪</script>'\nend\n"
    sources ||= { ID => { 'fact' => data['contributions'][0]['fact'].dup, 'content' => content,
      'sha256' => Digest::SHA256.hexdigest(content), 'generation' => GENERATION } }
    @destinations = []
    destinations = @destinations
    navigation = Object.new
    navigation.define_singleton_method(:url) do |path, extras = {}|
      destinations << [path, extras]
      # Distinctive return proves the presenter did not construct a second URL.
      '/from-shared-authority?kept="q&selection"'
    end
    highlighter = lambda { |text, **| text.lines.map { |line| ERB::Util.html_escape(line.delete_suffix("\n")) } }
    continuation_url = lambda do |selector|
      destinations << ['typed-continuation', selector]
      '/root-admitted-continuation'
    end
    Presenter.new(projection: data, sources: sources, source_states: states, navigation: navigation, highlighter: highlighter, continuation_url: continuation_url).render
  end

  def test_code_is_primary_and_physical_lines_and_injected_destinations_are_preserved
    html = render
    assert_includes html, 'class="cv codeview"'
    assert_includes html, "id=\"source-#{ID}-L2\""
    assert_includes html, 'aria-label="Line 3">3</a>'
    assert_includes html, '&lt;script&gt;雪&lt;/script&gt;'
    refute_includes html, '<script>'
    assert_operator html.index('class="cv codeview"'), :<, html.index('Ownership, provenance and coverage')
    assert_operator html.index('class="cv codeview"'), :<, html.index('Owner and method outline')
    assert_includes html, 'href="/from-shared-authority?kept=&quot;q&amp;selection&quot;"'
    assert @destinations.all? { |_, extras| extras.fetch('id') == ID && !extras.key?('generation') }
    assert @destinations.any? { |path, extras| path == '/links' && extras['direction'] == 'incoming' }
    assert_includes html, '#L2'
    assert_includes html, 'native_hash: observed method; no saved definition candidate'
  end

  def test_unavailable_source_does_not_become_an_empty_or_effective_file
    html = render(sources: {})
    assert_includes html, 'source unavailable'
    assert_includes html, 'Open exact Source'
    refute_includes html, 'class="cv codeview"'
    assert_includes html, 'not a concatenated effective runtime class'
  end

  def test_not_admitted_is_distinct_from_missing_source
    html = render(sources: {}, states: { ID => { 'status' => 'not_admitted', 'reason' => 'Line bound not admitted.' } })
    assert_includes html, 'source not admitted on this page'
    refute_includes html, 'Order#label: source unavailable'
    assert_includes html, 'Line bound not admitted.'
  end

  def test_unknown_generation_digest_status_and_oversize_are_refused
    bad = projection
    bad['contributions'][0]['source']['generation'] = 'c' * 64
    assert_raises(Presenter::InvalidProjection) { render(bad) }
    bad = projection
    bad['contributions'][0]['status'] = 'effective_runtime_class'
    assert_raises(Presenter::InvalidProjection) { render(bad) }
    bad_source = { ID => { 'fact' => projection['contributions'][0]['fact'], 'generation' => GENERATION,
      'content' => 'bad', 'sha256' => 'd' * 64 } }
    assert_raises(Presenter::InvalidProjection) { render(sources: bad_source) }
    content = 'x' * (Presenter::MAX_SOURCE_BYTES + 1)
    bad_source[ID].merge!('content' => content, 'sha256' => Digest::SHA256.hexdigest(content))
    assert_raises(Presenter::InvalidProjection) { render(sources: bad_source) }
  end

  def test_continuation_remains_a_core_selector_and_keeps_unknown_precedence_visible
    data = projection
    data['contributions'][0]['status'] = 'unknown_incomplete_candidates'
    data['coverage']['candidate_matches_seen'] = 2
    data['continuation'] = { 'operation' => 'source_comprehension', 'generation' => GENERATION, 'id' => ID, 'family' => 'methods', 'cursor' => 'opaque-core-cursor' }
    html = render(data)
    assert_includes html, 'Precedence unknown: more candidates remain'
    assert_includes html, 'More saved methods'
    refute_includes html, 'More saved contributions'
    assert @destinations.any? { |path, selector| path == 'typed-continuation' && selector['cursor'] == 'opaque-core-cursor' }
  end

  def test_shared_file_highlights_the_union_and_outlines_each_physical_start_in_place
    data = projection
    second = Marshal.load(Marshal.dump(data['contributions'][0]))
    second['fact'].merge!('id' => 'c' * 64, 'name' => 'Order#duplicate_label',
      'location' => { 'start_line' => 5, 'end_line' => 6 })
    %w[source callers].each { |key| second[key]['id'] = second['fact']['id'] }
    data['contributions'] << second
    content = "# header\ndef label\n  'first'\nend\ndef duplicate_label\n  'second'\nend\n"
    sources = { ID => { 'fact' => data['contributions'][0]['fact'], 'content' => content,
      'generation' => GENERATION, 'sha256' => Digest::SHA256.hexdigest(content) } }
    html = render(data, sources: sources, states: { second['fact']['id'] => { 'status' => 'shared_file' } })
    assert_equal 1, html.scan('class="cv codeview"').length
    [2, 3, 5, 6].each { |line| assert_includes html, "class=\"source-row selected\" id=\"source-#{ID}-L#{line}\"" }
    assert_includes html, "id=\"source-#{'c' * 64}-L5\""
    assert_includes html, "href=\"#source-#{'c' * 64}-L5\""
    assert_includes html, '#L5'
    assert_equal 7, html.scan('class="ln"').length
    refute_includes html, 'class="source-row selected" id="source-' + ID + '-L4"'
  end

  def test_page_local_owner_list_retains_original_ancestry_positions
    data = projection
    data['owners'] = [
      { 'index' => 8, 'name' => 'Tagged', 'kind' => 'module' },
      { 'index' => 15, 'name' => 'Parent', 'kind' => 'class' }
    ]
    html = render(data)
    assert_includes html, '<li value="9">Tagged (module)</li>'
    assert_includes html, '<li value="16">Parent (class)</li>'
    data['owners'][0]['index'] = '<script>'
    assert_raises(Presenter::InvalidProjection) { render(data) }
  end

  def test_unknown_owner_rows_are_visible_and_keep_the_normal_family_continuation
    data = projection
    data['contributions'] = []
    data['rows'] = [
      { 'owner' => nil, 'method_name' => nil, 'status' => 'anonymous_owner_no_label_candidate' },
      { 'owner' => 'SameLabel', 'method_name' => 'label', 'visibility' => 'public', 'status' => 'duplicate_owner_label_unknown' }
    ]
    data['continuation'] = { 'operation' => 'source_comprehension', 'generation' => GENERATION,
      'id' => ID, 'family' => 'contributions', 'cursor' => 'opaque-core-cursor' }
    html = render(data, sources: {})
    assert_includes html, 'Anonymous owner: source label unavailable'
    assert_includes html, 'Duplicate owner label: source candidates unknown'
    assert_includes html, 'More saved contributions'
    refute_includes html, 'class="cv codeview"'
  end
end
