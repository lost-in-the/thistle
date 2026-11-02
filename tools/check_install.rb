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
puts "Installed evidence: #{output}"
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
    # Check actual payloads before staging or installing the already-built pair.
    require "rubygems/package"
    {
      core => %w[docs/development/platforms.md docs/development/tagged-call-encoding.md
                 docs/development/loaded-model-evidence.md docs/development/callback-evidence.md
                 docs/development/find-evidence.md docs/development/route-constraints.md
                 docs/development/model-references.md docs/development/recorded-domain-access.md
                 docs/development/fact-identity.md docs/development/model-brief-markdown.md
                 docs/development/source-comprehension.md docs/development/job-mail-template.md docs/development/route-actions.md docs/development/passage.md docs/development/model-neighborhood.md docs/development/source-freshness.md docs/development/replacement-contract.md],
      map => %w[docs/MODELS.md docs/REUSE.md docs/investigations.md docs/source-comprehension.md docs/job-mail-template.md docs/route-actions.md docs/passage.md docs/model-neighborhood.md docs/model-reading.md]
    }.each do |package, expected|
      actual = Gem::Package.new(package).contents.select { |path| path.start_with?("docs/") }.sort
      raise "Installed document manifest differs for #{File.basename(package)}: #{actual.inspect}" unless actual == expected.sort
    end
    cache = File.join(worker, "vendor/cache")
    FileUtils.mkdir_p(cache)
    FileUtils.cp(dependencies.map(&:cache_file) + [core, map], cache)
    # A real consumer bundle, resolved offline from canonical gem filenames.
    requirements = dependencies.map { |spec| [spec.name, spec.version.to_s] }
    requirements += [[core_spec.name, core_spec.version.to_s], [map_spec.name, map_spec.version.to_s]]
    File.write(env.fetch("BUNDLE_GEMFILE"), "source \"https://rubygems.org\"\n" +
      requirements.map { |name, version| "gem #{name.inspect}, #{("= " + version).inspect}\n" }.join)
    run.call(ruby, "-S", "bundle", "install", "--local")
    FileUtils.cp(File.join(source, "Gemfile.lock"), File.join(output, "development-Gemfile.lock"))
    FileUtils.cp(File.join(worker, "Gemfile.lock"), File.join(output, "consumer-Gemfile.lock"))
    observe = <<~'CHILD'
      require "bundler"
      require "thistle"
      require "json"
      require "digest"
      native = $LOADED_FEATURES.find { |path| path.match?(%r{/thistle/thistle_native\.(so|bundle)\z}) }
      raise "Installed native extension not loaded" unless native
      native = File.realpath(native)
      raise "Native loaded outside consumer bundle" unless native.start_with?(File.realpath(Bundler.bundle_path) + File::SEPARATOR)
      puts JSON.generate(native_path: native, native_sha256: Digest::SHA256.file(native).hexdigest,
        installed_root: Gem.loaded_specs.fetch("thistle").full_gem_path)
    CHILD
    observed = JSON.parse(capture.call(ruby, "-S", "bundle", "exec", ruby, "-e", observe))
    File.write(File.join(output, "native-observation.json"), JSON.pretty_generate(observed) + "\n")
    installed_root = observed.fetch("installed_root")
    installed_lib = File.join(installed_root, "lib")
    # Stream receipts to retained evidence, including output from failed children.
    # The worker holds executable inputs and stores outside the source checkout.
    logged = ->(name, *args) do
      system(env, *args, chdir: worker, unsetenv_others: true, exception: true,
        out: File.join(output, name), err: File.join(output, "#{name}.stderr"))
    end
    # Relative fixture imports and child processes resolve only installed code.
    FileUtils.cp_r(File.join(source, "test"), worker)
    # Core's saved-model refusal contract uses this independent known answer.
    # Stage fixture data only; engine source must not enter the consumer load path.
    FileUtils.mkdir_p(File.join(worker, "engine/tests"))
    FileUtils.cp_r(File.join(source, "engine/tests/fixtures"), File.join(worker, "engine/tests"))
    core_fixture_inputs = Dir[File.join(worker, "engine/tests/fixtures/**/*")].sort
      .select { |path| File.file?(path) }.to_h do |path|
        [path.delete_prefix(worker + File::SEPARATOR), Digest::SHA256.file(path).hexdigest]
      end
    File.write(File.join(output, "core-fixture-inputs.json"), JSON.pretty_generate(core_fixture_inputs) + "\n")
    File.symlink(installed_lib, File.join(worker, "lib"))
    logged.call("core-tests.log", ruby, "-S", "bundle", "exec", ruby, "-I", installed_lib, "-e",
      'paths = Dir["test/test_*.rb"].sort; abort "Core tests absent" if paths.empty?; paths.each { |f| require File.expand_path(f) }')
    smoke = File.join(worker, "installed_smoke.rb")
    FileUtils.cp(File.join(source, "map/test/installed_smoke.rb"), smoke)
    smoke_args = []
    model_inputs = {}
    model_receipt = nil
    # Installed Core payload, never fixture availability, decides applicability.
    model_enabled = File.file?(File.join(installed_lib, "thistle/model_observer.rb"))
    if model_enabled
      fixture = File.join(worker, "model-fixture")
      FileUtils.mkdir_p(fixture)
      %w[booted_app.rb records.rb].each do |name|
        FileUtils.cp(File.join(source, "test/fixtures/models", name), File.join(fixture, name))
      end
      producer = File.join(worker, "installed_model_producer.rb")
      FileUtils.cp(File.join(source, "map/test/installed_model_producer.rb"), producer)
      [producer, *Dir[File.join(fixture, "*.rb")].sort].each do |path|
        model_inputs[path.delete_prefix(worker + File::SEPARATOR)] = Digest::SHA256.file(path).hexdigest
      end
    end
    inputs = { smoke_sha256: Digest::SHA256.file(smoke).hexdigest,
               model_enabled: model_enabled, model_fixture_inputs: model_inputs,
               core_fixture_inputs: core_fixture_inputs }
    File.write(File.join(output, "installed-inputs.json"), JSON.pretty_generate(inputs) + "\n")
    if model_enabled
      model_store = File.join(worker, "model-store")
      model_receipt = File.join(output, "model-producer.json")
      logged.call("model-producer.json", ruby, "-S", "bundle", "exec", ruby, producer,
        fixture, File.join(worker, "model-source"), model_store)
      # Successful completion is required before a fresh, Rails-free consumer.
      receipt = File.join(worker, "model-producer.json")
      FileUtils.cp(model_receipt, receipt)
      smoke_args = [model_store, receipt]
    end
    logged.call("map-installed-smoke.json", ruby, "-S", "bundle", "exec", ruby, smoke, *smoke_args)
    smoke_report = JSON.parse(File.read(File.join(output, "map-installed-smoke.json")))
    raise "Installed Map smoke did not pass" unless smoke_report.fetch("status") == "passed"
    raise "Installed Map smoke loaded different native bytes" unless smoke_report.fetch("native_sha256") == observed.fetch("native_sha256")
    # Callbacks have their own accepted producer/consumer argv protocol. Keep the
    # selected Model/Find smoke unchanged, including on pre-callback packages.
    callback_enabled = File.file?(File.join(installed_lib, "thistle/callback_observer.rb"))
    callback_inputs = {}
    callback_receipt = callback_result = nil
    if callback_enabled
      fixture = File.join(worker, "callback-fixture")
      FileUtils.mkdir_p(fixture)
      paths = %w[booted_app.rb records.rb].map do |name|
        target = File.join(fixture, name)
        FileUtils.cp(File.join(source, "test/fixtures/callbacks", name), target)
        target
      end
      %w[installed_callback_producer.rb installed_callback_consumer.rb].each do |name|
        target = File.join(worker, name)
        FileUtils.cp(File.join(source, "map/test", name), target)
        paths << target
      end
      callback_inputs = paths.to_h do |path|
        [path.delete_prefix(worker + File::SEPARATOR), Digest::SHA256.file(path).hexdigest]
      end
      File.write(File.join(output, "callback-inputs.json"), JSON.pretty_generate(callback_inputs) + "\n")
      store = File.join(worker, "callback-store")
      callback_receipt = File.join(output, "callback-producer.json")
      logged.call("callback-producer.json", ruby, "-S", "bundle", "exec", ruby,
        File.join(worker, "installed_callback_producer.rb"), fixture, File.join(worker, "callback-source"), store)
      produced = JSON.parse(File.read(callback_receipt))
      raise "Installed callback producer loaded different native bytes" unless produced.fetch("native_sha256") == observed.fetch("native_sha256")
      raise "Installed callback producer captured different fixture bytes" unless
        produced.fetch("fixture_source_sha256") == callback_inputs.fetch("callback-fixture/records.rb")
      receipt = File.join(worker, "callback-producer.json")
      FileUtils.cp(callback_receipt, receipt)
      callback_result = File.join(output, "callback-consumer.json")
      logged.call("callback-consumer.json", ruby, "-S", "bundle", "exec", ruby,
        File.join(worker, "installed_callback_consumer.rb"), store, receipt)
      consumed = JSON.parse(File.read(callback_result))
      raise "Installed callback consumer did not pass" unless consumed.fetch("status") == "passed"
      raise "Installed callback consumer loaded different native bytes" unless consumed.fetch("native_sha256") == observed.fetch("native_sha256")
      callback_inputs.each do |path, expected|
        raise "Installed callback input changed: #{path}" unless Digest::SHA256.file(File.join(worker, path)).hexdigest == expected
      end
    end
    FileUtils.cp(File.join(source, "test/support/installed_cli.rb"), worker)
    logged.call("installed-cli.log", ruby, "-S", "bundle", "exec", ruby, "installed_cli.rb")
    report = {
      status: "passed", scope: "development installed contracts",
      ruby: RUBY_DESCRIPTION, platform: RUBY_PLATFORM,
      bundler: capture.call(ruby, "-S", "bundle", "--version").strip,
      cargo: capture.call(ENV.fetch("THISTLE_CARGO", "cargo"), "--version", cwd: installed_root).strip,
      rustc: capture.call("rustc", "--version", cwd: installed_root).strip,
      cc: capture.call("cc", "--version").lines.first.strip,
      packages: { core: Digest::SHA256.file(core).hexdigest, map: Digest::SHA256.file(map).hexdigest },
      native_path: observed.fetch("native_path"),
      native_sha256: observed.fetch("native_sha256"),
      installed_inputs: inputs,
      model_journey: model_enabled ? "passed" : "not_applicable_to_selected_package",
      model_producer_receipt_sha256: model_receipt && Digest::SHA256.file(model_receipt).hexdigest,
      map_smoke_receipt_sha256: Digest::SHA256.file(File.join(output, "map-installed-smoke.json")).hexdigest,
      callback_journey: callback_enabled ? "passed" : "not_applicable_to_selected_package",
      callback_fixture_inputs: callback_inputs,
      callback_producer_receipt_sha256: callback_receipt && Digest::SHA256.file(callback_receipt).hexdigest,
      callback_consumer_receipt_sha256: callback_result && Digest::SHA256.file(callback_result).hexdigest,
      development_lock_sha256: Digest::SHA256.file(File.join(output, "development-Gemfile.lock")).hexdigest,
      consumer_lock_sha256: Digest::SHA256.file(File.join(output, "consumer-Gemfile.lock")).hexdigest
    }
    File.write(File.join(output, "report.json"), JSON.pretty_generate(report) + "\n")
    puts JSON.pretty_generate(report)
    puts "Installed evidence: #{output}"
  end
end
