# frozen_string_literal: true

require_relative 'session_test'

class ToolsTest < Minitest::Test
  include SavedGenerationReaderSessionHelpers

  def test_late_duplicate_candidates_and_continuation_are_not_dropped
    cursor = '["recorded-v1","opaque-first-page"]'
    first = { 'generation' => GENERATION, 'anchor' => { 'id' => ID },
      'relationships' => [{ 'candidate_matches' => 6, 'candidate_search_complete' => true,
        'candidates' => [1, 2, 3, 4], 'candidate_followup' => { 'operation' => 'references',
          'generation' => GENERATION, 'id' => ID, 'candidate_link' => 7 } }],
      'next_cursor' => cursor, 'coverage' => { 'scan_complete' => false, 'not_searched' => true } }
    @reader.answer = first
    assert_equal first, call('links', id: ID)[:data]['reader']
    before = @reader.operations.length
    assert_equal 'invalid_cursor', call('links', id: ID, direction: 'incoming', cursor: cursor)[:data].dig('refusal', 'code')
    assert_equal before, @reader.operations.length
    @reader.answer = { 'generation' => GENERATION, 'anchor' => { 'id' => ID }, 'relationships' => [],
      'next_cursor' => nil, 'coverage' => { 'scan_complete' => true } }
    refute call('links', id: ID, cursor: cursor)[:error]
    assert_equal cursor, @reader.operations.last.last[:cursor]
    # Separate candidate domain: no cursor or a cursor from that exact domain.
    @reader.answer = { 'generation' => GENERATION, 'anchor' => { 'id' => ID }, 'candidate_link' => 7,
      'candidates' => [{ 'id' => OTHER }, { 'id' => ID }], 'candidate_matches' => 6,
      'candidate_search_complete' => true, 'page_complete' => true, 'next_cursor' => nil }
    assert_equal @reader.answer, call('links', id: ID, candidate_link: 7)[:data]['reader']
  end

  def test_model_family_cursor_is_session_and_family_scoped
    cursor = '["opaque-family-page"]'
    @reader.answer = { 'generation' => GENERATION, 'next_cursor' => cursor }
    refute call('model_brief', id: ID, family: 'columns')[:error]
    @reader.answer = { 'generation' => GENERATION, 'next_cursor' => nil }
    before = @reader.operations.length
    assert_equal 'invalid_cursor', call('model_brief', id: ID, family: 'associations', cursor: cursor)[:data].dig('refusal', 'code')
    assert_equal before, @reader.operations.length
    refute call('model_brief', id: ID, family: 'columns', cursor: cursor)[:error]
  end

  def test_schema_keeps_paths_out_of_source_and_limits_declared_filters
    tools = Thistle::MCP::Tools
    assert_equal 5, tools::DESCRIPTIONS.length
    schema = tools.schema('thistle_source')
    assert_equal %w[file generation id], schema['properties'].keys.sort
    assert_equal false, schema['additionalProperties']
    assert_equal 2, schema['oneOf'].length
    assert_equal 8, tools.schema('thistle_links').dig('properties', 'limit', 'maximum')
    assert_includes tools::DESCRIPTIONS.fetch('thistle_model_brief'), 'outside this adapter, not absent from Core'
    assert_includes tools::DESCRIPTIONS.fetch('thistle_source'), 'not revalidated by this call'
  end
end
