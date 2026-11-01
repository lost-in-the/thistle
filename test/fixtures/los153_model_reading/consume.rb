# frozen_string_literal: true

# AUTHORED UNRUN. Fresh installed process; does not start or contact a server.
raise 'Explicit LOS153 consumer admission required' unless ENV['THISTLE_LOS153_INSTALLED'] == '1'
require 'json'
require 'digest'
require 'uri'
require 'cgi'
require 'thistle'
require 'thistle/map'
raise 'Consumer loaded producing framework' if defined?(Rails) || defined?(ActiveRecord)
manifest = JSON.parse(File.read(ARGV.fetch(0)))
cards = JSON.parse(File.read(File.join(__dir__, 'expected_cards.json')))
raise 'Wrong producer' unless manifest.fetch('rails_version') == cards.fetch('framework')
raise 'Producer did not exercise callback full recovery' unless manifest.fetch('schedule_registered_position') >= 8
home = File.realpath(ENV.fetch('GEM_HOME'))
%w[thistle thistle-map].each do |name|
  raise 'Checkout package used' unless File.realpath(Gem.loaded_specs.fetch(name).full_gem_path).start_with?(home + '/')
end
raise 'Woods package present' if Gem::Specification.find_all.any? { |spec| %w[woods woods-map].include?(spec.name) }
native = $LOADED_FEATURES.find { |path| path.match?(%r{/thistle/thistle_native\.(so|bundle|dll)\z}) }
raise 'Installed native absent' unless native
def demand(value, reason) = (raise reason unless value)
def collect_family(reader, id, family)
  rows = []; cursor = nil; seen = []
  16.times do
    answer = reader.source_comprehension(id, family: family, cursor: cursor, limit: 8, max_bytes: 32768)
    demand(answer.fetch('generation') == reader.generation && answer.fetch('source_runtime_coherence') == 'unknown', 'Lost saved evidence boundary')
    yield answer, cursor if block_given?
    rows.concat(answer.fetch('contributions'))
    return rows unless answer['continuation']
    next_cursor = answer.fetch('continuation').fetch('cursor')
    demand(!seen.include?(next_cursor) && next_cursor != cursor, 'Comprehension cursor stalled')
    seen << next_cursor; cursor = next_cursor
  end
  raise 'Fixture exceeded finite 16-page family allowance'
end
def links(html)
  html.scan(/href="([^"]+)"/).flatten.map { |href| URI(CGI.unescapeHTML(href)) }
