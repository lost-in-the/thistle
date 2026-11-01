# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/model_neighborhood_presenter'

# Independent handwritten primitive answers; not a native or framework fixture.
module ModelNeighborhoodAnswers
  G = 'a' * 64
  ID = 'b' * 64
  OTHER = 'c' * 64
  def self.identity(id = ID, name = 'Order <unsafe>')
    { 'id' => id, 'name' => name, 'kind' => id == ID ? 'rails_model' : 'class',
      'evidence' => id == ID ? 'runtime' : 'static', 'path' => id == ID ? nil : 'app/models/item.rb',
      'location' => id == ID ? nil : { 'start_line' => 2, 'end_line' => 5 } }
  end

  def self.page(family: 'edges', direction: 'outgoing', type: 'all', candidate: nil)
    root = identity
    association = { 'name' => 'items', 'macro' => 'has_many', 'target' => 'Item & more', 'polymorphic' => false,
      'through' => nil, 'scope' => 'none', 'options' => { 'dependent' => { 'kind' => 'symbol', 'value' => 'destroy' } }, 'omitted_options' => 0 }
    edge = { 'kind' => 'edge', 'type' => 'association', 'direction' => direction, 'relation' => 'has_many', 'origin' => root,
      'target_label' => 'Item & more', 'target_status' => 'one_saved_representation_binding_unknown',
      'association' => association, 'witness' => { 'fact_id' => ID, 'family' => 'associations', 'ordinal' => 0 },
      'candidate_matches' => 1, 'candidate_search_complete' => true, 'candidate_known_omitted' => 0,
      'candidate_selector' => 'a:0', 'candidates' => [identity(OTHER, 'Item & more')], 'binding' => 'unknown' }
    { 'version' => 1, 'generation' => G, 'root' => root, 'model' => { 'table' => 'orders', 'primary_key' => ['id'] },
      'family' => family, 'direction' => direction, 'type' => type, 'candidate' => candidate,
      'items' => family == 'edges' ? [edge] : [], 'next_cursor' => nil, 'semantics' => 'Recorded evidence; execution unknown.',
      'coverage' => { 'page_complete' => true, 'unsearched' => false, 'known_remaining' => 0,
        'default_presence' => 'not_recorded', 'database_constraints_indexes_on_delete' => 'not_recorded',
        'candidate_count_unit' => 'saved_representations_not_distinct_model_definitions' } }
  end
end

