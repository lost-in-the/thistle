# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../../test/fixtures/los144_route_actions/source_answers'
require_relative '../lib/thistle/map/passage_presenter'

# Handwritten DTO witnesses, independent of the new Rust implementation.
module PassageAnswers
  GENERATION = RouteActionsAnswers::GENERATION
  ROUTE = RouteActionsAnswers::ROUTE
  ACTION = RouteActionsAnswers::METHOD
  OTHER = RouteActionsAnswers::OTHER
  def self.page(save: false, selected: true, family: 'sequence')
    route = RouteActionsAnswers.page
    action = route.fetch('candidates').first.fetch('fact')
    route.delete('root')
    evidence = {'kind'=>save ? 'save_operation' : 'boundary','operation'=>save ? 'create!' : 'unknown_helper',
      'receiver'=>save ? '::Order' : nil,'span'=>action.fetch('span').dup,'syntax'=>'<unsafe>','condition'=>'unknown','reason'=>'Potential syntax only; binding unknown'}
    item = {'kind'=>'source_operation','ordinal'=>0,'witness'=>action,'evidence'=>evidence,'binding'=>'unknown'}
    item['save_contribution'] = {'status'=>'qualified_target_unavailable','reason'=>'No unique loaded model witness'} if save
    answer = {'version'=>1,'generation'=>GENERATION,'root'=>RouteActionsAnswers.identity(ROUTE,'route'),
      'selected_action'=>selected ? action : nil,'family'=>family,'selection_status'=>selected ? 'selected_syntax_binding_unknown' : 'choose_saved_action',
      'route'=>route,'items'=>selected ? [item] : [],'offset'=>0,'coverage'=>{'page_complete'=>true,'execution'=>'unavailable','source_scan_complete'=>true},
      'next_cursor'=>nil,'continuation'=>nil,'usage'=>{},'semantics'=>'Selected-action potential only; no execution trace.'}
    answer['report'] = "#{answer['semantics']}\nGeneration: #{GENERATION}\nSelected action: #{selected ? ACTION : 'none'}\n#{JSON.generate(answer['items'])}\n" if family == 'export'
    answer
  end
end

class PassagePresenterTest < Minitest::Test
  def validate(answer, action: PassageAnswers::ACTION, family: 'sequence')
    Thistle::Map::PassagePresenter.validate!(answer,generation:PassageAnswers::GENERATION,id:PassageAnswers::ROUTE,action:action,family:family)
  end
  def render(answer)
    nav = Thistle::Map::NavigationContext.new(generation:PassageAnswers::GENERATION,params:{'id'=>PassageAnswers::ROUTE,'action'=>PassageAnswers::ACTION})
    Thistle::Map::PassagePresenter.new(navigation:nav).render(answer)
  end
  def test_save_and_non_save_cards_change_page_and_export_without_generic_lifecycle
    [false,true].each do |save|
      answer = validate(PassageAnswers.page(save:save))
      html = render(answer)
      assert_equal save, html.include?('qualified_target_unavailable')
      assert_includes html, '&lt;unsafe&gt;'
      refute_includes html, '<unsafe>'
      assert_includes html, '#L2'
      report = validate(PassageAnswers.page(save:save,family:'export'),family:'export')
      assert_equal save, report.fetch('report').include?('save_contribution')
    end
  end
  def test_wrong_action_false_save_branch_and_forged_export_refuse
    answer = PassageAnswers.page
    answer['items'][0]['save_contribution'] = {'status'=>'potential_save_callback_contribution'}
    assert_raises(Thistle::InvalidSnapshot) {validate(answer)}
    answer = PassageAnswers.page
    answer['items'][0]['witness'] = RouteActionsAnswers.identity(PassageAnswers::OTHER)
    assert_raises(Thistle::InvalidSnapshot) {validate(answer)}
    answer = PassageAnswers.page(family:'export')
    answer['report'] << 'generic model create INSERT'
    assert_raises(Thistle::InvalidSnapshot) {validate(answer,family:'export')}
    answer = PassageAnswers.page
    answer['items'][0]['evidence']['span']['start_line'] = 999
    assert_raises(Thistle::InvalidSnapshot) {validate(answer)}
  end
  def test_no_implicit_first_candidate_selection_and_no_dead_source_link
    answer = validate(PassageAnswers.page(selected:false),action:nil)
    html = render(answer)
    assert_includes html, 'Choose a saved action definition'
    assert_includes html, 'action=' + PassageAnswers::ACTION
    refute_includes html, 'save_contribution'
    answer = PassageAnswers.page
    answer['selected_action']['span'] = nil
    assert_raises(Thistle::InvalidSnapshot) {validate(answer)}
  end
  def test_unselected_action_choices_have_their_own_progressing_cursor
    answer = PassageAnswers.page(selected:false)
    route = RouteActionsAnswers.page(continuation:true)
    route.delete('root')
    answer['route'] = route
    token = JSON.generate(['recorded-v1',PassageAnswers::GENERATION,
      Digest::SHA256.hexdigest(JSON.generate(['passage',PassageAnswers::ROUTE,nil,'sequence'])),1,0])
    answer['coverage']['page_complete'] = false
    answer['next_cursor'] = token
    answer['continuation'] = {'operation'=>'passage','generation'=>PassageAnswers::GENERATION,'id'=>PassageAnswers::ROUTE,'action'=>nil,'family'=>'sequence','cursor'=>token}
    html = render(validate(answer,action:nil))
    assert_includes html,'Continue saved action choices'
    refute_includes html,'Continue selected-action evidence'
    assert Thistle::Map::NavigationContext.continuation('/passage/sequence',
      {'generation'=>PassageAnswers::GENERATION,'id'=>PassageAnswers::ROUTE,'cursor'=>token})
  end
end
