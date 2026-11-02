# frozen_string_literal: true

if $PROGRAM_NAME == __FILE__
  require_relative '../../test/fixtures/route_actions/source_answers'
  require_relative '../lib/thistle/map/navigation_context'
  a = RouteActionsAnswers
  klass = Thistle::Map::NavigationContext
  params = {'generation'=>a::GENERATION,'id'=>a::ROUTE,'cursor'=>a.cursor,'q'=>'orders','domain'=>'metadata','kind'=>'route','prefix'=>'app'}
  a.demand(klass.continuation('/route-actions',params) == {route_actions: true}, 'Typed route not admitted')
  ['page','direction','candidate','path','file','unknown'].each do |field|
    a.rejects(Thistle::Map::Investigation::Invalid) { klass.continuation('/route-actions',params.merge(field=>'1')) }
  end
  [params.reject { |key,_| key=='generation' },params.merge('cursor'=>a.cursor(1,a::OTHER)),params.merge('generation'=>a::OTHER)].each do |bad|
    a.rejects(Thistle::Map::Investigation::Invalid) { klass.continuation('/route-actions',bad) }
  end
  selection = Thistle::Map::Investigation.new(generation: a::GENERATION, ids: (1..24).map { |n| format('%064x',n) })
  nav = klass.new(generation: a::GENERATION, params: params, selection: selection)
  source = URI.decode_www_form(URI.parse(nav.url('/source','id'=>a::METHOD)).query).to_h
  a.demand(source.keys.sort == %w[domain generation id kind prefix q selection], 'Route-only cursor leaked to Source')
  a.demand(source['selection'].split(',') == selection.ids, 'Full collection pruned')
  # A legal 256-byte query whose characters need percent encoding fits alone;
  # with a full selection + long valid cursor it can trigger search omission.
  long_scope = ['recorded-v1',a::GENERATION,Digest::SHA256.hexdigest(JSON.generate(['route_actions',a::ROUTE])),1,0]
  long_cursor = JSON.generate(long_scope) + ' ' * (512 - JSON.generate(long_scope).bytesize)
  crowded = klass.new(generation: a::GENERATION, mount: '/map', selection: selection,
    params: {'id'=>a::ROUTE,'q'=>'?'*256,'domain'=>'metadata','kind'=>'route','prefix'=>'?'*500})
  href = crowded.url('/route-actions','id'=>a::ROUTE,'cursor'=>long_cursor)
  fields = URI.decode_www_form(URI.parse(href).query).to_h
  a.demand(crowded.search_omitted && !fields.key?('q') && fields['selection'].split(',') == selection.ids, 'Search omission notice/full collection contract lost')
  a.demand(URI.parse(href).query.bytesize <= 4096 && fields.length <= 9, 'Navigation budget exceeded')
  puts 'PASS route scope, pre-Reader refusals, destination controls and full-collection URL budgets'
end
