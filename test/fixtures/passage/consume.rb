# frozen_string_literal: true

# AUTHORED UNRUN. Fresh process, Rails-free, exact installed Core + Map.
require 'json'
require 'digest'
require 'cgi'
require 'uri'
require 'thistle'
require 'thistle/map'
raise 'Consumer loaded a framework' if defined?(Rails) || defined?(ActiveRecord)
manifest = JSON.parse(File.read(ARGV.fetch(0)))
guard = manifest.fetch('controller_filter_guard')
raise 'Missing actual framework guard evidence' unless guard.values_at('registry_observed','only_create_observed','override_unavailable','override_invocations') == [true,true,true,0]
raise 'Ruby3.4 Hash-backed Set gate missing' if guard.fetch('ruby').start_with?('3.4.') && !guard.fetch('set_hash_backed')
generation = manifest.fetch('saved_a')
store = manifest.fetch('store')
home = File.realpath(ENV.fetch('GEM_HOME'))
%w[thistle thistle-map].each do |name|
  raise 'Consumer used checkout package' unless File.realpath(Gem.loaded_specs.fetch(name).full_gem_path).start_with?(home + '/')
end
raise 'Woods runtime present' if Gem::Specification.find_all.any? { |s| %w[woods woods-map].include?(s.name) }
def demand(value,message) = (raise message unless value)
def pages(reader, route, action, family: 'sequence')
  all = []; seen = []; cursor = nil
  64.times do
    answer = reader.passage(route,action:action,family:family,limit:1,cursor:cursor)
    demand(answer.fetch('generation') == reader.generation,'Generation changed')
    yield answer if block_given?
    all.concat(answer.fetch('items'))
    return all if answer.dig('coverage','page_complete')
    next_cursor = answer.fetch('next_cursor')
    demand(next_cursor && next_cursor != cursor && !seen.include?(next_cursor),'No finite forward progress')
    seen << next_cursor;cursor = next_cursor
  end
  raise 'Fixture exceeded finite64-page allowance'
end
def rack(app,path,params)
  status,headers,body = app.call({'REQUEST_METHOD'=>'GET','PATH_INFO'=>path,'SCRIPT_NAME'=>'/map',
    'QUERY_STRING'=>URI.encode_www_form(params),'HTTP_HOST'=>'localhost','REMOTE_ADDR'=>'127.0.0.1'})
  demand(status == 200,"Rack #{path} failed #{status}")
  [body.join,headers]
