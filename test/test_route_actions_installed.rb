# frozen_string_literal: true

# MANUAL, AUTHORED UNRUN. Root admits installed/framework/store/App execution.
# Execute with isolated installed gems, from outside this checkout, without -I.
require 'cgi'
require 'uri'

# Pure evidence assertions can be exercised without activating installed gems,
# booting a framework, creating a store or running the manual driver below.
module RouteActionsMapAssertions
  def self.status!(html, expected)
    marker = %(<p class="notice ui">#{CGI.escapeHTML(expected)}</p>)
    raise "Missing Map status: #{expected}" unless html.include?(marker)
  end

  def self.source_targets(html)
    html.scan(/href="([^"]+)"/).flatten.filter_map do |href|
      uri = URI.parse(CGI.unescapeHTML(href))
      uri if uri.scheme.nil? && uri.host.nil? && uri.path.end_with?('/source') && uri.fragment&.match?(/\AL[1-9]\d*\z/)
    end
  end

  def self.distinct_sources!(targets, count)
    ids = targets.map { |uri| URI.decode_www_form(uri.query.to_s).to_h.fetch('id') }.uniq
    raise 'Map did not expose distinct saved Source identities' unless ids.length == count
    ids
  end
end

if $PROGRAM_NAME == __FILE__
  require 'json'
  require 'open3'
  require 'rbconfig'
  require 'tmpdir'
  require 'fileutils'
  require 'digest'
  require 'cgi'
  require 'uri'

  def demand(value, message)
    raise message unless value
  end

  def installed!
    require 'thistle'
    gem_home = File.realpath(ENV.fetch('GEM_HOME'))
    demand(File.realpath(Gem.loaded_specs.fetch('thistle').full_gem_path).start_with?(gem_home + '/'), 'Core was not loaded from isolated installed gems')
    demand(Gem::Specification.find_all.none? { |spec| %w[woods woods-map].include?(spec.name) }, 'Woods runtime present')
  end

  def pages(reader, id)
    rows, seen, cursor = [], [], nil
    16.times do
      answer = reader.route_actions(id, limit: 1, cursor: cursor)
      demand(answer.fetch('generation') == reader.generation, 'Candidate page changed generation')
      yield answer if block_given?
      rows.concat(answer.fetch('candidates'))
      return rows if answer.dig('coverage','page_complete')
      next_cursor = answer.fetch('next_cursor')
      demand(next_cursor && next_cursor != cursor && !seen.include?(next_cursor), 'Candidate continuation failed to advance')
      seen << next_cursor
      cursor = next_cursor
    end
    raise 'Known-answer candidate traversal exceeded finite fixture bound'
  end

  mode, fixture, store, generation, partial_generation = ARGV
  if mode == 'capture'
    installed!
    require File.join(fixture,'booted_app')
    app = RouteActionsFixture.boot
    demand(Rails.version == '8.1.4', 'First route-actions installed fixture requires Rails 8.1.4')
    # Real installed producer -> saved A, with static late duplicate and observed
    # route defaults/constraints. No controller or endpoint is invoked.
    capture = Thistle::Capture.new(root: fixture, rails: app).call
    a = Thistle::Store.new(store).publish(capture)
    partial = Marshal.load(Marshal.dump(capture))
    partial.fetch('coverage').find { |row| row['family']=='ruby_declarations' }.merge!('status'=>'partial','reason'=>'Independent partial negative card')
    p = Thistle::Store.new(store).publish(partial)
    path = File.join(fixture,'app/controllers/orders_controller.rb')
    File.write(path,File.read(path).sub(':saved_a',':saved_b'))
    b = Thistle.capture(root: fixture, output: store, rails: app)
    demand(a['generation'] != b['generation'], 'CURRENT B did not advance')
    puts JSON.generate('a'=>a.fetch('generation'),'partial'=>p.fetch('generation'),'b'=>b.fetch('generation'))
  elsif %w[read map].include?(mode)
    installed!
    demand(!defined?(Rails), 'Fresh consumer loaded Rails')
    current = Thistle::Reader.new(store)
    demand(current.generation != generation, 'CURRENT still points at A')
    current.close
    reader = Thistle::Reader.new(store, generation: generation)
    begin
      cards = JSON.parse(File.read(File.join(fixture,'expected_cards.json')))
      routes = reader.facts.select { |fact| fact['kind']=='route' }.to_h { |fact| [fact.dig('attributes','route_name'),fact] }
      cards.reject { |key,_| %w[note partial_capture refused_page].include?(key) }.each do |name,card|
        route = routes.fetch(name)
        rows = pages(reader,route.fetch('id')) do |answer|
          demand(answer['status']==card.fetch('status'), "Wrong #{name} status: #{answer['status']}")
          demand(answer['candidate_count']['lower_bound']==card.fetch('count'), "Wrong #{name} global count witness")
          demand(answer['route']['attributes']==route['attributes'] && answer['route']['links']==route['links'], 'Original defaults/constraints/provenance changed')
          demand(answer['root']['path'].nil? && answer['root']['span'].nil?, 'Invented route physical source')
          demand(answer['unknowns'].values.all? { |value| value=='unknown' }, 'Candidate acquired execution/binding proof')
          demand(answer['usage']['source_reads']==0, 'Candidate selection read source')
        end
        demand(rows.map { |row| row.dig('fact','path') }.sort==card.fetch('paths').sort, "Wrong physical paths for #{name}")
        rows.each do |row|
          source = reader.source(row.fetch('fact').fetch('id'))
          demand(source['generation']==generation && source['fact']['id']==row['fact']['id'], 'Saved Source identity changed')
          demand(Digest::SHA256.hexdigest(source.fetch('content'))==source.fetch('sha256'), 'Saved Source digest mismatch')
          demand(source['fact']['location']==row['fact']['span'], 'Saved candidate span changed')
          demand(source.dig('fact','location','start_line')==card['line'], 'Wrong handwritten physical line') if card['line']
          demand(source['content'].include?(':saved_a') && !source['content'].include?(':saved_b'), 'CURRENT B replaced saved A Source') if name=='orders'
        end
      end
      demand(routes.fetch('orders').dig('attributes','controller')=='orders', 'Producer defaults missing')
      demand(reader.route_actions(routes.fetch('orders')['id'])['candidates'][0]['fact']['id']==reader.route_actions(routes.fetch('all_orders')['id'])['candidates'][0]['fact']['id'], 'Two routes lost common saved method identity')
      begin
        reader.route_actions(routes.fetch('orders')['id'],max_bytes: cards.dig('refused_page','max_bytes'))
        raise 'Byte refusal unexpectedly succeeded'
      rescue Thistle::LimitExceeded
        # Expected mandatory-envelope refusal, no successful empty answer.
      end
      partial = Thistle::Reader.new(store,generation: partial_generation)
      begin
        answer = partial.route_actions(routes.fetch('orders')['id'])
        demand(answer['status']==cards.dig('partial_capture','status') && answer.dig('coverage','capture_partial_or_unknown'), 'Partial discovery became successful proof')
      ensure
        partial.close
      end
      if mode=='map'
        require 'thistle/map'
        gem_home = File.realpath(ENV.fetch('GEM_HOME'))
        demand(File.realpath(Gem.loaded_specs.fetch('thistle-map').full_gem_path).start_with?(gem_home+'/'), 'Map was not installed')
        app = Thistle::Map::App.new(store: store)
        env = {'REQUEST_METHOD'=>'GET','SCRIPT_NAME'=>'/map','HTTP_HOST'=>'localhost','REMOTE_ADDR'=>'127.0.0.1','rack.url_scheme'=>'http'}
        fields = {'generation'=>generation,'id'=>routes.fetch('orders')['id'],'selection'=>routes.fetch('orders')['id'],'q'=>'orders','domain'=>'metadata','kind'=>'route','prefix'=>'app'}
        get = ->(path, params) do
          status, _, body = app.call(env.merge('PATH_INFO'=>path,'QUERY_STRING'=>URI.encode_www_form(params)))
          html=body.each.to_a.join
          body.close if body.respond_to?(:close)
          demand(status==200,"Installed Map #{path} status #{status}")
          html
        end
        route_source = get.call('/source',fields)
        demand(route_source.include?('Inspect controller/action candidates'),'Route lacks typed evidence entry')
        html = get.call('/route-actions',fields)
        demand(html.include?('One conventional static candidate'), 'Unique conventional candidate page missing')
        hrefs = html.scan(/href="([^"]+)"/).flatten.map { |href| CGI.unescapeHTML(href) }
        target = URI.parse(hrefs.find { |href| href.include?('/source?') && href.end_with?('#L2') } || raise('Physical candidate Source href absent'))
        source_fields = URI.decode_www_form(target.query).to_h
        demand(source_fields.values_at('generation','selection','q')==fields.values_at('generation','selection','q'), 'Map lost generation/investigation/search')
        source_html = get.call('/source',source_fields)
        demand(source_html.include?('id="L2"') && source_html.include?('source-row selected') && source_html.include?(':saved_a') && !source_html.include?(':saved_b'),'Map failed to reveal physical A source after CURRENT B')
        cards.reject { |name,_| %w[note partial_capture refused_page].include?(name) }.each do |name,card|
          card_fields = fields.merge('id'=>routes.fetch(name)['id'])
          card_html = get.call('/route-actions',card_fields)
          RouteActionsMapAssertions.status!(card_html,card.fetch('map_status'))
          next unless name == 'order'

          targets, seen = [], []
          16.times do
            targets.concat(RouteActionsMapAssertions.source_targets(card_html))
            continuation = card_html.scan(/<a href="([^"]+)">Continue saved action candidates<\/a>/).flatten.first
            break unless continuation
            uri = URI.parse(CGI.unescapeHTML(continuation))
            demand(uri.path=='/map/route-actions' && uri.host.nil? && uri.scheme.nil?, 'Foreign Map continuation')
            next_fields = URI.decode_www_form(uri.query).to_h
            demand(next_fields.values_at('generation','selection','q')==fields.values_at('generation','selection','q'), 'Map continuation lost pinned context')
            demand(!seen.include?(next_fields.fetch('cursor')), 'Repeated Map continuation')
            seen << next_fields.fetch('cursor')
            card_html = get.call('/route-actions',next_fields)
            RouteActionsMapAssertions.status!(card_html,card.fetch('map_status'))
          end
          targets.each do |target|
            target_fields = URI.decode_www_form(target.query).to_h
            demand(target_fields.values_at('generation','selection','q')==fields.values_at('generation','selection','q'), 'Duplicate Source witness lost context')
          end
          RouteActionsMapAssertions.distinct_sources!(targets,card.fetch('count'))
        end
        partial_html = get.call('/route-actions',fields.merge('generation'=>partial_generation))
        RouteActionsMapAssertions.status!(partial_html,cards.fetch('partial_capture').fetch('map_status'))
      end
      demand(!defined?(Rails), 'Reader/Map consumer booted Rails')
      puts JSON.generate('generation'=>generation,'mode'=>mode,'result'=>'installed route candidates and exact saved Source assertions passed')
    ensure
      reader.close
    end
  else
    # Root's outer finite process/output controls own this complete workflow.
    script = File.expand_path(__FILE__)
    Dir.mktmpdir('route-actions-installed-') do |temporary|
      copied = File.join(temporary,'fixture')
      FileUtils.cp_r(File.expand_path('fixtures/route_actions',__dir__),copied)
      saved_store = File.join(temporary,'store')
      out, err, result = Open3.capture3(RbConfig.ruby,script,'capture',copied,saved_store,chdir: temporary)
      demand(result.success?,"Capture subprocess failed: #{err}")
      tuple=JSON.parse(out.lines.last)
      %w[read map].each do |step|
        out, err, result = Open3.capture3(RbConfig.ruby,script,step,copied,saved_store,tuple.fetch('a'),tuple.fetch('partial'),chdir: temporary)
        demand(result.success?,"#{step} subprocess failed: #{err}")
        puts out
      end
    end
  end
end
