# frozen_string_literal: true

# Runs from outside both source checkouts with an isolated GEM_HOME/GEM_PATH.
# Intentionally does not load test_helper or add a checkout to $LOAD_PATH.
require 'rubygems'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'digest'
require 'uri'
require 'cgi'
require 'thistle'
require 'thistle/map'

def stored_call_fields(reader, link)
  data = link.fetch('attributes').fetch('thistle_call')
  return data unless [2, 3].include?(reader.manifest['schema_version']) && data['version'] == 2
  kind, name, omitted, safe, call, receiver = data.fetch('data')
  location = ->(tuple) { tuple && Hash[%w[start_byte end_byte start_line end_line].zip(tuple)] }
  { 'receiver' => { 'kind' => kind, 'name' => name, 'omitted_limit' => omitted },
    'safe_navigation' => safe, 'call_location' => location.call(call), 'receiver_location' => location.call(receiver) }
end

gem_home = File.realpath(ENV.fetch('GEM_HOME'))
%w[thistle thistle-map rouge].each do |name|
  path = File.realpath(Gem.loaded_specs.fetch(name).full_gem_path)
  raise "#{name} loaded outside the isolated installation" unless path.start_with?(gem_home + File::SEPARATOR)
end
raise 'Woods is present in the isolated installation' if Gem::Specification.find_all.any? { |spec| %w[woods woods-map].include?(spec.name) }
project_features = $LOADED_FEATURES.select { |path| path.match?(%r{/(?:thistle\.rb|thistle/.*\.(?:rb|so|bundle|dll))\z}) }
raise 'A Thistle implementation file came from outside the isolated gems' unless project_features.all? do |path|
  File.realpath(path).start_with?(gem_home + File::SEPARATOR)
end

