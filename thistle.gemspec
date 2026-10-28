# frozen_string_literal: true

require_relative "lib/thistle/version"

Gem::Specification.new do |spec|
  spec.name = "thistle"
  spec.version = Thistle::VERSION
  spec.authors = ["Thistle project contributors"]
  spec.summary = "Native evidence and source inspection for Ruby applications"
  spec.description = "An unreleased Rust engine packaged as a Ruby gem, with explicit Rails observations and immutable evidence generations."
  spec.homepage = "https://chatgpt.com/space/page_83d1d4a1a4ec81918d7310c21061c4e4"
  spec.license = "Nonstandard"
  spec.required_ruby_version = ">= 3.0"
  spec.metadata = { "allowed_push_host" => "https://unreleased.invalid", "development_status" => "private-milestone" }
  spec.files = Dir.glob("{lib,exe,ext,engine,docs}/**/*", File::FNM_DOTMATCH).select do |path|
    next false unless File.file?(path)
    # Vendored crate paths are part of Cargo's checksum contract, including
    # legitimate source subdirectories named target and fixture/build files.
    next true if path.start_with?("engine/vendor/")
    !path.start_with?("engine/target/", "ext/thistle_native/target/") &&
      !path.match?(/\.(?:so|o|bundle|a)\z/) && !%w[Makefile mkmf.log].include?(File.basename(path))
  end + %w[README.md LICENSE THIRD_PARTY.md rust-toolchain.toml .cargo/config.toml]
  spec.bindir = "exe"
  spec.executables = ["thistle"]
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/thistle_native/extconf.rb"]
end
