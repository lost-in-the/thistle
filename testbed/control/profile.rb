# frozen_string_literal: true

require 'json'
require 'digest'
require 'fileutils'
require 'rbconfig'

module HostProfile
  module_function

  def config = @config ||= JSON.parse(File.read('/input/profile.json'))

  def activate
    raise 'Ruby cohort drift' unless RUBY_VERSION == config.fetch('ruby')
    raise 'Ruby ABI/platform drift' unless RbConfig::CONFIG.fetch('ruby_version') == '3.4.0' && RUBY_PLATFORM.start_with?('x86_64-linux')
    ENV['GEM_HOME'] = '/work/gems'
    ENV['GEM_PATH'] = ['/work/gems', config.fetch('dependency_home')].join(':')
    Gem.clear_paths
    gem 'bundler', '= 2.6.9'
    { 'railties' => '7.1.6', 'activerecord' => '7.1.6', 'actionpack' => '7.1.6',
      'rack' => '3.2.7', 'rouge' => '4.6.1',
      'minitest' => '5.25.4', 'mysql2' => '0.5.7' }.each { |name, version| gem name, "= #{version}" }
  end

  def write(path, object)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(JSON.pretty_generate(object)) }
  end

  def file_identity(path)
    raise 'Identity needs an actual absolute file' unless path.start_with?('/') && File.file?(path)
    { 'path' => File.realpath(path), 'sha256' => Digest::SHA256.file(path).hexdigest, 'size' => File.size(path) }
  end

  def identities(client: false)
    require 'thistle/map'
    raise 'Selected Map lacks F05 presentation' unless defined?(Thistle::Map::ConstantOccurrence)
    require 'mysql2' if client
    ENV['BUNDLE_GEMFILE'] = '/input/app/Gemfile' # controlled parser context only; never bundle/setup
    require 'bundler/lockfile_parser'
    locked = Bundler::LockfileParser.new(File.read('/input/artifacts/Gemfile.lock')).specs.to_h { |s| [s.name, s.version.to_s] }
    %w[thistle thistle-map puma].each do |name|
      expected = name == 'puma' ? '8.0.2' : '0.1.0.pre.3'
      raise 'Host lock is missing selected product/server' unless locked[name] == expected
    end
    Gem.loaded_specs.each do |name, spec|
      next if spec.default_gem? || name == 'bundler'
      raise 'Loaded resolution not in supplied cohort lock' unless locked[name] == spec.version.to_s
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
      paths = File.readlines(lib).filter_map { |line| line.split.last if line.match?(/lib(?:mysqlclient|mariadb).*\.so/) }.uniq
      raise 'Client library absent' unless paths.length == 1
      result['client_library'] = file_identity(paths.first)
      raise 'Client library drift' unless result['client_library']['sha256'] == config.fetch('client_library_sha256')
      result['client_version'] = Mysql2::Client.info.fetch(:version)
      raise 'Client provider/version drift' unless result['client_version'] == config.fetch('client_version')
      FileUtils.mkdir_p('/work/loaded', mode: 0o700)
      { 'native.so' => native, 'mysql2.so' => path, 'client.so' => paths.first }.each do |name, source|
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
