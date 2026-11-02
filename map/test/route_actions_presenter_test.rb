# frozen_string_literal: true

if $PROGRAM_NAME == __FILE__
  require 'cgi'
  require_relative '../../lib/thistle/errors'
  require_relative '../../test/fixtures/route_actions/source_answers'
  require_relative '../lib/thistle/map/route_actions_presenter'
  a = RouteActionsAnswers
  presenter = Thistle::Map::RouteActionsPresenter
  selection = Thistle::Map::Investigation.new(generation: a::GENERATION, ids: [a::ROUTE,a::METHOD])
  navigation = Thistle::Map::NavigationContext.new(generation: a::GENERATION, mount: '/map', selection: selection,
    params: {'id'=>a::ROUTE,'q'=>'orders','domain'=>'metadata','kind'=>'route','prefix'=>'app'})
  page = a.page(continuation: true)
  presenter.validate!(page, generation: a::GENERATION, id: a::ROUTE, limit: 1)
  html = presenter.new(navigation: navigation).render(page)
  a.demand(html.include?('Multiple static candidates') && html.include?('at least: 2'), 'Ambiguity/count lost')
  a.demand(html.include?('&lt;OrdersController#index&gt;') && !html.include?('<OrdersController'), 'Candidate label unescaped')
  a.demand(html.include?('Opaque callback &lt;unexecuted&gt;') && html.include?('routes_to'), 'Raw route constraints/provenance lost')
  hrefs = html.scan(/href="([^"]+)"/).flatten.map { |href| CGI.unescapeHTML(href) }
  source = hrefs.find { |href| href.include?('/source?') }
  a.demand(source&.end_with?('#L2'), 'Exact saved line anchor absent')
  params = URI.decode_www_form(URI.parse(source).query).to_h
  a.demand(params.values_at('generation','id','selection','q') == [a::GENERATION,a::METHOD,selection.ids.join(','),'orders'], 'Physical Source lost generation/search/collection')
  a.demand(hrefs.any? { |href| href.include?('/route-actions?') && URI.decode_www_form(URI.parse(href).query).to_h['cursor'] == a.cursor }, 'Continuation lost')
  no_source = a.page
  no_source['candidates'][0].merge!('fact'=>a.identity.merge('path'=>nil,'span'=>nil),'source_status'=>'saved_source_absent','source'=>nil)
  presenter.validate!(no_source, generation: a::GENERATION, id: a::ROUTE)
  a.demand(presenter.new(navigation: navigation).render(no_source).include?('No physical source mapping'), 'Absent Source hidden')
  %w[unsupported_route_or_naming discovery_incomplete no_eligible_recorded_candidate].each do |status|
    negative = a.page
    negative['status'] = status
    negative['candidates'] = []
    negative['candidate_count'] = {'lower_bound'=>0,'exact'=>status=='no_eligible_recorded_candidate'}
    negative['coverage']['discovery_complete'] = status=='no_eligible_recorded_candidate'
    negative['coverage']['capture_partial_or_unknown'] = status=='discovery_incomplete'
    negative['naming']['status'] = 'unsupported' if status=='unsupported_route_or_naming'
    presenter.validate!(negative, generation: a::GENERATION, id: a::ROUTE)
    a.demand(presenter.new(navigation: navigation).render(negative).include?('No candidates returned'), 'Negative became empty proof')
  end
  mutations = [
    ->(p) { p['generation'] = a::OTHER },
    ->(p) { p['candidates'][0]['fact']['generation'] = a::OTHER },
    ->(p) { p['candidates'][0]['source']['id'] = a::OTHER },
    ->(p) { p['candidates'][0]['fact']['span']['start_line'] = 0 },
    ->(p) { p['unknowns']['dispatch'] = 'resolved' },
    ->(p) { p['status'] = 'unique_static_candidate_binding_unknown' },
    ->(p) { p['next_cursor'] = a.cursor(2); p['continuation']['cursor'] = a.cursor(2) },
    ->(p) { p['route']['attributes']['oversized'] = 'x' * 32768 }
  ]
  mutations.each do |mutate|
    bad = a.page(continuation: true); mutate.call(bad)
    a.rejects(Thistle::InvalidSnapshot) { presenter.validate!(bad, generation: a::GENERATION, id: a::ROUTE) }
  end
  a.rejects(Thistle::InvalidSnapshot) { presenter.validate!(page, generation: a::GENERATION, id: a::ROUTE, cursor: a.cursor) }
  puts 'PASS presenter ambiguity, saved Source href, retained context, negatives and forged-witness refusals'
end