class ModelNeighborhoodPresenterTest < Minitest::Test
  def render(answer, **options)
    params = { 'generation' => ModelNeighborhoodAnswers::G, 'id' => ModelNeighborhoodAnswers::ID, 'q' => 'Order' }
    nav = Thistle::Map::NavigationContext.new(generation: ModelNeighborhoodAnswers::G, params: params)
    Thistle::Map::ModelNeighborhoodPresenter.new(answer, navigation: nav, generation: ModelNeighborhoodAnswers::G,
      id: ModelNeighborhoodAnswers::ID, family: answer.fetch('family'), direction: answer.fetch('direction'),
      type: answer.fetch('type'), candidate: answer['candidate'], **options).render
  end

  def test_named_list_and_svg_agree_and_escape_and_link_to_physical_saved_source
    html = render(ModelNeighborhoodAnswers.page)
    assert_equal ['0'], html.scan(/data-neighborhood-edge="(\d+)"/).flatten
    assert_equal ['0'], html.scan(/data-neighborhood-diagram-edge="(\d+)"/).flatten
    assert_operator html.index('Named relationships</h2>'), :<, html.index('<svg')
    assert_includes html, 'Order &lt;unsafe&gt; → Item &amp; more'
    refute_includes html, '<unsafe>'
    assert_includes html, '#L2'
    assert_includes html, "generation=#{ModelNeighborhoodAnswers::G}"
    assert_includes html, 'Columns</a>'
    assert_includes html, 'Database facts</a>'
    assert_includes html, 'physical DB foreign keys and ON DELETE were not recorded'
  end

  def test_default_states_do_not_invent_default_presence_or_database_absence
    answer = ModelNeighborhoodAnswers.page(family: 'columns')
    defaults = [false, 0, '', nil].map { |v| { 'kind' => 'literal', 'value' => v } } + [{ 'kind' => 'expression' }, { 'kind' => 'opaque' }, nil]
    answer['items'] = defaults.each_with_index.map do |tagged, index|
      { 'kind' => 'column', 'ordinal' => index, 'column' => { 'name' => "c#{index}", 'type' => 'string', 'sql_type' => 'text',
        'null' => false, 'default' => tagged, 'default_recorded' => index != 6, 'default_presence' => 'not_recorded' } }
    end
    html = render(answer)
    ['false (literal', '0 (literal', '&quot;&quot; (literal', 'null (literal', 'Expression (text not recorded', 'Opaque value', 'Value not recorded'].each { |text| assert_includes html, text }
    assert_includes render(ModelNeighborhoodAnswers.page(family: 'database')), 'unavailable, not known absent'
  end

  def test_forged_witness_scope_id_and_continuation_refuse
    answer = ModelNeighborhoodAnswers.page
    answer['items'][0]['witness']['fact_id'] = 'd' * 64
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
    answer = ModelNeighborhoodAnswers.page
    answer['items'][0]['candidates'][0]['id'] = 'javascript:alert(1)'
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
    answer = ModelNeighborhoodAnswers.page
    answer['coverage']['page_complete'] = false
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
  end

  def test_unknown_target_is_retained_and_candidate_omissions_are_named
    answer = ModelNeighborhoodAnswers.page
    edge = answer['items'][0]
    edge['target_label'] = edge['association']['target'] = nil
    edge['target_status'] = 'unknown_target'
    edge['candidates'] = []
    edge['candidate_matches'] = 0
    assert_includes render(answer), 'Unknown / polymorphic target'
    edge['target_label'] = edge['association']['target'] = 'User'
    edge['candidate_matches'] = 6
    edge['candidate_known_omitted'] = 6
    html = render(answer)
    assert_includes html, 'Inspect all saved target representations'
    assert_includes html, 'candidate=a%3A0'
    assert_includes html, 'not distinct model-definition counts'
  end

  def test_incoming_reference_keeps_original_link_ordinal_and_global_candidate_uncertainty
    answer = ModelNeighborhoodAnswers.page(direction: 'incoming', type: 'reference')
    origin = ModelNeighborhoodAnswers.identity(ModelNeighborhoodAnswers::OTHER, 'ReportBuilder#orders')
    recorded = { 'origin' => origin, 'link' => { 'relation' => 'calls', 'target' => '::Order', 'resolution' => 'unresolved' },
      'link_ordinal' => 7, 'candidate_label' => '::Order', 'candidates' => nil, 'detail_omitted' => false }
    answer['items'] = [{ 'kind' => 'edge', 'type' => 'reference', 'direction' => 'incoming', 'origin' => origin,
      'relation' => 'calls', 'target_label' => '::Order', 'target_status' => 'selected_label_binding_unknown',
      'binding' => 'unknown', 'candidate_matches' => 1, 'candidate_search_complete' => false, 'candidate_known_omitted' => 0,
      'candidate_selector' => nil, 'candidates' => [answer['root']], 'recorded' => recorded }]
    html = render(answer)
    assert_includes html, 'ReportBuilder#orders → ::Order'
    assert_includes html, 'Original recorded reference'
    assert_includes html, '&quot;link_ordinal&quot;: 7'
    assert_includes html, 'candidate search complete: false'
    assert_equal html.scan(/data-neighborhood-edge="(\d+)"/), html.scan(/data-neighborhood-diagram-edge="(\d+)"/)
  end
end
