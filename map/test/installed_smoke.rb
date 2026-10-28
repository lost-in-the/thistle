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
  runtime_reader.close
  native = $LOADED_FEATURES.find { |path| path.match?(%r{/thistle/thistle_native\.(so|bundle|dll)\z}) }
  raise 'Installed native engine was not loaded' unless native && File.realpath(native).start_with?(gem_home + File::SEPARATOR)
  raise 'Woods source was loaded' if $LOADED_FEATURES.any? { |path| path.match?(%r{/(woods|woods_map)/}) }
  reader.close
  {
    'status' => 'passed', 'ruby' => RUBY_DESCRIPTION,
    'core_version' => Thistle::VERSION, 'map_version' => Thistle::Map::VERSION,
    'rouge_version' => Rouge.version, 'generation' => manifest.fetch('generation'),
    'core_gem' => Gem.loaded_specs.fetch('thistle').full_gem_path,
    'map_gem' => Gem.loaded_specs.fetch('thistle-map').full_gem_path,
    'native_sha256' => Digest::SHA256.file(native).hexdigest,
    'woods_installed' => false, 'source_checkout_load_path' => false
  }
end
puts JSON.pretty_generate(result)
