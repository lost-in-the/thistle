# frozen_string_literal: true

# AUTHORED UNRUN: fresh Rails-free installed Core+Map, after producer advances B.
require 'json'
require 'cgi'
require 'uri'
require 'digest'
require 'thistle'
require 'thistle/map'
raise 'Consumer loaded Rails' if defined?(Rails) || defined?(ActiveRecord)
manifest = JSON.parse(File.read(ARGV.fetch(0)))
cards = JSON.parse(File.read(File.join(__dir__, 'answer_cards.json')))
raise 'Producer framework mismatch' unless manifest.fetch('rails_version') == cards.fetch('framework')
home = File.realpath(ENV.fetch('GEM_HOME'))
%w[thistle thistle-map].each do |name|
  raise 'Checkout package used' unless File.realpath(Gem.loaded_specs.fetch(name).full_gem_path).start_with?(home + '/')
end
raise 'Woods runtime present' if Gem::Specification.find_all.any? { |spec| %w[woods woods-map].include?(spec.name) }
def demand(condition, message) = (raise message unless condition)
def pages(reader, id, **options)
  rows = []; cursor = nil; seen = []
  128.times do
    answer = reader.model_neighborhood(id, **options, limit: 2, cursor: cursor)
    demand(answer.fetch('generation') == reader.generation, 'Generation changed')
    demand(answer.dig('usage', 'wire_bytes_including_envelope_and_newline') == JSON.generate('ok' => true, 'result' => answer).bytesize + 1, 'Wire usage mismatch')
    rows.concat(answer.fetch('items'))
    yield answer if block_given?
    return rows if answer.dig('coverage', 'page_complete')
    next_cursor = answer.fetch('next_cursor')
    demand(next_cursor && next_cursor != cursor && !seen.include?(next_cursor), 'Continuation did not advance')
    seen << next_cursor; cursor = next_cursor
  end
  raise 'Fixture exceeded 128 finite steps'
