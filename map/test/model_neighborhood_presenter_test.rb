# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/model_neighborhood_presenter'
if $PROGRAM_NAME == __FILE__
  raise 'Pure presenter activated App, Native or Rails' if defined?(Thistle::Map::App) || defined?(Thistle::Native) || defined?(Rails) || defined?(ActiveRecord)
end

# Literal Rust-shaped public DTOs. No Native, App, framework or store is loaded.
module ModelNeighborhoodAnswers
  G = 'a' * 64
  ID = 'b' * 64
  OTHER = 'c' * 64
  SEMANTICS = 'Saved one-hop evidence: declarations, references and DB constraints are distinct. Name candidates are saved representations, not distinct definitions or resolved bindings. Missing targets may be unloaded/uncaptured. Runtime/source coherence and execution remain unknown. Empty searched evidence never proves absence.'
  def self.identity(id = ID, name = 'Order <unsafe>')
    { 'id' => id, 'name' => name, 'kind' => id == ID ? 'rails_model' : 'class',
      'evidence' => id == ID ? 'runtime' : 'static', 'path' => id == ID ? nil : 'app/models/item.rb',
      'location' => id == ID ? nil : { 'start_line' => 2, 'end_line' => 5, 'start_byte' => 0, 'end_byte' => 256 } }
  end

  def self.page(family: 'edges', direction: 'outgoing', type: 'all', candidate: nil)
    root = identity
    association = { 'name' => 'items', 'macro' => 'has_many', 'target' => 'Item & more', 'polymorphic' => false,
      'through' => nil, 'scope' => 'none', 'options' => { 'dependent' => { 'kind' => 'symbol', 'value' => 'destroy' } }, 'omitted_options' => 0 }
    edge = { 'kind' => 'edge', 'type' => 'association', 'direction' => direction, 'relation' => 'has_many', 'origin_id' => ID,
      'target_label' => 'Item & more', 'target_status' => 'one_saved_representation_binding_unknown',
      'association' => association, 'witness' => { 'fact_id' => ID, 'family' => 'associations', 'ordinal' => 0 },
      'candidate_matches' => 1, 'candidate_search_complete' => true, 'candidate_known_omitted' => 0,
      'candidate_selector' => 'a:0', 'candidates' => [identity(OTHER, 'Item & more')], 'binding' => 'unknown' }
    { 'version' => 1, 'generation' => G, 'root' => root,
      'model' => { 'name' => root['name'], 'table' => 'orders', 'primary_key' => ['id'], 'base_class' => 'Order', 'superclass' => 'ApplicationRecord',
        'abstract' => false, 'inheritance_column' => 'type', 'source' => 'unavailable', 'coherence' => 'unknown' },
      'family' => family, 'direction' => direction, 'type' => type, 'candidate' => candidate, 'candidate_context' => nil,
      'items' => family == 'edges' ? [edge] : [], 'next_cursor' => nil, 'semantics' => SEMANTICS,
      'coverage' => { 'page_complete' => true, 'unsearched' => false, 'known_remaining' => 0, 'recorded_candidates_total' => nil,
        'columns_status' => 'observed', 'associations_status' => 'observed', 'recorded_associations' => 12,
        'capture_partial_or_unknown' => true, 'noncomplete_capture_families' => [
          { 'family' => 'ruby_declarations', 'status' => 'partial' }, { 'family' => 'dynamic_resolution', 'status' => 'unavailable' },
          { 'family' => 'execution_trace', 'status' => 'unavailable' }, { 'family' => 'rails_routes', 'status' => 'unavailable' },
          { 'family' => 'rails_models', 'status' => 'partial' }, { 'family' => 'rails_model_effects', 'status' => 'unavailable' }],
        'capture_families' => 10, 'capture_families_not_examined' => 0, 'last_reference_step' => nil,
        'default_presence' => 'not_recorded', 'database_constraints_indexes_on_delete' => 'not_recorded',
        'candidate_count_unit' => 'saved_representations_not_distinct_model_definitions' },
      'cost' => { 'reader_open' => { 'facts' => 1200, 'fact_visits' => 6000 },
        'recorded_directory' => { 'status' => 'complete', 'built_this_request' => true, 'facts_visited' => 1200,
          'key_bytes' => 30000, 'sort_comparisons' => 11000, 'sort_compared_label_bytes' => 200000, 'retained_bytes' => 9640 },
        'reference_attempts' => 0, 'completed_reference_steps' => 0,
        'completed_step_work' => { 'facts_scanned' => 0, 'links_scanned' => 0, 'comparisons' => 0, 'label_bytes' => 0 },
        'transient_reservation_bytes' => 33554432, 'source_attempts' => 0 },
      'usage' => { 'returned_items' => family == 'edges' ? 1 : 0, 'wire_bytes_including_envelope_and_newline' => 65536 } }
  end

  def self.token(family:, direction:, type:, candidate: nil, position: 1)
    JSON.generate(['recorded-v1', G, Digest::SHA256.hexdigest(JSON.generate(['model_neighborhood', ID, family, direction, type, candidate])), position, 0])
  end

  def self.realistic(family: 'edges', direction: 'outgoing', type: 'all', candidate: nil)
    answer = page(family: family, direction: direction, type: type, candidate: candidate)
    label = 'Shop::' + 'NamedModel' * 9 + "<&'"
    if family == 'edges'
      row = answer['items'].first
      row['target_label'] = row['association']['target'] = label
      row['candidates'] = (1..4).map { |n| identity(n.to_s(16).rjust(64, '0'), label) }
      row['candidate_matches'] = 7
      row['candidate_known_omitted'] = 3
      row['target_status'] = 'ambiguous_saved_representations'
      if direction == 'incoming' || type == 'reference'
        row.delete('association'); row.delete('witness'); row.delete('origin_id')
        row['type'] = type == 'association' ? 'association' : 'reference'
        row['relation'] = row['type'] == 'association' ? 'association_target_label' : 'references'
        row['origin'] = direction == 'incoming' ? identity(OTHER, 'ReportBuilder#orders') : answer['root'].dup
        row['candidates'] = [answer['root'].dup] if direction == 'incoming'
        row['candidate_matches'] = row['candidates'].length
        row['candidate_known_omitted'] = 0
        row['candidate_search_complete'] = direction != 'incoming'
        row['candidate_selector'] = direction == 'incoming' ? nil : 'r:0'
        row['recorded'] = { 'link' => { 'relation' => row['relation'], 'target' => label, 'resolution' => 'unresolved' },
          'link_ordinal' => 0, 'detail_omitted' => false, 'match_basis' => 'label_match_binding_unknown' }
      end
    elsif family == 'columns'
      answer['items'] = [{ 'kind' => 'column', 'ordinal' => 0, 'column' => { 'name' => 'note', 'type' => 'string', 'sql_type' => 'text',
        'null' => false, 'default' => { 'kind' => 'literal', 'value' => '"&<' * 128 } } }]
    elsif family == 'candidates'
      answer['candidate_context'] = { 'kind' => candidate.start_with?('a:') ? 'association' : 'reference',
        'name' => 'reviewers', 'target_label' => '::' + label, 'selector' => candidate }
      answer['items'] = [{ 'kind' => 'candidate', 'identity' => identity(OTHER, label) }]
      answer['coverage']['recorded_candidates_total'] = 7
    end
    unless family == 'database'
      answer['coverage'].merge!('page_complete' => false, 'unsearched' => true, 'known_remaining' => nil)
      answer['next_cursor'] = token(family: family, direction: direction, type: type, candidate: candidate)
    end
    answer['usage']['returned_items'] = answer['items'].length
    3.times { answer['usage']['wire_bytes_including_envelope_and_newline'] = JSON.generate('ok' => true, 'result' => answer).bytesize + 1 }
    answer
  end

  class BudgetReader
    attr_reader :calls
    def initialize = @calls = []
    def model_neighborhood(id, **options)
      raise 'Wrong model' unless id == ID
      @calls << options
      answer = ModelNeighborhoodAnswers.realistic(**options.slice(:family, :direction, :type, :candidate))
      wire = JSON.generate('ok' => true, 'result' => answer).bytesize + 1
      raise Thistle::LimitExceeded, "Mandatory envelope and first row #{wire} exceed max_bytes #{options.fetch(:max_bytes)}" if wire > options.fetch(:max_bytes)
      answer
    end
  end
