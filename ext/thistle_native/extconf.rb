# frozen_string_literal: true

require "mkmf"
require "shellwords"

host_os = RbConfig::CONFIG.fetch("host_os")
abort "Thistle source builds require Linux or macOS (see README)" unless /linux|darwin/.match?(host_os)
engine = File.expand_path("../../engine", __dir__)
target = File.expand_path("target", __dir__)
cargo = ENV.fetch("THISTLE_CARGO", "cargo")
command = [cargo, "build", "--release", "--locked", "--offline", "--target-dir", target]
abort "Rust build failed; install Rust 1.90, a C compiler and libclang (see README)" unless system(*command, chdir: engine)

archive = File.join(target, "release", "libthistle_core.a")
abort "Rust library was not produced" unless File.file?(archive)
$LOCAL_LIBS = "#{Shellwords.escape(archive)} #{$LOCAL_LIBS}"
if /linux/.match?(host_os)
  $LOCAL_LIBS << " -ldl -lpthread -lm"
  $LDFLAGS << " -Wl,--exclude-libs,ALL"
else
  # Darwin's libSystem supplies these system libraries. Only Ruby's entry point
  # needs to be visible; keep the linked Rust archive out of the public ABI.
  $LDFLAGS << " -Wl,-exported_symbol,_Init_thistle_native"
end
create_makefile("thistle/thistle_native")