end
def rack(app, path, params)
  status, headers, body = app.call('REQUEST_METHOD' => 'GET', 'PATH_INFO' => path, 'SCRIPT_NAME' => '/map',
    'QUERY_STRING' => URI.encode_www_form(params), 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1')
  demand(status == 200, "Rack #{path} refused: #{status}")
  [body.join, headers]
end
store = manifest.fetch('store'); generation = manifest.fetch('saved_a')
reader = Thistle::Reader.new(store, generation: generation)
begin
  root = reader.find('Order', limit: 500).find { |fact| fact['kind'] == 'rails_model' && fact['name'] == cards.fetch('root') }
  demand(root, 'Order saved runtime model missing')
  id = root.fetch('id')
  root_fact = reader.fact(id)
  associations = pages(reader, id, type: 'association')
  actual = associations.to_h { |row| [row.dig('association', 'name'), [row.fetch('relation'), row['target_label']]] }
  demand(actual == cards.fetch('associations'), 'Independent association cards differ')
  demand(associations.length > 8, 'No row continuation exercised')
  demand(associations.all? { |row| row.fetch('association') == root_fact.dig('attributes', 'model', 'associations', 'entries').fetch(row.dig('witness', 'ordinal')) }, 'Association witness differs from saved entry')
  ghost = associations.find { |row| row.dig('association', 'name') == 'ghosts' }
  demand(ghost.fetch('target_status') == 'missing_or_unloaded' && ghost['candidate_matches'].zero?, 'Unloaded target invented')
  subject = associations.find { |row| row.dig('association', 'name') == 'subject' }
  demand(subject['target_label'].nil? && subject['candidates'].empty?, 'Polymorphic target invented or dropped')
  user = associations.find { |row| row.dig('association', 'name') == 'user' }
  demand(user['candidate_matches'] > 4 && user['candidates'].length == 4, 'Global ambiguity or four-candidate bound lost')
  representations = pages(reader, id, family: 'candidates', candidate: user.fetch('candidate_selector'))
  demand(representations.length == user['candidate_matches'], 'Candidate continuation lost representations')
  demand(representations.map { |row| row.dig('identity', 'id') }.uniq.length == representations.length, 'Candidate repeated')
  demand(representations.count { |row| row.dig('identity', 'kind') == 'class' } >= cards.fetch('user_declaration_site_minimum'), 'Captured User declaration sites lost')
  demand(representations.count { |row| row.dig('identity', 'kind') == 'rails_model' } == cards.fetch('user_runtime_class_count'), 'Reopens counted as separate loaded classes')
  admin = associations.find { |row| row.dig('association', 'name') == 'admins' }
  demand(admin['candidates'].all? { |candidate| candidate['name'] == 'Admin::User' }, 'Namespace conflated')
  item = reader.find('Item', limit: 500).find { |fact| fact['kind'] == 'rails_model' && fact['name'] == 'Item' }
  demand(pages(reader, item.fetch('id'), type: 'association').any? { |row| row.dig('association', 'name') == 'order' && row['target_label'] == 'Order' }, 'Order-Item cycle missing')
  columns = pages(reader, id, family: 'columns').map { |row| row.fetch('column').reject { |key, _| %w[default_recorded default_presence].include?(key) } }
  demand(columns == manifest.fetch('raw_order_columns'), 'Stored raw defaults/types differ from independently read adapter metadata')
  source_ids = []; app = Thistle::Map::App.new(store: store)
  selection = [id, item.fetch('id')].join(',')
  %w[outgoing incoming].product(%w[all association reference]).each do |direction, type|
    native_rows = pages(reader, id, direction: direction, type: type)
    native_rows.each do |row|
      next if row['association']
      evidence = row.fetch('recorded')
      saved = reader.fact(row.dig('origin', 'id')).fetch('links').fetch(evidence.fetch('link_ordinal'))
      demand(saved == evidence.fetch('link') || evidence['detail_omitted'], 'Reference witness differs from original saved link')
    end
    cursor = nil; seen = []; displayed = []
    128.times do
      params = { 'generation' => generation, 'id' => id, 'selection' => selection, 'q' => 'Order', 'cursor' => cursor }.compact
      nav = Thistle::Map::NavigationContext.new(generation: generation, mount: '/map', params: params,
        selection: Thistle::Map::Investigation.from_params(params))
      limit = Thistle::Map::ModelNeighborhoodPresenter.page_limit(nav)
      answer = reader.model_neighborhood(id, direction: direction, type: type, cursor: cursor, limit: limit,
        max_bytes: Thistle::Map::ModelNeighborhoodPresenter.request_bytes(nav, limit))
      html, headers = rack(app, "/model-neighborhood/edges/#{direction}/#{type}", params)
      demand(html.bytesize <= 65536 && headers.fetch('content-security-policy').include?("default-src 'none'"), 'Display/CSP bound lost')
      list = html.scan(/data-neighborhood-edge="(\d+)"/).flatten
      diagram = html.scan(/data-neighborhood-diagram-edge="(\d+)"/).flatten
      demand(list == diagram && list.length == answer.fetch('items').length, 'Diagram/list/native selected rows differ')
      answer.fetch('items').each do |row|
        from = CGI.escapeHTML(row.dig('origin', 'name'))
        to = CGI.escapeHTML(row['target_label'] || 'Unknown / polymorphic target')
        demand(html.include?("#{from} → #{to}") && html.include?(CGI.escapeHTML(row.fetch('relation'))), 'Full names/edge type not revealed')
        displayed << row
      end
      html.scan(/href="([^"]+)"/).flatten.each do |href|
        uri = URI.parse(CGI.unescapeHTML(href))
        next unless uri.path == '/map/source' && uri.fragment&.match?(/\AL[1-9]\d*\z/)
        fields = URI.decode_www_form(uri.query).to_h
        demand(fields.values_at('generation', 'selection', 'q') == [generation, selection, 'Order'], 'Source context lost')
        source_html, = rack(app, '/source', fields)
        saved_source = reader.source(fields.fetch('id'))
        demand(source_html.include?(%(id="#{uri.fragment}")) && source_html.include?(saved_source.fetch('sha256')), 'Physical Source href did not reach exact saved A line/digest')
        source_ids << fields.fetch('id')
      end
      break if answer.dig('coverage', 'page_complete')
      next_cursor = answer.fetch('next_cursor')
      demand(next_cursor && next_cursor != cursor && !seen.include?(next_cursor), 'Map cursor stalled')
      seen << next_cursor; cursor = next_cursor
    end
    demand(displayed == native_rows, 'Map traversal differs from public Reader')
  end
  demand(!source_ids.empty?, 'No real physical Source href exercised')
  partial = Thistle::Reader.new(store, generation: manifest.fetch('partial'))
  begin
    demand(partial.model_neighborhood(id).dig('coverage', 'capture_partial_or_unknown'), 'Partial capture hidden')
  ensure
    partial.close
  end
  current = Thistle::Reader.new(store)
  begin
    demand(current.generation == manifest.fetch('current_b') && current.generation != generation, 'CURRENT did not advance')
  ensure
    current.close
  end
  report = reader.find('ReportBuilder#saved_marker', limit: 50).find { |fact| fact['kind'] == 'method' }
  demand(reader.source(report.fetch('id')).fetch('content').include?(cards.fetch('source_marker_a')), 'Pinned A source was replaced by CURRENT B')
  puts JSON.generate('result' => 'candidate_development_only', 'generation' => generation, 'association_rows' => associations.length,
    'saved_user_representations' => representations.length, 'physical_source_ids' => source_ids.uniq, 'served_person_checks' => 'UNRUN')
ensure
  reader.close
end
