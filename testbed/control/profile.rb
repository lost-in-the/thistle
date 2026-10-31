# frozen_string_literal: true

# Fixed admitted homes are established before any default/dependency require.
# No Bundler setup, repository load path or inherited Ruby option participates.
ENV['GEM_HOME'] = '/work/gems'
ENV['GEM_PATH'] = '/work/gems:/dependencies'
Gem.clear_paths

require 'json'
require 'digest'
require 'fileutils'
require 'rbconfig'

module HostProfile
  module_function

  def config = @config ||= JSON.parse(File.read('/input/profile.json'))

  def activate(consumer: false)
    raise 'Ruby cohort drift' unless RUBY_VERSION == config.fetch('ruby')
    raise 'Ruby ABI/platform drift' unless RbConfig::CONFIG.fetch('ruby_version') == '3.4.0' && RUBY_PLATFORM.start_with?('x86_64-linux')
    ENV['GEM_HOME'] = '/work/gems'
    ENV['GEM_PATH'] = ['/work/gems', config.fetch('dependency_home')].join(':')
    Gem.clear_paths
    versions = { 'rack' => '3.2.7', 'rouge' => '4.6.1' }
    if consumer
      versions.merge!('thistle' => '0.1.0.pre.3', 'thistle-map' => '0.1.0.pre.3')
    else
      versions.merge!('bundler' => '2.6.9', 'railties' => '7.1.6', 'activerecord' => '7.1.6',
        'actionpack' => '7.1.6', 'minitest' => '5.25.4', 'mysql2' => '0.5.7')
    end
    versions.each { |name, version| gem name, "= #{version}" }
  end

  def write(path, object)
    data = JSON.pretty_generate(object)
    raise 'Receipt output budget' if data.bytesize > 8 * 1024 * 1024
    temporary = "#{path}.#{Process.pid}.#{Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)}.tmp"
    File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(data); f.flush; f.fsync }
    File.link(temporary, path) # exclusive atomic publication; never overwrite evidence
    File.unlink(temporary)
  end

  def file_identity(path)
    raise 'Identity needs an actual absolute file' unless path.start_with?('/') && File.file?(path)
    { 'path' => File.realpath(path), 'sha256' => Digest::SHA256.file(path).hexdigest, 'size' => File.size(path) }
  end

  def framework_free!
    raise 'Consumer loaded framework' if defined?(Rails) || defined?(ActiveRecord) || defined?(ActiveSupport) ||
      %w[railties activerecord actionpack activesupport].any? { |name| Gem.loaded_specs.key?(name) }
  end

  def admitted_gem_root?(path) = path.start_with?('/work/gems/', '/dependencies/')

  def verify_spec!(name, spec, locked, providers)
    if spec.default_gem?
      expected = providers.fetch('specs').fetch(name)
      raise 'Default provider spec drift' unless expected.fetch('version') == spec.version.to_s &&
        expected.fetch('gemspec_path') == File.realpath(spec.loaded_from) &&
        expected.fetch('gemspec_sha256') == Digest::SHA256.file(spec.loaded_from).hexdigest
      raise 'Default provider lock drift' if locked.key?(name) && locked[name] != spec.version.to_s
    else
      raise 'Nondefault gem provider escaped admitted homes' unless admitted_gem_root?(File.realpath(spec.full_gem_path))
      raise 'Loaded resolution not in supplied cohort lock' unless locked[name] == spec.version.to_s
    end
  end

  def client_auth_identity(mapped_paths)
    expected = config.fetch('client_auth')
    path = expected.fetch('path')
    raise 'Client auth directory drift' unless path == '/input/client-auth/caching_sha2_password.so' &&
      ENV['MARIADB_PLUGIN_DIR'] == '/input/client-auth'
    actual = file_identity(path)
    raise 'Client auth provider drift' unless actual.slice('sha256', 'size') == expected.slice('sha256', 'size')
    raise 'Unadmitted client auth mapping' unless mapped_paths.empty? || mapped_paths.uniq == [path]
    # Pre-connection cohort checks have no mapping yet. Later authenticated
    # producer/host observations separately establish the actual loaded provider.
    actual.merge('mapped' => mapped_paths.include?(path))
  end

  def identities(client: false, reference: nil)
    require 'thistle/map'
    raise 'Selected Map lacks F05 presentation' unless defined?(Thistle::Map::ConstantOccurrence)
    require 'mysql2' if client
    if reference
      raise 'Reference lock drift' unless reference.fetch('lock').fetch('sha256') == Digest::SHA256.file('/input/artifacts/Gemfile.lock').hexdigest
      locked = reference.fetch('specs').transform_values { |s| s.fetch('version') }
    else
      ENV['BUNDLE_GEMFILE'] = '/input/app/Gemfile' # parser context only; never bundle/setup
      require 'bundler/lockfile_parser'
      locked = Bundler::LockfileParser.new(File.read('/input/artifacts/Gemfile.lock')).specs.to_h { |s| [s.name, s.version.to_s] }
    end
    (reference ? %w[thistle thistle-map] : %w[thistle thistle-map puma]).each do |name|
      expected = name == 'puma' ? '8.0.2' : '0.1.0.pre.3'
      raise 'Host lock is missing selected product/server' unless locked[name] == expected
    end
    providers = JSON.parse(File.read('/input/default-providers.json'))
    Gem.loaded_specs.each do |name, spec|
      verify_spec!(name, spec, locked, providers)
    end
    $LOADED_FEATURES.select { |p| p.start_with?('/') }.each do |path|
      actual = file_identity(path)
      next if actual.fetch('path').start_with?('/work/gems/', '/dependencies/', '/input/control/', '/input/app/', '/work/sessions/')
      expected = providers.fetch('files').fetch(actual.fetch('path'))
      raise 'Immutable image default file drift' unless actual.slice('sha256', 'size') == expected
    end
    native = $LOADED_FEATURES.find { |p| p.match?(%r{/thistle/thistle_native\.(so|bundle)\z}) } or raise 'Native absent'
    result = { 'ruby' => RUBY_DESCRIPTION, 'native' => file_identity(native),
      'artifacts' => config.fetch('artifacts'),
      'lock' => file_identity('/input/artifacts/Gemfile.lock'),
      'specs' => Gem.loaded_specs.sort.to_h.transform_values { |s| { 'version' => s.version.to_s, 'path' => s.full_gem_path } },
      # Builtin feature names (enumerator, fiber, etc.) are not pretend files.
      'builtin_features' => $LOADED_FEATURES.reject { |p| p.start_with?('/') },
      'project_files' => $LOADED_FEATURES.select { |p| p.start_with?('/work/gems/') }.map { |p| file_identity(p) } }
    raise 'Native changed' unless result['native']['sha256'] == config.dig('artifacts', 'native.so', 'sha256')
    %w[thistle thistle-map].each do |name|
      raise 'Product loaded outside installed home' unless Gem.loaded_specs.fetch(name).full_gem_path.start_with?('/work/gems/gems/')
    end
    if client
      path = $LOADED_FEATURES.find { |p| p.match?(%r{/mysql2/mysql2\.(so|bundle)\z}) } or raise 'Client absent'
      result['client'] = file_identity(path)
      raise 'Adapter binary drift' unless result['client']['sha256'] == config.fetch('mysql2_extension_sha256')
      lib = '/proc/self/maps'
      mappings = File.readlines(lib)
      paths = mappings.filter_map { |line| line.split.last if line.match?(/lib(?:mysqlclient|mariadb).*\.so/) }.uniq
      raise 'Client library absent' unless paths.length == 1
      result['client_library'] = file_identity(paths.first)
      raise 'Client library drift' unless result['client_library']['sha256'] == config.fetch('client_library_sha256')
      result['client_version'] = Mysql2::Client.info.fetch(:version)
      raise 'Client provider/version drift' unless result['client_version'] == config.fetch('client_version')
      auth_paths = mappings.filter_map { |line| line.split.last if line.match?(%r{/caching_sha2_password\.so\s*\z}) }.uniq
      result['client_auth_plugin'] = client_auth_identity(auth_paths)
      FileUtils.mkdir_p('/work/loaded', mode: 0o700)
      { 'native.so' => native, 'mysql2.so' => path, 'client.so' => paths.first,
        'client-auth-provider.so' => result['client_auth_plugin'].fetch('path') }.each do |name, source|
        target = File.join('/work/loaded', name)
        if File.exist?(target)
          raise 'Retained loaded binary drift' unless Digest::SHA256.file(target).hexdigest == Digest::SHA256.file(source).hexdigest
        else
          FileUtils.cp(source, target)
        end
      end
    end
    result
  end
end