end
reader = Thistle::Reader.new(store,generation:generation)
begin
  routes = reader.find('orders',limit:50).select { |f| f['kind'] == 'route' }.map { |f| reader.fact(f.fetch('id')) }
  output = {}
  selection = [routes.find { |f| f.dig('attributes','action') == 'create' }.fetch('id'),routes.find { |f| f.dig('attributes','action') == 'index' }.fetch('id')].join(',')
  app = Thistle::Map::App.new(store:store)
  %w[create index preview conditional show missing].each do |action_name|
    route = routes.find { |f| f.dig('attributes','action') == action_name }
    demand(route,"Missing route #{action_name}")
    choose = reader.passage(route.fetch('id'))
    demand(choose['items'] == [] && choose['selected_action'].nil?,'Implicit action narrative')
    if action_name == 'show'
      demand(choose.dig('route','candidate_count','lower_bound') == 2,'Ambiguous action lost')
      output[action_name] = {'selection'=>'ambiguous','candidate_ids'=>choose.dig('route','candidates').map { |r|r.dig('fact','id') }}
      next
    elsif action_name == 'missing'
      demand(choose.dig('route','candidates').empty?,'Invented missing action')
      output[action_name] = {'selection'=>'no_candidate'}
      next
    end
    candidate = choose.dig('route','candidates').fetch(0).fetch('fact')
    rows = pages(reader,route.fetch('id'),candidate.fetch('id'))
    saves = rows.select { |r| r.dig('evidence','kind') == 'save_operation' }
    demand(!saves.empty? == %w[create conditional].include?(action_name),"Wrong selected-action save meaning #{action_name}")
    if action_name == 'create'
      demand(saves.all? { |r|r.dig('evidence','condition') == 'no_enclosing_branch_syntax' && !r.fetch('evidence').key?('branch') },'Create acquired an enclosing branch')
      demand(saves.first.dig('evidence','span','start_line') == 6,'Wrong direct create witness')
    elsif action_name == 'conditional'
      demand(saves.all? { |r|r.dig('evidence','condition') == 'inside_branch_syntax' && r.dig('evidence','branch','kind') == 'if' &&
        r.dig('evidence','branch','span','start_line') == 21 && r.dig('evidence','branch','span','end_line') == 21 },'Conditional action lost its actual branch enclosure')
    end
    exports = pages(reader,route.fetch('id'),candidate.fetch('id'),family:'export') do |answer|
      parsed = JSON.parse(answer.fetch('report').lines.drop(3).join)
      demand(parsed == answer.fetch('items'),'Export diverged from Reader items')
    end
    demand(exports == rows,'Export traversal differs')
    params = {'generation'=>generation,'id'=>route.fetch('id'),'action'=>candidate.fetch('id'),'selection'=>selection,'q'=>'orders','domain'=>'all'}
    cursor = nil; rendered = +''; sources = []
    64.times do
      html,headers = rack(app,'/passage/sequence',params.merge('cursor'=>cursor).compact)
      demand(headers.fetch('content-security-policy').include?("default-src 'none'"),'CSP lost')
      rendered << html
      html.scan(/href="([^"]+)"/).flatten.each do |href|
        uri = URI.parse(CGI.unescapeHTML(href))
        next unless uri.path.end_with?('/source') && uri.fragment&.match?(/\AL[1-9]\d*\z/)
        fields = URI.decode_www_form(uri.query).to_h
        demand(fields['generation'] == generation && fields['selection'] == selection && fields['q'] == 'orders','Source context changed')
        source_html,_ = rack(app,uri.path.delete_prefix('/map'),fields)
        demand(source_html.include?(%(id="#{uri.fragment}")),'Physical Source line missing')
        sources << fields.fetch('id')
      end
      navigation = Thistle::Map::NavigationContext.new(generation:generation,params:params,selection:Thistle::Map::Investigation.from_params(params))
      answer = reader.passage(route.fetch('id'),action:candidate.fetch('id'),limit:Thistle::Map::PassagePresenter.page_limit(navigation),
        max_bytes:Thistle::Map::PassagePresenter.request_bytes(navigation),cursor:cursor)
      break if answer.dig('coverage','page_complete')
      cursor = answer.fetch('next_cursor')
    end
    demand(rendered.include?('Potential registered save callback contribution') == %w[create conditional].include?(action_name),'Map save meaning differs')
    demand(rendered.include?('Inside if branch syntax at saved line 21') == (action_name == 'conditional'),'Map conditional meaning differs')
    demand(rendered.include?('Captured filter registry label candidate'),'Local registry status missing')
    demand(rendered.include?('Selected action source scan complete'),'Local source completeness missing')
    demand(sources.include?(candidate.fetch('id')),'No real action Source')
    # Exercise the actual family-specific Map export admission, not just Reader
    # export or a standalone renderer. Keep its explicit same-family cursor.
    export_rows = []; export_cursor = nil; export_seen = []; export_complete = false
    64.times do
      export_params = params.merge('cursor'=>export_cursor).compact
      export_html,_ = rack(app,'/passage/export',export_params)
      demand(export_html.include?('Potential request Passage'),'Actual Map export missing')
      nav = Thistle::Map::NavigationContext.new(generation:generation,mount:'/map',params:export_params,
        selection:Thistle::Map::Investigation.from_params(export_params))
      export = reader.passage(route.fetch('id'),action:candidate.fetch('id'),family:'export',
        limit:Thistle::Map::PassagePresenter.page_limit(nav),cursor:export_cursor,
        max_bytes:Thistle::Map::PassagePresenter.request_bytes(nav,family:'export',action:candidate.fetch('id')))
      export_rows.concat(export.fetch('items'))
      if export.dig('coverage','page_complete')
        export_complete = true
        break
      end
      next_cursor = export.fetch('next_cursor')
      demand(next_cursor && next_cursor != export_cursor && !export_seen.include?(next_cursor),'Export made no finite progress')
      export_seen << next_cursor; export_cursor = next_cursor
    end
    demand(export_complete,'Fixture export exceeded finite64-page allowance')
    demand(export_rows == rows,'Actual Map-family export and sequence changed selected-action evidence')
    if action_name == 'create'
      demand(saves.any? { |r| r.dig('save_contribution','callbacks').any? { |c| c.dig('witness','name') == 'Order#queue_receipt' && c.dig('effects','details') == 'not_projected' } },'Actual compact model callback contribution absent')
      demand(rows.any? { |r| r.dig('witness','name') == 'ApplicationController#authenticate' },'Inherited filter edit witness absent')
      demand(rows.any? { |r| r.dig('witness','name') == 'OrdersController#check_order' },'Action filter edit witness absent')
      demand(sources.uniq.length >= 4,'Distinct action/filter/model Source witnesses missing')
      job_row = rows.find { |r|r.dig('evidence','kind') == 'async_boundary' }
      demand(job_row && job_row['followup'],'No potential job boundary followup')
      job = reader.job_mail(job_row.dig('followup','id'),family:'handoff',limit:16)
      mailer = job.fetch('items').find { |r| r.dig('candidate','name') == 'ReceiptMailer#receipt' }
      demand(mailer,'No qualified related mailer candidate')
      mail = reader.job_mail(mailer.dig('candidate','id'),family:'handoff',limit:16)
      template = mail.fetch('items').find { |r| r.dig('candidate','path') == 'app/views/receipt_mailer/receipt.html.erb' }
      demand(template,'No explicit template candidate')
      source = reader.source(template.dig('candidate','id'))
      demand(source.fetch('content').include?('Captured ERB must never be evaluated'),'Wrong saved template')
      template_html,_ = rack(app,'/source',params.slice('generation','selection','q','domain').merge('id'=>template.dig('candidate','id')))
      demand(template_html.include?('Captured ERB must never be evaluated'),'Rendered exact template Source absent')
      output['template'] = {'id'=>template.dig('candidate','id'),'path'=>source.dig('fact','path'),'sha256'=>source.fetch('sha256')}
    elsif action_name == 'index'
      demand(rows.any? { |r| r['applicability'] == 'excluded_by_recorded_action_condition' },'Action applicability not switched')
    end
    output[action_name] = {'route'=>route.fetch('id'),'action'=>candidate.fetch('id'),'operation_kinds'=>rows.filter_map { |r|r.dig('evidence','kind') },
      'save_conditions'=>saves.map { |r|r.fetch('evidence').slice('condition','branch','span') },'source_ids'=>sources.uniq}
  end
  source = reader.source(output.fetch('index').fetch('action'))
  demand(source.fetch('content').include?('saved_a') && !source.fetch('content').include?('saved_b'),'Pinned Source changed after CURRENT B')
  partial = Thistle::Reader.new(store,generation:manifest.fetch('partial'))
  begin
    result = partial.passage(output.fetch('index').fetch('route'),action:output.fetch('index').fetch('action'))
    demand(result.dig('route','coverage','capture_partial_or_unknown'),'Partial capture erased')
  ensure
    partial.close
  end
  puts JSON.generate({'generation'=>generation,'current_b'=>manifest.fetch('current_b'),'cards'=>output,'framework_loaded'=>false,
    'scope'=>'Installed Reader/Rack only; served keyboard/noJS/narrow/person remain separate'})
ensure
  reader.close
end
