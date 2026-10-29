# frozen_string_literal: true

# Development feedback from fresh source-gem installs, not independent qualification.
# Invoke through bundle exec so the tested dependency resolution is explicit.
require "bundler"
require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

source = File.expand_path("..", __dir__)
FileUtils.mkdir_p(File.join(source, "pkg"))
output = Dir.mktmpdir("install-check-", File.join(source, "pkg"))
dependencies = Bundler.load.specs.reject { |spec| %w[thistle bundler].include?(spec.name) || spec.default_gem? }
dependencies.each do |spec|
  abort "Missing cached gem #{spec.full_name}; run bundle cache first" unless File.file?(spec.cache_file)
end
core_spec = Gem::Specification.load(File.join(source, "thistle.gemspec"))
map_spec = Gem::Specification.load(File.join(source, "map/thistle-map.gemspec"))

Dir.mktmpdir("thistle-installed-", File.realpath(Dir.tmpdir)) do |worker|
  Bundler.with_unbundled_env do
    # Pass build inputs only, never credentials or inherited Ruby/Bundler injection.
    env = ENV.to_h.slice("PATH", "HOME", "RUSTUP_HOME", "LIBCLANG_PATH", "THISTLE_CARGO", "SDKROOT")
    env.merge!("GEM_HOME" => File.join(worker, "gems"), "GEM_PATH" => File.join(worker, "gems"),
               "BUNDLE_PATH" => File.join(worker, "bundle"), "BUNDLE_GEMFILE" => File.join(worker, "Gemfile"),
               "BUNDLE_IGNORE_CONFIG" => "true", "BUNDLE_DISABLE_SHARED_GEMS" => "true",
               "CARGO_HOME" => File.join(worker, "cargo"), "CARGO_NET_OFFLINE" => "true",
               "TMPDIR" => File.realpath(Dir.tmpdir), "LANG" => "C.UTF-8")
    ruby = RbConfig.ruby
    run = ->(*args, cwd: worker) do
      system(env, *args, chdir: cwd, unsetenv_others: true, exception: true)
    end
    capture = ->(*args, cwd: worker) do
      stdout, stderr, status = Open3.capture3(env, *args, chdir: cwd, unsetenv_others: true)
      raise "#{args.first} failed: #{stderr}" unless status.success?
      stdout
    end
    core, map = [core_spec, map_spec].map { |spec| File.join(output, spec.file_name) }
    run.call(ruby, "-S", "gem", "build", "thistle.gemspec", "--output", core, cwd: source)
    run.call(ruby, "-S", "gem", "build", "thistle-map.gemspec", "--output", map, cwd: File.join(source, "map"))
    cache = File.join(worker, "vendor/cache")
    FileUtils.mkdir_p(cache)
    FileUtils.cp(dependencies.map(&:cache_file) + [core, map], cache)
    # A real consumer bundle, resolved offline from canonical gem filenames.
    requirements = dependencies.map { |spec| [spec.name, spec.version.to_s] }
    requirements += [[core_spec.name, core_spec.version.to_s], [map_spec.name, map_spec.version.to_s]]
    File.write(env.fetch("BUNDLE_GEMFILE"), "source \"https://rubygems.org\"\n" +
      requirements.map { |name, version| "gem #{name.inspect}, #{("= " + version).inspect}\n" }.join)
    run.call(ruby, "-S", "bundle", "install", "--local")
    observe = <<~'CHILD'
      require "bundler"
      require "thistle"
      require "json"
      require "digest"
      native = $LOADED_FEATURES.find { |path| path.match?(%r{/thistle/thistle_native\.(so|bundle)\z}) }
      raise "Installed native extension not loaded" unless native
      native = File.realpath(native)
      raise "Native loaded outside consumer bundle" unless native.start_with?(File.realpath(Bundler.bundle_path) + File::SEPARATOR)
      puts JSON.generate(native_sha256: Digest::SHA256.file(native).hexdigest,
        installed_root: Gem.loaded_specs.fetch("thistle").full_gem_path)
    CHILD
    observed = JSON.parse(capture.call(ruby, "-S", "bundle", "exec", ruby, "-e", observe))
    installed_root = observed.fetch("installed_root")
    installed_lib = File.join(installed_root, "lib")
    # Relative fixture imports and child processes resolve only installed code.
    FileUtils.cp_r(File.join(source, "test"), worker)
    File.symlink(installed_lib, File.join(worker, "lib"))
    run.call(ruby, "-S", "bundle", "exec", ruby, "-I", installed_lib, "-e",
      'paths = Dir["test/test_*.rb"].sort; abort "Core tests absent" if paths.empty?; paths.each { |f| require File.expand_path(f) }')
    FileUtils.cp(File.join(source, "map/test/installed_smoke.rb"), worker)
    run.call(ruby, "-S", "bundle", "exec", ruby, "installed_smoke.rb")
    FileUtils.cp(File.join(source, "test/support/installed_cli.rb"), worker)
    run.call(ruby, "-S", "bundle", "exec", ruby, "installed_cli.rb")
    FileUtils.cp(File.join(source, "Gemfile.lock"), File.join(output, "development-Gemfile.lock"))
    FileUtils.cp(File.join(worker, "Gemfile.lock"), File.join(output, "consumer-Gemfile.lock"))
    report = {
      status: "passed", scope: "development installed contracts",
      ruby: RUBY_DESCRIPTION, platform: RUBY_PLATFORM,
      bundler: capture.call(ruby, "-S", "bundle", "--version").strip,
      cargo: capture.call(ENV.fetch("THISTLE_CARGO", "cargo"), "--version", cwd: installed_root).strip,
      rustc: capture.call("rustc", "--version", cwd: installed_root).strip,
      cc: capture.call("cc", "--version").lines.first.strip,
      packages: { core: Digest::SHA256.file(core).hexdigest, map: Digest::SHA256.file(map).hexdigest },
      native_sha256: observed.fetch("native_sha256"),
      development_lock_sha256: Digest::SHA256.file(File.join(output, "development-Gemfile.lock")).hexdigest,
      consumer_lock_sha256: Digest::SHA256.file(File.join(output, "consumer-Gemfile.lock")).hexdigest
    }
    File.write(File.join(output, "report.json"), JSON.pretty_generate(report) + "\n")
    puts JSON.pretty_generate(report)
    puts "Installed evidence: #{output}"
  end
end
