# frozen_string_literal: true

require "rake/testtask"
require "rbconfig"
require "tmpdir"

# Store paths deliberately reject symlink ancestors. macOS exposes its default
# temporary directory through /var; tests must use the physical fixture root.
task :test_environment do
  ENV["TMPDIR"] = File.realpath(Dir.tmpdir)
end

desc "Compile the Rust engine and thin Ruby native bridge"
task :compile do
  Dir.chdir("ext/thistle_native") do
    ruby "extconf.rb"
    # Recompile the small C bridge when switching Ruby ABIs. mkmf also does not
    # track the externally built Rust archive; clean forces the final relink.
    sh ENV.fetch("MAKE", "make"), "clean"
    sh ENV.fetch("MAKE", "make")
    FileUtils.mkdir_p("../../lib/thistle")
    FileUtils.cp("thistle_native.#{RbConfig::CONFIG.fetch('DLEXT')}", "../../lib/thistle/")
  end
end

task unit: :test_environment

desc "Run the locked, offline Rust tests"
task native: :test_environment do
  sh ENV.fetch("THISTLE_CARGO", "cargo"), "test", "--locked", "--offline", "--manifest-path", "engine/Cargo.toml"
end

Rake::TestTask.new(:map) do |task|
  task.libs.concat ["lib", "map/lib", "map/test"]
  task.pattern = "map/test/*_test.rb"
  task.warning = false
end
task map: :test_environment

desc "Build and verify fresh core/Map source-gem installs outside the checkout"
task installed: :test_environment do
  ruby "tools/check_install.rb"
end

Rake::TestTask.new(:unit) do |task|
  task.libs << "lib"
  task.pattern = "test/test_*.rb"
  task.warning = true
end

desc "Run optional MCP admission contracts without SDK/native activation"
task :mcp do
  paths = %w[session tools stdio].map { |name| "mcp/test/#{name}_test.rb" }
  abort "MCP contract test inputs absent" unless paths.all? { |path| File.file?(path) }
  # CI's Rails bundle supplies a Minitest reporter plugin. Keep this pure child
  # isolated without changing the parent environment or weakening its guards.
  sh({ "MT_NO_PLUGINS" => "1" }, RbConfig.ruby, "-Imcp/lib", "-e",
    'ARGV.each { |path| require File.expand_path(path) }', *paths)
end

desc "Run the native, Ruby and optional MCP contract tests"
task test: [:compile, :unit, :mcp]

task default: :test