end

class ModelNeighborhoodPresenterTest < Minitest::Test
  def render(answer, navigation: nil, **options)
    params = { 'generation' => ModelNeighborhoodAnswers::G, 'id' => ModelNeighborhoodAnswers::ID, 'q' => 'Order' }
    nav = navigation || Thistle::Map::NavigationContext.new(generation: ModelNeighborhoodAnswers::G, params: params)
    Thistle::Map::ModelNeighborhoodPresenter.new(answer, navigation: nav, generation: ModelNeighborhoodAnswers::G,
      id: ModelNeighborhoodAnswers::ID, family: answer.fetch('family'), direction: answer.fetch('direction'),
      type: answer.fetch('type'), candidate: answer['candidate'], **options).render
  end

  def test_named_subset_escaping_single_source_link_and_shared_controls
    html = render(ModelNeighborhoodAnswers.page)
    assert_equal ['0'], html.scan(/data-neighborhood-edge="(\d+)"/).flatten
    assert_equal ['0'], html.scan(/data-neighborhood-diagram-edge="(\d+)"/).flatten
    assert_operator html.index('Named relationships</h2>'), :<, html.index('<svg')
    assert_includes html, 'Order &lt;unsafe&gt;'
    assert_includes html, '→ Item &amp; more'
    refute_includes html, '<unsafe>'
    assert_equal 1, html.scan(/href="[^"]+#L2"/).length
    assert_includes html, 'Columns</button>'
    assert_includes html, 'Database facts</button>'
    assert_includes html, 'physical DB foreign keys and ON DELETE were not recorded'
  end

  def test_default_outgoing_page_admits_eight_rows_without_repeating_the_full_root
    params = { 'generation' => ModelNeighborhoodAnswers::G, 'id' => ModelNeighborhoodAnswers::ID }
    nav = Thistle::Map::NavigationContext.new(generation: ModelNeighborhoodAnswers::G, params: params)
    limit, max_bytes = Thistle::Map::ModelNeighborhoodPresenter.admission(nav)
    assert_equal 8, limit
    answer = ModelNeighborhoodAnswers.page
    answer['root']['name'] = answer['model']['name'] = '&' * 512
    answer['items'] = (0...8).map do |index|
      row = Marshal.load(Marshal.dump(answer['items'].first))
      row['witness']['ordinal'] = index
      row['candidate_selector'] = "a:#{index}"
      row['candidates'] = []
      row['candidate_matches'] = row['candidate_known_omitted'] = 0
      row['target_status'] = 'missing_or_unloaded'
      row
    end
    html = render(answer, navigation: nav, limit: limit, max_bytes: max_bytes)
    assert_equal 8, html.scan(/data-neighborhood-edge=/).length
    assert_equal 1, html.scan('&amp;' * 512).length
    assert_equal 8, html.scan(/<strong>This model →/).length
    assert_operator html.bytesize + Thistle::Map::ModelNeighborhoodPresenter.layout_reserve(nav), :<=, 65_536
  end

  def test_encoded_search_has_an_explicit_context_limit_without_silently_dropping_state
    query = ('Order.where(status: "open").includes(:items, :user); ' * 6).byteslice(0, 256)
    assert_equal 256, query.bytesize
    params = { 'generation' => ModelNeighborhoodAnswers::G, 'id' => ModelNeighborhoodAnswers::ID,
      'selection' => (1..24).map { |n| n.to_s(16).rjust(64, '0') }.join(','), 'q' => query }
    nav = Thistle::Map::NavigationContext.new(generation: ModelNeighborhoodAnswers::G, mount: '/map', params: params,
      selection: Thistle::Map::Investigation.from_params(params))
    error = assert_raises(Thistle::Map::ModelNeighborhoodPresenter::DisplayLimit) do
      Thistle::Map::ModelNeighborhoodPresenter.admission(nav)
    end
    assert_includes error.message, 'Navigation context leaves no useful model page'
    limit, max_bytes = Thistle::Map::ModelNeighborhoodPresenter.admission(nav, direction: 'incoming')
    answer = ModelNeighborhoodAnswers.realistic(direction: 'incoming')
    html = render(answer, navigation: nav, limit: limit, max_bytes: max_bytes)
    assert_includes html, 'name="q" value="' + ERB::Util.html_escape(query) + '"'
    assert_includes html, 'name="selection" value="' + params['selection'] + '"'
    refute nav.search_omitted
    assert_operator html.bytesize + Thistle::Map::ModelNeighborhoodPresenter.layout_reserve(nav), :<=, 65_536
  end

  def test_literal_default_values_and_missing_saved_tag_refusal
    answer = ModelNeighborhoodAnswers.page(family: 'columns')
    defaults = [false, 0, '', nil].map { |v| { 'kind' => 'literal', 'value' => v } } + [{ 'kind' => 'expression' }, { 'kind' => 'opaque' }]
    answer['items'] = defaults.each_with_index.map do |tagged, index|
      { 'kind' => 'column', 'ordinal' => index, 'column' => { 'name' => "c#{index}", 'type' => 'string', 'sql_type' => 'text', 'null' => false, 'default' => tagged } }
    end
    html = render(answer)
    ['false (literal)', '0 (literal)', '&quot;&quot; (literal)', 'null (literal)', 'Expression (text not recorded', 'Opaque value'].each { |text| assert_includes html, text }
    refute_includes html, 'default_recorded'
    assert_includes html, 'default presence was not recorded'
    answer['items'][0]['column'].delete('default')
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
    assert_includes render(ModelNeighborhoodAnswers.page(family: 'database')), 'unavailable, not known absent'
  end

  def test_visible_active_filter_and_unavailable_are_distinct_from_empty
    answer = ModelNeighborhoodAnswers.page(direction: 'incoming', type: 'association')
    answer['items'] = []
    answer['coverage']['associations_status'] = 'unavailable'
    html = render(answer)
    assert_includes html, 'Showing: Incoming · Associations.'
    assert_includes html, 'aria-current="true">Incoming'
    assert_includes html, 'aria-current="true">Associations'
    assert_includes html, 'association observation unavailable (not known empty)'
    answer = ModelNeighborhoodAnswers.page(family: 'columns')
    answer['coverage']['columns_status'] = 'unavailable'
    assert_includes render(answer), 'Column observation unavailable (not known empty)'
  end

  def test_forged_witness_aliases_ids_and_missing_continuation_refuse
    answer = ModelNeighborhoodAnswers.page
    answer['items'][0]['origin_id'] = 'd' * 64
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
    answer = ModelNeighborhoodAnswers.page
    answer['cost'].delete('reference_attempts')
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
    answer = ModelNeighborhoodAnswers.page
    answer['items'][0]['candidates'][0]['id'] = 'javascript:alert(1)'
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
    answer = ModelNeighborhoodAnswers.page
    answer['coverage']['page_complete'] = false
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
    answer = ModelNeighborhoodAnswers.realistic(direction: 'incoming', type: 'reference')
    answer['items'][0]['recorded']['origin'] = answer['items'][0]['origin']
    assert_raises(Thistle::InvalidSnapshot) { render(answer) }
  end

  def test_unknown_target_omissions_and_named_candidate_context
    answer = ModelNeighborhoodAnswers.page
    edge = answer['items'][0]
    edge['target_label'] = edge['association']['target'] = nil
    edge['target_status'] = 'unknown_target'; edge['candidates'] = []; edge['candidate_matches'] = 0
    assert_includes render(answer), 'Unknown / polymorphic target'
    edge['target_label'] = edge['association']['target'] = 'User'
    edge['candidate_matches'] = 6; edge['candidate_known_omitted'] = 6
    html = render(answer)
    assert_includes html, 'Inspect all saved target representations'
    assert_includes html, 'name="candidate" value="a:0"'
    assert_includes html, 'not distinct model-definition counts'
    answer = ModelNeighborhoodAnswers.realistic(family: 'candidates', candidate: 'a:0')
    html = render(answer)
    assert_includes html, 'Saved representations for association'
    assert_includes html, '&quot;reviewers&quot; → ::Shop::'
  end

  def test_last_step_is_explicitly_not_completed_page_or_retained_row
    answer = ModelNeighborhoodAnswers.realistic(direction: 'incoming', type: 'reference')
    answer['coverage']['last_reference_step'] = { 'status' => 'completed_component', 'scan_complete' => true, 'row_retained' => false }
    html = render(answer)
    assert_includes html, 'Only page_complete describes'
    assert_includes html, '&quot;scan_complete&quot;:true'
    assert_includes html, '&quot;row_retained&quot;:false'
    assert_includes html, 'Original recorded reference'
  end

  def test_complete_diagram_can_be_omitted_without_pruning_any_named_html_edge
    params = { 'generation' => ModelNeighborhoodAnswers::G, 'id' => ModelNeighborhoodAnswers::ID,
      'selection' => (1..24).map { |n| n.to_s(16).rjust(64, '0') }.join(','), 'q' => 'q' * 256 }
    nav = Thistle::Map::NavigationContext.new(generation: ModelNeighborhoodAnswers::G, mount: '/map', params: params,
      selection: Thistle::Map::Investigation.from_params(params))
    answer = ModelNeighborhoodAnswers.page
    answer['root']['name'] = answer['model']['name'] = '&' * 2500
    row = answer['items'].first
    row['target_label'] = row['association']['target'] = '&' * 3000
    row['candidates'] = []
    row['candidate_matches'] = row['candidate_known_omitted'] = 0
    row['target_status'] = 'missing_or_unloaded'
    html = render(answer, navigation: nav)
    assert_includes html, %(<h1 class="t1">#{ERB::Util.html_escape(answer.fetch('root').fetch('name'))}: model neighborhood</h1>)
    assert_equal ['0'], html.scan(/data-neighborhood-edge="(\d+)"/).flatten
    assert_empty html.scan(/data-neighborhood-diagram-edge="(\d+)"/)
    assert_includes html, 'The full named list contains every selected edge'
    assert_operator html.bytesize + Thistle::Map::ModelNeighborhoodPresenter.layout_reserve(nav), :<=, 65_536
  end

  def test_budget_enforcing_rust_shaped_pages_with_24_ids_256q_long_names_demand_success
    params = { 'generation' => ModelNeighborhoodAnswers::G, 'id' => ModelNeighborhoodAnswers::ID,
      'selection' => (1..24).map { |n| n.to_s(16).rjust(64, '0') }.join(','), 'q' => 'q' * 256 }
    selected = Thistle::Map::Investigation.from_params(params)
    reader = ModelNeighborhoodAnswers::BudgetReader.new
    cases = [['edges', 'outgoing', 'all', nil], ['edges', 'outgoing', 'reference', nil],
      ['edges', 'incoming', 'association', nil], ['edges', 'incoming', 'reference', nil],
      ['columns', 'outgoing', 'all', nil], ['database', 'outgoing', 'all', nil],
      ['candidates', 'outgoing', 'all', 'a:0']]
    cases.each do |family, direction, type, candidate|
      nav = Thistle::Map::NavigationContext.new(generation: ModelNeighborhoodAnswers::G, mount: '/map', params: params, selection: selected)
      limit, max_bytes = Thistle::Map::ModelNeighborhoodPresenter.admission(nav, family: family, direction: direction)
      answer = reader.model_neighborhood(ModelNeighborhoodAnswers::ID, family: family, direction: direction, type: type,
        candidate: candidate, limit: limit, max_bytes: max_bytes)
      html = render(answer, navigation: nav, limit: limit, max_bytes: max_bytes)
      # Success is required. No rescue or 200-or-422 branch can mask collapse.
      assert_operator answer['items'].length, :>=, 1 unless family == 'database'
      assert_operator html.bytesize + Thistle::Map::ModelNeighborhoodPresenter.layout_reserve(nav), :<=, 65_536
      assert_includes html, 'name="selection" value="' + params['selection'] + '"'
      assert_includes html, 'name="q" value="' + params['q'] + '"'
      refute nav.search_omitted
      list = html.scan(/data-neighborhood-edge="(\d+)"/)
      diagram = html.scan(/data-neighborhood-diagram-edge="(\d+)"/)
      assert_equal list, diagram unless diagram.empty?
      puts "Pure budget #{family}/#{direction}/#{type}: limit=#{limit} native=#{answer.dig('usage', 'wire_bytes_including_envelope_and_newline')}/#{max_bytes} primary+layout-reserve=#{html.bytesize + Thistle::Map::ModelNeighborhoodPresenter.layout_reserve(nav)}"
    end
    assert_equal cases.length, reader.calls.length
  end
end
