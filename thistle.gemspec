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
  spec.required_ruby_version = ">= 3.4"
  spec.metadata = { "allowed_push_host" => "https://unreleased.invalid", "development_status" => "private-milestone" }
  # Installed user/build contracts; contributor policy and history stay in Git.
  installed_docs = %w[
    docs/development/platforms.md
    docs/development/tagged-call-encoding.md
    docs/development/loaded-model-evidence.md
    docs/development/callback-evidence.md
    docs/development/find-evidence.md
    docs/development/route-constraints.md
    docs/development/model-references.md
    docs/development/model-brief-markdown.md
    docs/development/recorded-domain-access.md
    docs/development/fact-identity.md
  ]
  installed_docs.each do |path|
    raise "Missing installed document: #{path}" unless File.file?(path)
  end
  spec.files = Dir.glob("{lib,exe,ext,engine}/**/*", File::FNM_DOTMATCH).select do |path|
    next false unless File.file?(path)
    # Transfer archives and historical evidence are repository documentation,
    # not runtime gem contents. Do not alter the vendored dependency byte set.
    next false if path.start_with?("docs/handoff/")
    next false if path.match?(%r{\Aext/thistle_native/[^/]+\.dSYM/})
    # Vendored crate paths are part of Cargo's checksum contract, including
    # legitimate source subdirectories named target and fixture/build files.
    next true if path.start_with?("engine/vendor/")
    !path.start_with?("engine/target/", "ext/thistle_native/target/") &&
      !path.match?(/\.(?:so|o|bundle|a)\z/) && !%w[Makefile mkmf.log].include?(File.basename(path))
  end + installed_docs + %w[README.md CHANGELOG.md LICENSE THIRD_PARTY.md rust-toolchain.toml .cargo/config.toml]
  spec.bindir = "exe"
  spec.executables = ["thistle"]
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/thistle_native/extconf.rb"]
end