result = Dir.mktmpdir('thistle-map-installed-') do |directory|
  app_root = File.join(directory, 'app')
  store = File.join(directory, 'store')
  FileUtils.mkdir_p(app_root)
  File.write(File.join(app_root, 'bird.rb'), "class InstalledBird\n  def song = '<script>packaged</script>'\nend\n")
  manifest = Thistle.capture(root: app_root, output: store)
  reader = Thistle::Reader.new(store)
  fact = reader.find('InstalledBird', limit: 10).find { |row| row['kind'] == 'class' }
  raise 'Expected independently named fixture class missing' unless fact
  app = Thistle::Map::App.new(store: store)
  env = {
    'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/source', 'SCRIPT_NAME' => '',
    'QUERY_STRING' => URI.encode_www_form('id' => fact.fetch('id'), 'generation' => manifest.fetch('generation')),
    'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1', 'rack.url_scheme' => 'http'
  }
  status, headers, body = app.call(env)
  html = body.each.to_a.join
  raise "Source view returned #{status}" unless status == 200
  raise 'Expected source text missing' unless html.include?('packaged') && html.include?('InstalledBird')
  raise 'Captured markup was not escaped' if html.include?('<script>packaged</script>')
  raise 'Source generation was not carried through UI links' unless html.include?("generation=#{reader.generation}")
  raise 'CSP absent' unless headers['content-security-policy'].include?("frame-ancestors 'none'")
  raise 'Read-only method gate missing' unless app.call(env.merge('REQUEST_METHOD' => 'POST')).first == 405
  # Construct runtime-only evidence independently of the Rails observer, then
  # publish it through the installed native store alongside the static capture.
  capture = Thistle::Capture.new(root: app_root).call
  runtime_id = Digest::SHA256.hexdigest('installed-runtime-route')
  capture.fetch('facts') << {
    'id' => runtime_id, 'kind' => 'route', 'name' => 'GET /installed-runtime',
    'path' => nil, 'location' => nil, 'evidence' => 'runtime',
    'attributes' => { 'source_status' => 'unavailable', 'coherence' => 'unknown' }, 'links' => []
  }
  runtime_manifest = Thistle::Store.new(store).publish(capture)
  runtime_reader = Thistle::Reader.new(store, generation: runtime_manifest.fetch('generation'))
  begin
    runtime_reader.source(runtime_id)
    raise 'Runtime fact unexpectedly has source'
  rescue Thistle::Error => error
    raise unless error.code == 'source_unavailable'
  end
  runtime_query = URI.encode_www_form('id' => runtime_id, 'generation' => runtime_reader.generation)
  runtime_status, _, runtime_body = app.call(env.merge('QUERY_STRING' => runtime_query))
  runtime_html = runtime_body.each.to_a.join
  raise "Runtime Source returned #{runtime_status}" unless runtime_status == 200
  raise 'Runtime evidence context missing' unless runtime_html.include?('GET /installed-runtime') && runtime_html.include?('runtime') && runtime_html.include?('No file or line was captured')
  raise 'Runtime navigation lost generation' unless runtime_html.include?("generation=#{runtime_reader.generation}") && runtime_html.include?('/links?') && runtime_html.include?('/check?')
  # This contract is deliberately separate from the frozen evaluator: it checks
  # the installed packages' call metadata and same-generation provenance.
  call_source = "class InstalledParcel\n  def note = <<~TEXT\n    \#{self.render}\n  TEXT\nend\n"
  call_path = File.join(app_root, 'parcel.rb')
  File.write(call_path, call_source)
  first_call = Thistle.capture(root: app_root, output: store)
  call_reader = Thistle::Reader.new(store, generation: first_call.fetch('generation'))
  call_fact = call_reader.find('InstalledParcel#note', limit: 10).find { |item| item['name'] == 'InstalledParcel#note' }
  raise 'Installed Find did not return the heredoc owner' unless call_fact
  call = call_reader.links(call_fact.fetch('id')).find { |link| link['relation'] == 'calls' && link['target'] == 'render' }
  raise 'Installed schema 3 capture did not retain compact-v2 semantic metadata' unless call &&
    call_reader.manifest['schema_version'] == 3 && call.dig('attributes', 'thistle_call', 'version') == 2
  data = stored_call_fields(call_reader, call)
  raise 'Installed self receiver was not preserved' unless call && call['resolution'] == 'unresolved' &&
    data && data.dig('receiver', 'kind') == 'self' && data['safe_navigation'] == false
  location = data.fetch('call_location')
  raise 'Heredoc parser anchor is not the expected call on line 3' unless location['start_line'] == 3 &&
    call_source.b.byteslice(location['start_byte']...location['end_byte']) == 'self.render' &&
    location['start_line'] > call_fact.fetch('location').fetch('end_line')
  call_query = URI.encode_www_form('id' => call_fact.fetch('id'), 'generation' => call_reader.generation)
  call_status, _, call_body = app.call(env.merge('PATH_INFO' => '/links', 'QUERY_STRING' => call_query))
  call_html = call_body.each.to_a.join
  raise 'Installed Links did not show the heredoc self receiver' unless call_status == 200 && call_html.include?('<br>self ·') && call_html.include?('Representative source')
  href = call_html[/href="([^"]+#L3)"/, 1]
  raise 'Installed Links omitted the heredoc source anchor' unless href
  source_uri = URI.parse(href.gsub('&amp;', '&'))
  raise 'Installed source anchor is not pinned to the original generation' unless source_uri.path == '/source' &&
    URI.decode_www_form(source_uri.query).to_h['generation'] == call_reader.generation && source_uri.fragment == 'L3'
  File.write(call_path, call_source.sub('self.render', 'self.changed'))
  Thistle.capture(root: app_root, output: store)
  latest_reader = Thistle::Reader.new(store)
  raise 'Second capture did not create a new generation' if latest_reader.generation == call_reader.generation
  pinned_status, _, pinned_body = app.call(env.merge('PATH_INFO' => source_uri.path, 'QUERY_STRING' => source_uri.query))
  pinned_html = pinned_body.each.to_a.join
  raise 'Pinned installed Source lost the original anchor' unless pinned_status == 200 && pinned_html.include?('id="L3"') && pinned_html.include?(call_reader.generation)
  raise 'Pinned installed Source bytes changed' unless call_reader.source(call_fact.fetch('id')).fetch('content') == call_source
  raise 'Pinned installed Check failed' unless call_reader.check.fetch('integrity') == 'verified'

  # The separate installed producer has exited; this fresh consumer has neither
  # Rails nor its model fixture loaded and cannot derive answers from live state.
  raise 'Model consumer loaded Rails' if defined?(Rails) || defined?(ModelFixture)
  model_store, model_receipt = ARGV
  raise 'Installed model producer receipt missing' unless model_store && model_receipt
  produced = JSON.parse(File.read(model_receipt))
  model_generation = produced.fetch('generation')
  raise 'Unexpected model observation cohort' unless produced['active_record_version'] == '8.1.4'
  Thistle.capture(root: app_root, output: model_store)
  model_reader = Thistle::Reader.new(model_store, generation: model_generation)
  models = model_reader.facts.select { |row| row['kind'] == 'rails_model' }
  by_name = models.to_h { |row| [row['name'], row] }
  order = by_name.fetch('ModelFixture::Order')
  model = order.fetch('attributes').fetch('model')
  raise 'Model identity or schema labels changed' unless model['table'] == 'orders' && model['primary_key'] == ['id'] &&
    model['source'] == 'unavailable' && model['coherence'] == 'unknown' && order['path'].nil? && order['location'].nil?
  sti = by_name.fetch('ModelFixture::PriorityOrder').fetch('attributes').fetch('model')
  raise 'STI labels changed' unless sti['base_class'] == 'ModelFixture::Order' && sti['inheritance_column'] == 'type'
  state = model.fetch('columns').fetch('entries').find { |column| column['name'] == 'state' }
  raise 'Raw schema default/nullability changed' unless state && state['type'] == 'string' && state['null'] == false &&
    state['default'] == { 'kind' => 'literal', 'value' => 'new' }
  associations = model.fetch('associations').fetch('entries').to_h { |row| [row.fetch('name'), row] }
  raise 'Association cardinality/labels changed' unless associations.keys.sort == %w[items payments products] &&
    associations['items']['target'] == 'ModelFixture::Item' && associations['payments']['target'] == 'ModelFixture::Payment' &&
    associations['items']['scope'] == 'opaque' && associations['products']['through'] == 'items' && associations['products']['target'].nil?
  payment = by_name.fetch('ModelFixture::Payment').dig('attributes', 'model', 'associations', 'entries').find { |row| row['name'] == 'subject' }
  missing = by_name.fetch('ModelFixture::MissingTable').dig('attributes', 'model')
  raise 'Unavailable/unknown families changed' unless payment['polymorphic'] == true && payment['target'].nil? &&
    missing.dig('columns', 'status') == 'unavailable' && missing.dig('associations', 'status') == 'observed'
  model_links = model_reader.links(order.fetch('id'))
  raise 'Model labels became bindings or lost identity' unless model_links.all? { |link| link['resolution'] == 'unresolved' } &&
    model_links.filter_map { |link| link.dig('attributes', 'association') }.sort == %w[items payments]
  begin
    model_reader.source(order.fetch('id'))
    raise 'Model source was fabricated'
  rescue Thistle::Error => error
    raise unless error.code == 'source_unavailable'
  end
  static = model_reader.facts.find { |row| row['kind'] == 'class' && row['name'] == 'ModelFixture::Order' }
  raise 'Separate captured source missing' unless static &&
    model_reader.source(static.fetch('id')).fetch('sha256') == produced.fetch('fixture_source_sha256')
  model_check = model_reader.check
  raise 'Model coverage/integrity changed' unless model_check['integrity'] == 'verified' &&
    model_check.fetch('coverage').find { |row| row['family'] == 'rails_models' }&.fetch('status') == 'partial'
  model_app = Thistle::Map::App.new(store: model_store)
  model_query = URI.encode_www_form('id' => order.fetch('id'), 'generation' => model_generation)
  %w[/source /links].each do |path|
    status, _, body = model_app.call(env.merge('PATH_INFO' => path, 'QUERY_STRING' => model_query))
    html = body.each.to_a.join
    raise "Installed model #{path} lost evidence" unless status == 200 && html.include?(model_generation) &&
      html.include?('ModelFixture::Order') && html.include?('items') && html.include?('payments') && html.include?('unknown')
  end

  # Use the saved real-model observation in this fresh consumer. Older selected
  # packages retain their original contract; new Readers must prove references.
  references_journey = nil
  if model_reader.respond_to?(:references)
    item = by_name.fetch('ModelFixture::Item')
    item_evidence = model_reader.find('ModelFixture::Item').select { |row| row['name'] == 'ModelFixture::Item' }
    static_item = item_evidence.find { |row| row['kind'] == 'class' }
    callback_item = item_evidence.find { |row| row['kind'] == 'rails_save_callbacks' }
    raise 'Captured Item or registered-callback identity missing' unless static_item && callback_item
    outgoing = model_reader.references(order.fetch('id'))
    association = outgoing.fetch('relationships').find { |row| row.dig('link', 'attributes', 'association') == 'items' }
    raise "Installed outgoing references lost ambiguity: #{association&.slice('candidate_label', 'candidate_matches', 'match_basis', 'candidate_search_complete')}" unless association &&
      outgoing.fetch('generation') == model_generation && association['candidate_label'] == 'ModelFixture::Item' &&
      association['match_basis'] == 'recorded_outgoing_binding_unknown' && association['candidate_search_complete'] &&
      association.fetch('candidate_matches') == 3 &&
      association.fetch('candidates').map { |row| row.fetch('id') }.sort == [item.fetch('id'), static_item.fetch('id'), callback_item.fetch('id')].sort
    incoming = model_reader.references(item.fetch('id'), direction: 'incoming')
    raise 'Installed incoming references lost the registered association' unless incoming.fetch('generation') == model_generation &&
      incoming.fetch('relationships').any? { |row| row.dig('origin', 'id') == order.fetch('id') &&
        row.dig('link', 'attributes', 'association') == 'items' && row['match_basis'] == 'label_match_binding_unknown' }
    status, _, body = model_app.call(env.merge('PATH_INFO' => '/links', 'QUERY_STRING' => model_query))
    reference_html = body.each.to_a.join
    raise 'Installed reference display lost uncertainty' unless status == 200 && reference_html.include?('binding unknown') &&
      reference_html.include?('3 known name-match candidates') && reference_html.include?('No captured source')
    source_uri = reference_html.scan(/href="([^"]+)"/).flatten.map { |href| URI.parse(CGI.unescapeHTML(href)) }.find do |uri|
      params = URI.decode_www_form(uri.query.to_s).to_h
      uri.path == '/source' && params['id'] == static_item.fetch('id') && params['generation'] == model_generation
    end
    raise 'Installed candidate Source link missing or unpinned' unless source_uri
    source_status, _, body = model_app.call(env.merge('PATH_INFO' => source_uri.path, 'QUERY_STRING' => source_uri.query))
    source_html = body.each.to_a.join
    raise 'Installed reference Source changed captured evidence' unless source_status == 200 && source_html.include?(model_generation) &&
      model_reader.source(static_item.fetch('id')).fetch('sha256') == produced.fetch('fixture_source_sha256')
    incoming_query = URI.encode_www_form('id' => item.fetch('id'), 'generation' => model_generation, 'direction' => 'incoming')
    incoming_status, _, body = model_app.call(env.merge('PATH_INFO' => '/links', 'QUERY_STRING' => incoming_query))
    incoming_html = body.each.to_a.join
    raise 'Installed incoming Map view failed' unless incoming_status == 200 && incoming_html.include?('ModelFixture::Order') &&
      incoming_html.include?('binding unknown') && incoming_html.include?(model_generation) &&
      incoming_html.include?('Additional candidates not searched') &&
      incoming_html.include?('Detailed fact evidence was not loaded') && !incoming_html.include?('unknown format')
    limited = model_reader.references(order.fetch('id'), limit: 1)
    raise 'Installed reference omission was confused with unsearched input' unless
      limited.dig('coverage', 'known_matches') == 2 && limited.dig('coverage', 'known_omitted') == 1 &&
      limited.dig('coverage', 'not_searched') == false && limited.dig('coverage', 'capture_partial') == true &&
      limited.dig('coverage', 'budgets', 'facts') == 20_000
    limited_html = Thistle::Map::ReferencesPresenter.new(generation: model_generation, mount: '').render(limited)
    raise 'Installed reference omission display lost its scope' unless limited_html.include?('1 known omitted') &&
      limited_html.include?('Relationship scan complete within this capture') && limited_html.include?('Capture partial')
    method_fact = model_reader.find('business_method').find { |row| row['kind'] == 'method' }
    raise 'Installed no-match fixture method missing' unless method_fact
    empty = model_reader.references(method_fact.fetch('id'), direction: 'incoming')
    raise 'Installed no-match result lost searched/capture scope' unless empty.fetch('relationships').empty? &&
      empty.dig('coverage', 'scan_complete') && empty.dig('coverage', 'capture_partial') && !empty.dig('coverage', 'not_searched')
    empty_query = URI.encode_www_form('id' => method_fact.fetch('id'), 'generation' => model_generation, 'direction' => 'incoming')
    empty_status, _, body = model_app.call(env.merge('PATH_INFO' => '/links', 'QUERY_STRING' => empty_query))
    empty_html = body.each.to_a.join
    raise 'Installed no-match display overclaimed absence' unless empty_status == 200 &&
      empty_html.include?('No matching recorded relationships found in the searched evidence') &&
      empty_html.include?('This does not establish that the model has no references') && empty_html.include?('Capture partial')
    references_journey = { 'generation' => model_generation, 'outgoing' => outgoing, 'incoming' => incoming,
      'limited' => limited, 'no_match' => empty, 'no_match_status' => empty_status,
      'static_source_id' => static_item.fetch('id'), 'source_sha256' => produced.fetch('fixture_source_sha256'),
      'source_status' => source_status, 'incoming_status' => incoming_status,
      'current_advanced' => true, 'fresh_consumer_without_rails' => true }
  end

  # Inspect this exact installed package, without a checkout or a live-app scan.
  packaged_root = File.join(Gem.loaded_specs.fetch('thistle').full_gem_path, 'lib')
  packaged_path = 'thistle/reader.rb'
  packaged_bytes = File.binread(File.join(packaged_root, packaged_path)).force_encoding(Encoding::UTF_8)
  literal = 'def source_file(path)'
  # Find spans count original bytes, including any preceding non-ASCII text.
  expected_byte = packaged_bytes.b.index(literal.b)
  raise 'Packaged Reader known answer missing' unless expected_byte
  expected_line = packaged_bytes.b.byteslice(0, expected_byte).count("\n") + 1
  find_store = File.join(directory, 'find-store')
  find_manifest = Thistle.capture(root: packaged_root, output: find_store)
  find_generation = find_manifest.fetch('generation')
  # Advance CURRENT before opening the fresh pinned consumer.
  Thistle.capture(root: app_root, output: find_store)
  find_reader = Thistle::Reader.new(find_store, generation: find_generation)
  found = find_reader.search_evidence(literal, domain: 'source', kind: 'file', path: packaged_path)
  raise 'Installed Find is not complete for the packaged Reader' unless found['status'] == 'complete' && found['total_matches'] == 1
  hit = found.fetch('results').fetch(0)
  raise 'Installed Find invented a declaration owner' unless hit['origin'] == 'source' && hit['fact_id'].nil? && hit['path'] == packaged_path
  raise 'Installed Find span changed original bytes' unless hit['span'] == {
    'start_byte' => expected_byte, 'end_byte' => expected_byte + literal.bytesize,
    'start_line' => expected_line, 'end_line' => expected_line }
  raise 'Installed file Source bytes changed' unless find_reader.source_file(packaged_path).fetch('content') == packaged_bytes
  find_app = Thistle::Map::App.new(store: find_store)
  find_context = { 'q' => literal, 'domain' => 'source', 'kind' => 'file', 'prefix' => packaged_path }
  find_status, _, find_body = find_app.call(env.merge('PATH_INFO' => '/',
    'QUERY_STRING' => URI.encode_www_form(find_context.merge('generation' => find_generation))))
  find_html = find_body.each.to_a.join
  raise 'Installed Map Find failed' unless find_status == 200
  find_uri = URI.parse(CGI.unescapeHTML(find_html[/data-result-link href="([^"]+)"/, 1].to_s))
  find_params = URI.decode_www_form(find_uri.query.to_s).to_h
  raise 'Installed Find context or generation lost' unless find_params.slice(*find_context.keys) == find_context && find_params['generation'] == find_generation
  file_status, _, file_body = find_app.call(env.merge('PATH_INFO' => find_uri.path, 'QUERY_STRING' => find_uri.query))
  file_html = file_body.each.to_a.join
  raise 'Installed pinned file Source failed' unless file_status == 200 && find_uri.fragment == "L#{expected_line}" &&
    file_html.include?("id=\"L#{expected_line}\"") && file_html.include?(find_generation) && file_html.include?('No declaration owner')
  raise 'Packaged Find Check failed' unless find_reader.check.fetch('integrity') == 'verified'

  native = $LOADED_FEATURES.find { |path| path.match?(%r{/thistle/thistle_native\.(so|bundle|dll)\z}) }
  raise 'Installed native engine was not loaded' unless native && File.realpath(native).start_with?(gem_home + File::SEPARATOR)
  raise 'Woods source was loaded' if $LOADED_FEATURES.any? { |path| path.match?(%r{/(woods|woods_map)/}) }
  {
    'status' => 'passed', 'ruby' => RUBY_DESCRIPTION,
    'core_version' => Thistle::VERSION, 'map_version' => Thistle::Map::VERSION,
    'rouge_version' => Rouge.version, 'generation' => manifest.fetch('generation'),
    'core_gem' => Gem.loaded_specs.fetch('thistle').full_gem_path,
    'map_gem' => Gem.loaded_specs.fetch('thistle-map').full_gem_path,
    'native_sha256' => Digest::SHA256.file(native).hexdigest,
    'model_journey' => { 'generation' => model_generation, 'model_id' => order.fetch('id'),
      'model_count' => models.length, 'associations' => associations.keys.sort,
      'fixture_source_sha256' => produced.fetch('fixture_source_sha256'),
      'current_advanced' => true, 'fresh_consumer_without_rails' => true },
    'find_journey' => { 'generation' => find_generation, 'path' => packaged_path,
      'span' => hit.fetch('span'), 'source_sha256' => Digest::SHA256.hexdigest(packaged_bytes),
      'status' => found.fetch('status'), 'map_source_status' => file_status, 'current_advanced' => true },
    'references_journey' => references_journey,
    'woods_installed' => false, 'source_checkout_load_path' => false
  }
ensure
  model_reader&.close
  find_reader&.close
  latest_reader&.close
  call_reader&.close
  runtime_reader&.close
  reader&.close
end
puts JSON.pretty_generate(result)
