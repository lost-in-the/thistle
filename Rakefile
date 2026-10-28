# frozen_string_literal: true

require "rake/testtask"
require "rbconfig"

desc "Compile the Rust engine and thin Ruby native bridge"
task :compile do
  Dir.chdir("ext/thistle_native") do
    ruby "extconf.rb"
    # mkmf does not track the externally built Rust archive as a prerequisite.
    FileUtils.rm_f("thistle_native.#{RbConfig::CONFIG.fetch('DLEXT')}")
    sh ENV.fetch("MAKE", "make")
    FileUtils.mkdir_p("../../lib/thistle")
    FileUtils.cp("thistle_native.#{RbConfig::CONFIG.fetch('DLEXT')}", "../../lib/thistle/")
  end
end

Rake::TestTask.new(:unit) do |task|
  task.libs << "lib"
  task.pattern = "test/test_*.rb"
  task.warning = true
end

desc "Run the native and Ruby contract tests"
task test: [:compile, :unit]

task default: :test
