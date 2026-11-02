# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../../test/fixtures/route_actions/source_answers'
require_relative '../lib/thistle/map/passage_presenter'

# Handwritten DTO witnesses, independent of the new Rust implementation.
module PassageAnswers
  GENERATION = RouteActionsAnswers::GENERATION
  ROUTE = RouteActionsAnswers::ROUTE
  ACTION = RouteActionsAnswers::METHOD
  OTHER = RouteActionsAnswers::OTHER
  def self.page(save: false, selected: true, family: 'sequence', conditional: false)
    route = RouteActionsAnswers.page
    action = route.fetch('candidates').first.fetch('fact')
    route.delete('root')
    evidence = {'kind'=>save ? 'save_operation' : 'boundary','operation'=>save ? 'create!' : 'unknown_helper',
      'receiver'=>save ? '::Order' : nil,'span'=>action.fetch('span').dup,'syntax'=>'<unsafe>',
      'condition'=>conditional ? 'inside_branch_syntax' : 'no_enclosing_branch_syntax','reason'=>'Potential syntax only; binding unknown'}
    evidence['branch'] = {'kind'=>'if','span'=>action.fetch('span').dup} if conditional
    item = {'kind'=>'source_operation','ordinal'=>0,'witness'=>action,'evidence'=>evidence,'binding'=>'unknown'}
    item['save_contribution'] = {'status'=>'qualified_target_unavailable','reason'=>'No unique loaded model witness'} if save
    answer = {'version'=>1,'generation'=>GENERATION,'root'=>RouteActionsAnswers.identity(ROUTE,'route'),
      'selected_action'=>selected ? action : nil,'family'=>family,'selection_status'=>selected ? 'selected_syntax_binding_unknown' : 'choose_saved_action',
      'route'=>route,'items'=>selected ? [item] : [],'offset'=>0,
      'filters'=>{'status'=>'not_captured','registry_candidates'=>0,'binding'=>'unknown'},
      'coverage'=>{'page_complete'=>true,'execution'=>'unavailable','source_scan_complete'=>true,'analysis_status'=>'selected_body_syntax'},
      'next_cursor'=>nil,'continuation'=>nil,'usage'=>{},'semantics'=>'Selected-action potential only; no execution trace.'}
    answer['report'] = "#{answer['semantics']}\nGeneration: #{GENERATION}\nSelected action: #{selected ? ACTION : 'none'}\n#{JSON.generate(answer['items'])}\n" if family == 'export'
    answer
  end
  def self.report!(answer)
    answer['report'] = "#{answer['semantics']}\nGeneration: #{GENERATION}\nSelected action: #{answer.dig('selected_action','id') || 'none'}\n#{JSON.generate(answer['items'])}\n"
    answer
  end
  def self.contributed(family: 'sequence')
    answer = page(save:true,family:family)
    item = answer.fetch('items').first
    runtime = ->(id,kind) { {'generation'=>GENERATION,'id'=>id,'kind'=>kind,'name'=>'Order','evidence'=>'runtime','path'=>nil,'span'=>nil} }
    registry = 'e'*64
    item.merge!('model_candidates'=>1,'callback_registry_candidates'=>1,'model'=>runtime.call('f'*64,'rails_model'))
    callbacks = (0...4).map do |n|
      witness = RouteActionsAnswers.identity(format('%064x',100+n)).merge('name'=>"Order#queue_receipt_#{n}",'path'=>'app/models/order.rb')
      {'callback_id'=>"#{registry}:#{n}",'registry_id'=>registry,'position'=>n,'kind'=>'after','inherited'=>false,
        'filter'=>{'kind'=>'method','name'=>"queue_receipt_#{n}",'owner'=>'Order'},'registry_provenance'=>'registered_metadata',
        'conditions'=>{'if'=>{'status'=>'recorded','count'=>1,'kinds'=>{'proc'=>1},'evaluation'=>'unknown'},'unless'=>{'status'=>'recorded','count'=>0,'kinds'=>{},'evaluation'=>'unknown'}},
        'binding'=>'descriptor_matched_captured_declaration','status'=>'supported_potential','reason'=>'recorded_constant_receiver_perform_later',
        'witness'=>witness,'effects'=>{'returned_count'=>8,'unit'=>'representative_potential_perform_later_call_groups',
          'known_omitted'=>2,'search_complete'=>true,'details'=>'not_projected','non_exhaustive'=>true}}
    end
    item['save_contribution'] = {'status'=>'potential_save_callback_contribution','model_binding'=>'unknown',
      'registry'=>runtime.call(registry,'rails_save_callbacks'),'registry_status'=>'observed','callbacks'=>callbacks,
      'summary_limit'=>4,'summaries_omitted'=>0,'component_callbacks_returned'=>4,
      'effect_absence'=>'No supported match does not prove that no effect is possible.',
      'coverage'=>{'rows_attempted'=>4,'rows_not_searched'=>4,'rows_metadata_omitted'=>0,'rows_output_omitted'=>0,'truncated'=>true}}
    report!(answer) if family == 'export'
    answer
  end
