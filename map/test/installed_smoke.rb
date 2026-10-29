# frozen_string_literal: true

# Runs from outside both source checkouts with an isolated GEM_HOME/GEM_PATH.
# Intentionally does not load test_helper or add a checkout to $LOAD_PATH.
require 'rubygems'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'digest'
require 'uri'
require 'thistle'
require 'thistle/map'

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
  # the installed packages' v1 call metadata and same-generation provenance.
  call_source = "class InstalledParcel\n  def note = <<~TEXT\n    \#{self.render}\n  TEXT\nend\n"
  call_path = File.join(app_root, 'parcel.rb')
  File.write(call_path, call_source)
  first_call = Thistle.capture(root: app_root, output: store)
  call_reader = Thistle::Reader.new(store, generation: first_call.fetch('generation'))
  call_fact = call_reader.find('InstalledParcel#note', limit: 10).find { |item| item['name'] == 'InstalledParcel#note' }
  raise 'Installed Find did not return the heredoc owner' unless call_fact
  call = call_reader.links(call_fact.fetch('id')).find { |link| link['relation'] == 'calls' && link['target'] == 'render' }
  data = call && call.dig('attributes', 'thistle_call')
  raise 'Installed v1 self receiver was not preserved' unless call && call['resolution'] == 'unresolved' &&
    data && data['version'] == 1 && data.dig('receiver', 'kind') == 'self' && data['safe_navigation'] == false
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
    'woods_installed' => false, 'source_checkout_load_path' => false
  }
ensure
  latest_reader&.close
  call_reader&.close
  runtime_reader&.close
  reader&.close
end
puts JSON.pretty_generate(result)
