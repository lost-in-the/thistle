# frozen_string_literal: true

require "mkmf"
require "shellwords"

abort "This private Thistle milestone currently builds on Linux only" unless /linux/.match?(RUBY_PLATFORM)
engine = File.expand_path("../../engine", __dir__)
target = File.expand_path("target", __dir__)
cargo = ENV.fetch("THISTLE_CARGO", "cargo")
command = [cargo, "build", "--release", "--locked", "--offline", "--target-dir", target]
abort "Rust build failed; install Rust 1.90, a C compiler and libclang (see README)" unless system(*command, chdir: engine)

archive = File.join(target, "release", "libthistle_core.a")
abort "Rust library was not produced" unless File.file?(archive)
$LOCAL_LIBS = "#{Shellwords.escape(archive)} -ldl -lpthread -lm #{$LOCAL_LIBS}"
$LDFLAGS << " -Wl,--exclude-libs,ALL"
create_makefile("thistle/thistle_native")