end

class PassagePresenterTest < Minitest::Test
  def validate(answer, action: PassageAnswers::ACTION, family: 'sequence', max_bytes: 32768)
    Thistle::Map::PassagePresenter.validate!(answer,generation:PassageAnswers::GENERATION,id:PassageAnswers::ROUTE,action:action,family:family,max_bytes:max_bytes)
  end
  def render(answer)
    nav = Thistle::Map::NavigationContext.new(generation:PassageAnswers::GENERATION,params:{'id'=>PassageAnswers::ROUTE,'action'=>PassageAnswers::ACTION})
    Thistle::Map::PassagePresenter.new(navigation:nav).render(answer)
  end
  def test_save_and_non_save_cards_change_page_and_export_without_generic_lifecycle
    [false,true].each do |save|
      answer = validate(PassageAnswers.page(save:save))
      html = render(answer)
      assert_equal save, html.include?('Save syntax found; unique recorded model')
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
    refute_includes html, 'Export this selected-action investigation'
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
  def test_branch_truth_remains_unknown_but_conditional_and_unenclosed_syntax_differ
    direct = validate(PassageAnswers.page(save:true))
    conditional = validate(PassageAnswers.page(save:true,conditional:true))
    assert_includes render(direct),'No enclosing branch syntax'
    assert_includes render(conditional),'Inside if branch syntax at saved line 2'
    assert_includes render(conditional),'predicate truth and execution unknown'
    exported = validate(PassageAnswers.page(save:true,conditional:true,family:'export'),family:'export')
    assert_equal 'if',JSON.parse(exported.fetch('report').lines.drop(3).join).first.dig('evidence','branch','kind')
    bad = PassageAnswers.page(save:true,conditional:true)
    bad['items'][0]['evidence']['branch']['span']['end_byte'] = 99999
    assert_raises(Thistle::InvalidSnapshot) {validate(bad)}
  end
  def test_local_filter_and_source_status_are_visible_before_the_list
    [['not_captured',0,'were not captured'],['unavailable',1,'could not be observed'],['ambiguous_registry_candidates',2,'Multiple filter registries'],['captured',1,'Captured filter registry']].each do |state,count,label|
      answer = PassageAnswers.page
      answer['filters'].merge!('status'=>state,'registry_candidates'=>count)
      html = render(validate(answer))
      assert_operator html.index(label),:<,html.index('<ol>')
      assert_includes html,"#{count} recorded candidates"
    end
    answer = PassageAnswers.page
    answer['coverage'].merge!('source_scan_complete'=>false,'analysis_status'=>'unknown','reason'=>'saved_file_exceeds_source_allowance','unsearched'=>'selected_action_source_not_scanned')
    html = render(validate(answer))
    assert_operator html.index('source scan unknown'),:<,html.index('<ol>')
    assert_includes html,'saved file exceeds source allowance'
    answer['coverage'].merge!('analysis_status'=>'bounded_partial','unsearched'=>'remaining_node_or_row_work',
      'stop_region'=>answer.fetch('selected_action').fetch('span').dup,'unsearched_from_byte'=>25)
    assert_includes render(validate(answer)),'unsearched work begins at saved byte 25'
  end
  def test_compact_large_save_and_export_render_once_with_exact_witnesses_and_omissions
    answer = PassageAnswers.contributed
    html = render(validate(answer))
    assert_includes html,'Callback summaries omitted: 0'
    assert_includes html,'Representative potential perform_later call groups: 8'
    assert_includes html,'This is not a count of invocations.'
    assert_includes html,'No supported match does not prove that no effect is possible.'
    assert_equal 4,html.scan('Inspect potential model callback definition').length
    refute_includes html,'source_excerpt'
    exported = PassageAnswers.contributed(family:'export')
    # Same parsed meaning with different JSON key order/spacing is valid.
    prefix = exported.fetch('report').lines.first(3).join
    exported['report'] = prefix + JSON.pretty_generate(exported.fetch('items').map { |r| r.to_a.reverse.to_h })
    result = render(validate(exported,family:'export'))
    refute_includes result,'<ol>'
    refute_includes result,'Registered callback '
    assert_operator result.bytesize,:<,Thistle::Map::PassagePresenter::MAX_BODY_BYTES
    nav = Thistle::Map::NavigationContext.new(generation:PassageAnswers::GENERATION,params:{})
    assert_operator Thistle::Map::PassagePresenter.request_bytes(nav),:<,32768
    cap = Thistle::Map::PassagePresenter.request_bytes(nav)
    near = PassageAnswers.contributed(family:'export')
    [64,128,256,512].each do |length|
      candidate = PassageAnswers.contributed(family:'export')
      candidate.fetch('items').first.fetch('save_contribution').fetch('callbacks').each_with_index do |callback,n|
        name = "receipt_#{n}_" + 'a'*length
        callback['filter']['name'] = name
        callback['witness']['name'] = "Order##{name}"
      end
      PassageAnswers.report!(candidate)
      near = candidate if JSON.generate(candidate).bytesize <= cap
    end
    assert_operator JSON.generate(near).bytesize,:<=,cap
    assert_operator JSON.generate(near).bytesize,:>,cap * 0.65
    assert_operator render(validate(near,family:'export',max_bytes:cap)).bytesize,:<,Thistle::Map::PassagePresenter::MAX_BODY_BYTES
    assert_raises(Thistle::InvalidSnapshot) {validate(near,family:'export',max_bytes:JSON.generate(near).bytesize-1)}
    bad = PassageAnswers.contributed
    bad['items'][0]['save_contribution']['callbacks'][0]['effects']['body'] = 'full effect body'
    assert_raises(Thistle::InvalidSnapshot) {validate(bad)}
    # The existing cap remains a refusal even for a malformed/oversized producer.
    bad = PassageAnswers.contributed(family:'export')
    bad['report'] << 'x'*65536
    assert_raises(Thistle::InvalidSnapshot) {validate(bad,family:'export')}
  end
  def test_export_admission_uses_rendered_links_and_a_full_rust_shaped_summary
    params = {'generation'=>PassageAnswers::GENERATION,'q'=>'orders','domain'=>'all',
      'selection'=>[PassageAnswers::ACTION,PassageAnswers::OTHER].join(',')}
    nav = Thistle::Map::NavigationContext.new(generation:PassageAnswers::GENERATION,mount:'/map',params:params,
      selection:Thistle::Map::Investigation.from_params(params))
    klass = Thistle::Map::PassagePresenter
    old_sequence_cap = klass.request_bytes(nav)
    cap = klass.request_bytes(nav,family:'export',action:PassageAnswers::ACTION)
    assert_equal 32768,cap
    assert_operator cap,:>,old_sequence_cap
    assert_equal old_sequence_cap,klass.request_bytes(nav,family:'export',action:nil)
    answer = PassageAnswers.contributed(family:'export')
    # Include real DTO categories omitted by the former small mock: full-length
    # semantics, directory/open usage, component coverage, and long descriptors.
    answer['semantics'] = 'Registry order, lexical order, conditions, model identity, source coherence, invocation, persistence and delivery remain unknown. ' * 3
    answer['usage'] = {'selection_fact_visits'=>70,'selection_comparisons'=>400,'selection_label_bytes'=>16000,
      'scratch_reservation'=>100663296,'reader_open'=>{'facts'=>120,'links'=>200,'method_key_bytes'=>9000},
      'directories'=>%w[method rails_model rails_save_callbacks rails_controller_filters].map { |kind|
        {'family'=>kind,'built'=>true,'facts'=>120,'retained_bytes'=>4096,'capacity'=>128,'comparisons'=>400} },
      'scope'=>'Route, saved-source and callback work share finite admission; directories build lazily and source prefixes repeat per page. No runtime or performance evidence.'}
    contribution = answer['items'].first.fetch('save_contribution')
    contribution['coverage'].merge!('capture_partial_or_unknown'=>false,'declaration_scan_complete'=>true,
      'candidate_ranges_complete'=>true,'source_rows_not_searched'=>0,'facts_visited'=>70,'links_visited'=>100,
      'compared_label_bytes'=>16000,'source_files_attempted'=>1,'source_bytes_charged'=>4096)
    contribution.fetch('callbacks').each_with_index do |callback,n|
      name = "deliver_order_receipt_#{n}_" + 'subscriber_retry_policy_' * 8
      callback['filter']['name'] = name
      callback['witness']['name'] = "Order##{name}"
    end
    PassageAnswers.report!(answer)
    wire = JSON.generate(answer).bytesize
    assert_operator wire,:>,old_sequence_cap, 'Regression must exceed the old export admission'
    assert_operator wire,:<=,cap
    klass.validate!(answer,generation:PassageAnswers::GENERATION,id:PassageAnswers::ROUTE,
      action:PassageAnswers::ACTION,family:'export',max_bytes:cap)
    html = klass.new(navigation:nav).render(answer)
    assert_operator html.bytesize,:<,klass::MAX_BODY_BYTES
    refute_includes html,'<ol>'
    assert_equal 1,html.scan('Selected action:').length
  end

  def test_filter_descriptor_is_visible_without_a_source_witness_and_service_is_neutral
    answer = PassageAnswers.page
    answer['filters'].merge!('status'=>'captured','registry_candidates'=>1)
    answer['items'] = [{'kind'=>'controller_filter','ordinal'=>0,'registry_id'=>'e'*64,'registration'=>{'filter'=>{'kind'=>'method','name'=>'authenticate','owner'=>'ApplicationController'}},
      'applicability'=>'opaque_conditions_unknown','order'=>'Framework registry position only','witness'=>nil,'binding'=>'unknown'}]
    html = render(validate(answer))
    assert_includes html,'Registered filter: authenticate'
    assert_includes html,'Observed owner: ApplicationController'
    assert_includes html,'opaque conditions'
    answer = PassageAnswers.page
    row = answer.fetch('items').first
    row.fetch('evidence').merge!('kind'=>'constant_call_boundary','receiver'=>'::PaymentService','operation'=>'call')
    candidate = RouteActionsAnswers.identity('d'*64).merge('name'=>'PaymentService#call')
    row.merge!('candidate_matches'=>1,'receiver_framework_role'=>'unknown','boundary'=>'Stop; binding unknown',
      'related_candidate'=>candidate,'followup'=>{'operation'=>'job_mail','generation'=>PassageAnswers::GENERATION,'id'=>candidate.fetch('id'),'family'=>'handoff'})
    html = render(validate(answer))
    assert_includes html,'Framework role and binding unknown'
    assert_includes html,'Inspect related method source evidence'
    refute_includes html,'Inspect potential mail/template handoff'
  end
end
