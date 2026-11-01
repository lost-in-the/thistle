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
def known_rows(reader, rows, expected)
  demand(!rows.empty? && !expected.empty?, 'Known-answer domain must not be empty')
  expected.map do |card|
    matches = rows.select do |row|
      origin = row.fetch('origin')
      origin['name'] == card.fetch('origin_name') && origin['kind'] == card.fetch('origin_kind') &&
        row['relation'] == card.fetch('relation') && row['target_label'] == card.fetch('target_label') &&
        (!card.key?('link_ordinal') || row.dig('recorded', 'link_ordinal') == card.fetch('link_ordinal'))
    end
    demand(matches.length == 1, "Missing/ambiguous independent witness #{card.fetch('origin_name')}")
    origin = matches.fetch(0).fetch('origin')
    if card['path']
      demand(origin['path'] == card.fetch('path') && origin.dig('location', 'start_line') == card.fetch('start_line'), 'Independent physical Source witness differs')
      demand(reader.source(origin.fetch('id')).fetch('content').lines.fetch(card.fetch('start_line') - 1).include?(card.fetch('source_contains')), 'Saved A line differs from independent Source card')
    end
    origin.fetch('id')
  end
end
store = manifest.fetch('store'); generation = manifest.fetch('saved_a')
reader = Thistle::Reader.new(store, generation: generation)
begin
  root = reader.find('Order', limit: 500).find { |fact| fact['kind'] == 'rails_model' && fact['name'] == cards.fetch('root') }
  demand(root, 'Order saved runtime model missing')
  id = root.fetch('id'); root_fact = reader.fact(id)
  associations = pages(reader, id, type: 'association')
  actual = associations.to_h { |row| [row.dig('association', 'name'), [row.fetch('relation'), row['target_label']]] }
  demand(actual == cards.fetch('associations'), 'Independent association cards differ')
  demand(associations.length > 8, 'No row continuation exercised')
  demand(associations.all? { |row| row['origin_id'] == id && !row.key?('origin') &&
    row.fetch('association') == root_fact.dig('attributes', 'model', 'associations', 'entries').fetch(row.dig('witness', 'ordinal')) }, 'Association witness differs from saved entry')
  ghost = associations.find { |row| row.dig('association', 'name') == 'ghosts' }
  demand(ghost.fetch('target_status') == 'missing_or_unloaded' && ghost['candidate_matches'].zero?, 'Unloaded target invented')
  subject = associations.find { |row| row.dig('association', 'name') == 'subject' }
  demand(subject['target_label'].nil? && subject['candidates'].empty?, 'Polymorphic target invented or dropped')
  user = associations.find { |row| row.dig('association', 'name') == 'user' }
  demand(user['candidate_matches'] > 4 && user['candidates'].length == 4, 'Global ambiguity or four-candidate bound lost')
  representations = pages(reader, id, family: 'candidates', candidate: user.fetch('candidate_selector'))
  demand(representations.length == user['candidate_matches'], 'Candidate continuation lost representations')
  ids = representations.map { |row| row.dig('identity', 'id') }
  demand(ids.uniq.length == ids.length, 'Candidate repeated')
  demand(representations.count { |row| row.dig('identity', 'kind') == 'class' } >= cards.fetch('user_declaration_site_minimum'), 'Captured User declaration sites lost')
  demand(representations.count { |row| row.dig('identity', 'kind') == 'rails_model' } == cards.fetch('user_runtime_class_count'), 'Reopens counted as separate loaded classes')
  admin = associations.find { |row| row.dig('association', 'name') == 'admins' }
  admin_representations = pages(reader, id, family: 'candidates', candidate: admin.fetch('candidate_selector'))
  admin_card = cards.fetch('admin_target')
  demand(admin_representations.length >= admin_card.fetch('minimum_representations'), 'Admin candidates unexpectedly empty')
  demand(admin_representations.all? { |row| row.dig('identity', 'name') == admin_card.fetch('name') }, 'Namespace conflated')
  demand(admin_representations.count { |row| row.dig('identity', 'kind') == 'rails_model' } == admin_card.fetch('rails_model_count'), 'Expected exactly one saved Admin::User runtime model')
  rooted_card = cards.fetch('rooted_target')
  rooted = associations.find { |row| row.dig('association', 'name') == rooted_card.fetch('association') }
  demand(rooted['target_label'] == rooted_card.fetch('display') && rooted['candidate_matches'] == user['candidate_matches'], 'Root marker changed display or candidate matching')
  rooted_representations = pages(reader, id, family: 'candidates', candidate: rooted.fetch('candidate_selector')) do |answer|
    demand(answer.dig('candidate_context', 'name') == rooted_card.fetch('association') &&
      answer.dig('candidate_context', 'target_label') == rooted_card.fetch('display'), 'Candidate page lost named original target')
  end
  demand(rooted_representations.map { |row| row.dig('identity', 'id') }.sort == ids.sort, 'Leading-root candidate range differs')
  ordinal = root_fact.fetch('links').index { |link| link['relation'] == 'association_target_label' && link.dig('attributes', 'association') == 'reviewers' }
  demand(!ordinal.nil?, 'Rooted original association link missing')
  public_rows = reader.references(id, direction: 'outgoing').fetch('relationships')
  public_row = public_rows.find { |row| row['link_ordinal'] == ordinal }
  demand(public_row['candidate_label'] == rooted_card.fetch('display') && public_row['candidate_matches'] == ids.length, 'Public references rooted lookup differs')
  item = reader.find('Item', limit: 500).find { |fact| fact['kind'] == 'rails_model' && fact['name'] == 'Item' }
  demand(pages(reader, item.fetch('id'), type: 'association').any? { |row| row.dig('association', 'name') == 'order' && row['target_label'] == 'Order' }, 'Order-Item cycle missing')
  columns = pages(reader, id, family: 'columns').map { |row| row.fetch('column') }
  demand(columns == manifest.fetch('raw_order_columns'), 'Stored raw defaults/types differ from independent post-A adapter oracle')
  # These independent cards require real, nonempty incoming/outgoing domains.
  incoming_associations = pages(reader, id, direction: 'incoming', type: 'association')
  known_rows(reader, incoming_associations, cards.fetch('incoming_associations'))
  incoming_references = pages(reader, id, direction: 'incoming', type: 'reference')
  required_source_ids = known_rows(reader, incoming_references, cards.fetch('incoming_references'))
  outgoing_references = pages(reader, id, type: 'reference')
  known_rows(reader, outgoing_references, cards.fetch('outgoing_references'))
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
    cursor = nil; seen = []; displayed = []; finished = false
    128.times do
      params = { 'generation' => generation, 'id' => id, 'selection' => selection, 'q' => 'Order', 'cursor' => cursor }.compact
      nav = Thistle::Map::NavigationContext.new(generation: generation, mount: '/map', params: params,
        selection: Thistle::Map::Investigation.from_params(params))
      limit, max_bytes = Thistle::Map::ModelNeighborhoodPresenter.admission(nav, family: 'edges', direction: direction)
      answer = reader.model_neighborhood(id, direction: direction, type: type, cursor: cursor, limit: limit, max_bytes: max_bytes)
      html, headers = rack(app, "/model-neighborhood/edges/#{direction}/#{type}", params)
      demand(html.bytesize <= 65536 && headers.fetch('content-security-policy').include?("default-src 'none'"), 'Display/CSP bound lost')
      demand(html.include?("Showing: #{direction.capitalize}"), 'Active direction not visible')
      list = html.scan(/data-neighborhood-edge="(\d+)"/).flatten
      diagram = html.scan(/data-neighborhood-diagram-edge="(\d+)"/).flatten
      demand(list.length == answer.fetch('items').length, 'HTML/native selected rows differ')
      demand(diagram == list || diagram.empty? && html.include?('The full named list contains every selected edge'), 'Diagram pruned independently of the named list')
      answer.fetch('items').each_with_index do |row, index|
        origin = row['association'] ? answer.fetch('root') : row.fetch('origin')
        segment = html.match(/<li id="mn-edge-#{index}".*?(?=<li id="mn-edge-|<\/ol>)/m)&.to_s
        demand(segment, 'Named edge segment missing')
        visible = CGI.unescapeHTML(segment.gsub(/<[^>]*>/, ''))
        demand([origin.fetch('name'), row['target_label'] || 'Unknown / polymorphic target', row.fetch('relation'), row.fetch('direction'), row.fetch('type')].all? { |text| visible.include?(text) }, 'Full names/type/direction not revealed')
        if !diagram.empty?
          svg = html.match(/<g data-neighborhood-diagram-edge="#{index}">.*?<\/g>/m)&.to_s
          demand(svg && [origin.fetch('name'), row['target_label'] || 'Unknown / polymorphic target', row.fetch('relation')].all? { |text| CGI.unescapeHTML(svg).include?(text) }, 'Diagram edge differs from the named list')
        end
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
      if answer.dig('coverage', 'page_complete')
        finished = true; break
      end
      next_cursor = answer.fetch('next_cursor')
      demand(next_cursor && next_cursor != cursor && !seen.include?(next_cursor), 'Map cursor stalled')
      seen << next_cursor; cursor = next_cursor
    end
    demand(finished && displayed == native_rows, 'Map traversal differs from public Reader or did not finish')
  end
  demand((required_source_ids - source_ids).empty?, 'Independent ReportBuilder physical Source hrefs were not followed')
  selected24 = manifest.fetch('selection_24')
  demand(selected24.length == 24 && selected24.uniq.length == 24, 'Real fixture lacks 24 saved IDs')
  context = { 'generation' => generation, 'id' => id, 'selection' => selected24.join(','), 'q' => 'q' * 256 }
  [['edges', nil], ['columns', nil], ['database', nil], ['candidates', user.fetch('candidate_selector')]].each do |family, candidate|
    html, = rack(app, "/model-neighborhood/#{family}/outgoing/all", context.merge('candidate' => candidate).compact)
    demand(html.include?('name="selection" value="' + selected24.join(',') + '"') && html.include?('name="q" value="' + 'q' * 256 + '"'), '24-ID/256q context lost')
    demand(html.bytesize <= 65536, '24-ID complete display overflow')
  end
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
    'known_incoming_associations' => cards.fetch('incoming_associations').length, 'known_incoming_references' => cards.fetch('incoming_references').length,
    'saved_user_representations' => representations.length, 'physical_source_ids' => source_ids.uniq, 'served_person_checks' => 'UNRUN')
ensure
  reader.close
end