end
generation = manifest.fetch('saved_a'); store = manifest.fetch('store')
reader = Thistle::Reader.new(store, generation: generation)
begin
  models = reader.find(cards.fetch('model'), limit: 50).select { |fact| fact['kind'] == 'rails_model' && fact['name'] == cards.fetch('model') }
  demand(models.length == 1, 'Fixture must have one explicit saved Order registry')
  id = models.fetch(0).fetch('id') # uniqueness is a fixture oracle, not runtime binding
  contributions = collect_family(reader, id, 'contributions')
  method_pages = []
  methods = collect_family(reader, id, 'methods') { |answer, cursor| method_pages << [answer, cursor] }
  demand(method_pages.length >= 2 && method_pages.first[0]['continuation'], 'Fixture did not exercise a real methods continuation')
  suffix_card = cards.fetch('methods_continuation')
  suffix_page = method_pages.index { |answer, _| answer.fetch('contributions').any? { |row| row.dig('fact', 'name') == suffix_card.fetch('method') } }
  demand(suffix_page && suffix_page.positive?, 'Independent suffix method did not require continuation')
  source_ids = {}
  cards.fetch('cards').each do |card|
    rows = card['method'] ? methods : contributions
    found = rows.select do |row|
      fact = row.fetch('fact')
      fact['name'] == (card['method'] || card.fetch('owner')) && fact['path'] == card.fetch('path') &&
        fact.dig('location', 'start_line') == (card['method'] ? card.fetch('line') : 2)
    end
    demand(found.length == 1, "Independent physical card missing/ambiguous: #{card.fetch('question')}")
    fact = found.fetch(0).fetch('fact')
    source = reader.source(fact.fetch('id'))
    demand(source.fetch('generation') == generation && source.fetch('sha256') == manifest.fetch('source_sha256').fetch(card.fetch('path')), 'Source identity differs from A')
    demand(source.fetch('content').lines.fetch(card.fetch('line') - 1).include?(card.fetch('source_contains')), 'Independent physical line differs')
    demand(source.fetch('content').lines.fetch(card.fetch('line')).include?(card.fetch('next_line')), 'Guard source differs') if card['next_line']
    source_ids[card['method'] || card.fetch('owner')] = fact.fetch('id')
  end
  demand(methods.any? { |row| row['owner'] == 'ReceiptPolicy' && row.dig('fact', 'name') == 'ReceiptPolicy#schedule_receipt' }, 'Concern contribution missing')
  columns = reader.model_neighborhood(id, family: 'columns', limit: 8).fetch('items').map { |row| row.fetch('column') }
  demand(columns == manifest.fetch('raw_order_columns'), 'Saved typed columns differ from post-A adapter oracle')
  cards.fetch('cards').last.fetch('columns').each do |name, type|
    demand(columns.any? { |column| column['name'] == name && column['type'] == type }, 'Independent column type missing')
  end
  associations = reader.model_neighborhood(id, family: 'edges', type: 'association', limit: 8).fetch('items')
  cards.fetch('cards').last.fetch('associations').each do |name, expected|
    demand(associations.any? { |row| row.dig('association', 'name') == name && [row['relation'], row['target_label']] == expected && row['binding'] == 'unknown' }, 'Independent association missing or binding invented')
  end
  registry = reader.model_brief(id, family: 'registry_candidates', limit: 8).fetch('result').fetch('items')
  demand(registry.length == 1 && registry.fetch(0)['name'] == 'Order', 'Explicit fixture callback registry candidate missing/ambiguous')
  registry_id = registry.fetch(0).fetch('id')
  compact_callbacks = reader.callback_effects(registry_id, limit: 8)
  demand(compact_callbacks.dig('coverage', 'truncated'), 'Fixture did not exceed compact8 callbacks')
  demand(compact_callbacks.fetch('callbacks').none? { |row| row.dig('filter', 'name') == 'schedule_receipt' }, 'Fixture scheduling callback was not beyond compact8')
  callbacks = reader.callback_effects(registry_id, limit: 200)
  receipt = callbacks.fetch('callbacks').select { |row| row.dig('filter', 'name') == 'schedule_receipt' }
  demand(receipt.length == 1, 'Named registered callback missing/ambiguous')
  demand(receipt.fetch(0).dig('filter', 'owner') == 'ReceiptPolicy', 'Observed callback owner differs')
  demand(receipt.fetch(0).fetch('if').any? { |condition| condition['name'] == 'receipt_due?' }, 'Registered guard missing')
  demand(callbacks.fetch('execution') == 'unknown' && callbacks.fetch('coherence') == 'unknown', 'Execution/coherence invented')
  # These in-process Rack link controls do not establish actual served/browser QA.
  selection = [id, source_ids.fetch('ReceiptPolicy#schedule_receipt')].join(',')
  context = { 'generation' => generation, 'id' => id, 'selection' => selection, 'q' => 'Order', 'domain' => 'metadata' }
  app = Thistle::Map::App.new(store: store)
  requests = 0
  get = lambda do |path, params|
    requests += 1; demand(requests <= 12, 'Rack control request allowance exceeded')
    status, headers, body = app.call('REQUEST_METHOD' => 'GET', 'PATH_INFO' => path.delete_prefix('/map'), 'SCRIPT_NAME' => '/map',
      'QUERY_STRING' => URI.encode_www_form(params), 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1')
    demand(status == 200, "Rack control refused #{status}: #{body.join}")
    demand(headers.fetch('content-security-policy').include?("default-src 'none'"), 'CSP missing')
    body.join
  end
  page = get.call("/models/#{id}/source", context)
  demand(page.include?('aria-label="Model reading"') && page.include?('app/models/order.rb') && page.include?('saved_a') && !page.include?('current_b'), 'Reading lost full primary A source')
  # The outline may continue, but the named concern declaration is on this
  # focused fixture's first contribution page. Select its exact physical Source.
  concern = contributions.select { |row| row.dig('fact', 'name') == 'ReceiptPolicy' }
  demand(concern.length == 1, 'Fixture concern declaration ambiguous')
  physical = links(page).find { |uri| URI.decode_www_form(uri.query || '').to_h['id'] == concern.fetch(0).dig('fact', 'id') && uri.fragment&.start_with?('L') }
  demand(physical, 'Named concern exact Source link missing')
  preserved = context.reject { |key, _| key == 'id' }
  demand(preserved.all? { |key, value| URI.decode_www_form(physical.query).to_h[key] == value }, 'Source link lost saved context')
  source_page = get.call(physical.path, URI.decode_www_form(physical.query).to_h)
  returned = source_page.match(/href="([^"]+)"[^>]*>Return to model reading/)
  demand(returned, 'Canonical model return missing')
  return_uri = URI(CGI.unescapeHTML(returned[1]))
  restored = get.call(return_uri.path, URI.decode_www_form(return_uri.query).to_h)
  demand(return_uri.fragment && restored.match?(/<div class="source-row[^"]*" id="#{Regexp.escape(return_uri.fragment)}">/), 'Return did not restore an actual physical source-row')
  demand(!restored.include?('Requested physical position is not displayed'), 'Notice was mistaken for physical source')
  demand(restored.include?(%(name="selection" value="#{selection}")) && restored.include?('value="Order"'), 'Return query/full selection lost')
  get.call("/models/#{id}/model-neighborhood/columns/outgoing/all", context)
  get.call("/models/#{id}/model-neighborhood/edges/outgoing/association", context)
  registry_page = get.call("/models/#{id}/brief/registry_candidates", context)
  demand(registry_page.include?('registered callback evidence'), 'Explicit registry choice absent')
  compact_page = get.call("/models/#{id}/model-callbacks", context.merge('id' => registry_id))
  full = links(compact_page).find { |uri| uri.path.end_with?('/model-callbacks/full') }
  demand(full, 'Compact callback page has no named full registered recovery')
  callback_page = get.call(full.path, URI.decode_www_form(full.query).to_h)
  %w[schedule_receipt receipt_due? ReceiptPolicy].each { |name| demand(callback_page.include?(name), 'Named callback beyond8 not reachable in full recovery') }
  # Follow the real first continuation, rather than replay a fabricated cursor.
  more = links(page).find { |uri| uri.path.end_with?('/comprehension/methods') && URI.decode_www_form(uri.query || '').to_h['cursor'] }
  demand(more && URI.decode_www_form(more.query).to_h['cursor'] == method_pages.first[0].fetch('continuation').fetch('cursor'), 'Actual outline continuation differs from Core')
  suffix_rows = get.call(more.path, URI.decode_www_form(more.query).to_h)
  demand(suffix_rows.include?(suffix_card.fetch('method')), 'First continued page did not expose the independent named suffix fixture')
  suffix = methods.select { |row| row.dig('fact', 'name') == suffix_card.fetch('method') }
  demand(suffix.length == 1 && suffix[0].dig('fact', 'path') == suffix_card.fetch('path') && suffix[0].dig('fact', 'location', 'start_line') == suffix_card.fetch('line'), 'Independent suffix method physical location differs')
  exact = links(suffix_rows).find { |uri| URI.decode_www_form(uri.query || '').to_h['id'] == suffix[0].dig('fact', 'id') && uri.fragment == "L#{suffix_card.fetch('line')}" }
  demand(exact, 'Continued method exact Source absent')
  exact_page = get.call(exact.path, URI.decode_www_form(exact.query).to_h)
  back = exact_page.match(/href="([^"]+)"[^>]*>Return to model reading/)
  demand(back, 'Continued source return missing')
  back_uri = URI(CGI.unescapeHTML(back[1])); back_params = URI.decode_www_form(back_uri.query).to_h
  demand(back_params['cursor'] == URI.decode_www_form(more.query).to_h['cursor'] && back_params['selection'] == selection && back_params['q'] == 'Order', 'Continued return lost cursor/query/selection')
  continued_restored = get.call(back_uri.path, back_params)
  demand(continued_restored.match?(/<div class="source-row[^"]*" id="#{Regexp.escape(back_uri.fragment)}">/) && !continued_restored.include?('Requested physical position is not displayed'), 'Continued return restored a notice instead of the actual source-row')
  partial = Thistle::Reader.new(store, generation: manifest.fetch('partial'))
  begin
    demand(partial.model_neighborhood(id, family: 'columns').dig('coverage', 'capture_partial_or_unknown'), 'Partial capture hidden')
  ensure
    partial.close
  end
  current = Thistle::Reader.new(store)
  begin
    demand(current.generation == manifest.fetch('current_b') && current.generation != generation, 'CURRENT is not B')
  ensure
    current.close
  end
  puts JSON.generate('result' => 'candidate_development_only', 'generation' => generation, 'model_id' => id,
    'selection' => selection, 'focus_path' => "/models/#{id}/source", 'source_ids' => source_ids, 'registry_id' => registry_id,
    'rack_requests' => requests, 'native_path' => native, 'native_sha256' => Digest::SHA256.file(native).hexdigest,
    'served_keyboard_nojs_zoom_ime_person' => 'UNRUN', 'all17' => 'UNQUALIFIED')
ensure
  reader.close
end
