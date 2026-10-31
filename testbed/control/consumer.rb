# frozen_string_literal: true

require_relative 'profile'
HostProfile.activate(consumer: true)
require 'thistle/map'
require 'rack/mock'
require 'uri'
require 'cgi'
require_relative 'http'
require_relative 'answers'
HostProfile.framework_free!
out = ARGV.fetch(0)
raise 'Expected private attempt path' unless out.match?(%r{\A/work/sessions/[0-9a-f]{32}/attempts/[0-9a-f]{32}\z})
ownership = JSON.parse(File.read(File.join(out, 'begin.json')))
raise 'Attempt owner mismatch' unless ownership.fetch('attempt') == File.basename(out) && ownership.fetch('token') == out.split('/')[3]
store = File.join(out, 'store')
receipt = JSON.parse(File.read(File.join(out, 'producer.json')))
expected = JSON.parse(File.read('/input/app/expected.json'))
reader = latest = nil
begin
  reader = Thistle::Reader.new(store, generation: receipt.fetch('saved'))
  latest = Thistle::Reader.new(store)
  raise 'Wrong CURRENT' unless latest.generation == receipt.fetch('current') && latest.generation != reader.generation
  select = ->(name, kind) do
    found = reader.find(name).select { |fact| fact['name'] == name && fact['kind'] == kind }
    raise 'Known fact absent or ambiguous' unless found.length == 1
    found.first
  end
  model = select.call('Order', 'rails_model')
  associations = model.dig('attributes', 'model', 'associations', 'entries')
  raise 'Model associations missing' unless associations.any? { |a| a['name'] == 'items' && a['macro'] == 'has_many' && a['target'] == 'Item' }
  columns = model.dig('attributes', 'model', 'columns', 'entries')
  raise 'Model columns differ' unless columns.map { |c| [c['name'], c['type'], c['null']] }.sort == expected.fetch('columns').fetch('orders')
  registry = select.call('Order', 'rails_save_callbacks')
  raise 'Callback evidence absent' unless registry.dig('attributes', 'callbacks', 'save', 'entries').any? { |row| row.dig('filter', 'name') == 'normalize_reference' }
  origin = select.call('Inspection#sites', 'method')
  order = select.call('Order', 'class')
  source = reader.source(origin.fetch('id'))
  raise 'Pinned source changed' unless source.fetch('sha256') == receipt.fetch('source_sha256') && source.fetch('generation') == reader.generation
  raise 'Pinned source is not canonical' unless source.fetch('content') == File.binread('/input/app/app/services/inspection.rb')
  sites = reader.links(origin.fetch('id')).select { |link| link['relation'] == 'references_constant' && link['target'] == 'Order' }
  raise 'Two same-target sites lost' unless sites.length == 2 && sites.map { |s| s.dig('attributes', 'thistle_constant', 'role') }.sort == %w[argument value]
  locations = sites.map { |s| s.dig('attributes', 'thistle_constant', 'location') }
  raise 'Sites coalesced' unless locations.uniq.length == 2
  raise 'Site anchors differ' unless locations.map { |loc| loc[2] }.sort == expected.fetch('site_lines')
  locations.each do |location|
    raise 'Site source mismatch' unless source.fetch('content').byteslice(location[0]...location[1]) == 'Order'
  end
  check = reader.check
  raise 'Saved check failed' unless check.fetch('integrity') == 'verified' && check.fetch('generation') == reader.generation
  routes = reader.facts.select { |fact| fact['kind'] == 'route' }
  selected_routes = routes.select { |fact| expected.fetch('route').all? { |key, value| fact.dig('attributes', key) == value } }
  raise 'Runtime route missing or ambiguous' unless selected_routes.length == 1
  oracle = { 'saved' => reader.generation, 'origin_id' => origin.fetch('id'), 'order_id' => order.fetch('id'),
    'source_sha256' => Digest::SHA256.file('/input/app/app/services/inspection.rb').hexdigest,
    'site_lines' => expected.fetch('site_lines'), 'site_count' => 2 }
  app = Rack::MockRequest.new(Thistle::Map::App.new(store: store))
  pages = {}
  request = ->(path, params) do
    query = URI.encode_www_form(params.merge('generation' => reader.generation))
    response = app.get("#{path}?#{query}", 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1')
    raise 'Map response failed' unless response.status == 200 && response.body.include?(reader.generation)
    response.body
  end
  pages['find'] = request.call('/', { 'q' => 'Inspection#sites' })
  pages['source'] = request.call('/source', { 'id' => origin.fetch('id') })
  pages['links'] = request.call('/links', { 'id' => origin.fetch('id') })
  pages['incoming'] = request.call('/links', { 'id' => order.fetch('id'), 'direction' => 'incoming' })
  pages['check'] = request.call('/check', {})
  %w[find source links incoming check].each { |kind| MapAnswers.verify(kind, pages.fetch(kind), oracle) }
  # INTERNAL UNIX transport; host URL/concurrency is checked separately.
  socket = "/work/sessions/#{ownership.fetch('token')}/http.sock"
  { 'find' => ['/', { 'q' => 'Inspection#sites' }], 'source' => ['/source', { 'id' => origin.fetch('id') }],
    'links' => ['/links', { 'id' => origin.fetch('id') }],
    'incoming' => ['/links', { 'id' => order.fetch('id'), 'direction' => 'incoming' }],
    'check' => ['/check', {}] }.each do |name, (path, params)|
    query = URI.encode_www_form(params.merge('generation' => reader.generation))
    response = HostHTTP.request(socket, "/map#{path}?#{query}")
    raise 'Map internal UNIX HTTP failed' unless response.code == '200'
    MapAnswers.verify(name, response.body, oracle)
    pages["http-#{name}"] = response.body
  end
  %w[links incoming].each do |name|
    raise 'F05 rows missing' unless pages.fetch(name).scan('class="constant-site"').length >= 2
    %w[argument value].each { |role| raise 'F05 role missing' unless pages.fetch(name).include?("Role: #{role}") }
  end
  hrefs = pages['incoming'].scan(/href="([^"]+#L\d+)"/).flatten.map { |href| CGI.unescapeHTML(href) }.uniq
  lines = locations.map { |loc| "L#{loc[2]}" }
  lines.each do |line|
    href = hrefs.find { |h| URI.parse(h).fragment == line } or raise 'Pinned site link absent'
    uri = URI.parse(href)
    params = URI.decode_www_form(uri.query).to_h
    raise 'Link changed generation' unless params.fetch('generation') == reader.generation
    page = request.call(uri.path, params)
    raise 'Pinned source line/digest absent' unless page.include?("id=\"#{line}\"") && page.include?(source.fetch('sha256'))
    pages["follow-#{line}"] = page
  end
  HostProfile.write(File.join(out, 'reader.json'), { 'source' => source, 'sites' => sites, 'model' => model,
    'callbacks' => registry, 'routes' => routes, 'check' => check, 'origin' => origin })
  HostProfile.write(File.join(out, 'map.json'), pages)
  HostProfile.write(File.join(out, 'oracle.json'), oracle)
  identity = HostProfile.identities(reference: receipt.fetch('identity'))
  raise 'Native producer/reader mismatch' unless identity.fetch('native') == receipt.fetch('identity').fetch('native')
  HostProfile.framework_free!
  HostProfile.write(File.join(out, 'consumer.json'), { 'status' => 'passed', 'saved' => reader.generation,
    'current' => latest.generation, 'identity' => identity, 'rails_free' => true,
    'scope' => 'installed Reader, Map Rack and INTERNAL UNIX HTTP; host URL checked separately; browser/human unobserved' })
ensure
  latest&.close
  reader&.close
end
