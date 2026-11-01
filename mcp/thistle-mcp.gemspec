# frozen_string_literal: true

require_relative "lib/thistle/mcp/version"

Gem::Specification.new do |spec|
  spec.name = "thistle-mcp"
  spec.version = Thistle::MCP::VERSION
  spec.authors = ["Thistle project contributors"]
  spec.summary = "Local saved-generation investigation through Thistle's public Reader"
  spec.description = "An optional stdio MCP adapter over one explicitly selected immutable Thistle generation."
  spec.homepage = "https://github.com/lost-in-the/thistle"
  spec.license = "Nonstandard"
  spec.required_ruby_version = ">= 3.4"
  spec.metadata = { "allowed_push_host" => "https://unreleased.invalid", "development_status" => "private-milestone" }
  # Explicit payload: no tests, stores, client configuration or credentials.
  spec.files = %w[
    lib/thistle/mcp.rb
    lib/thistle/mcp/version.rb
    lib/thistle/mcp/limits.rb
    lib/thistle/mcp/session.rb
    lib/thistle/mcp/tools.rb
    lib/thistle/mcp/server.rb
    lib/thistle/mcp/stdio.rb
    exe/thistle-mcp
    README.md
    docs/local-reader.md
    LICENSE
    THIRD_PARTY.md
  ]
  spec.files.each do |path|
    raise "Missing MCP package input: #{path}" unless File.file?(File.join(__dir__, path))
  end
  spec.bindir = "exe"
  spec.executables = ["thistle-mcp"]
  spec.require_paths = ["lib"]
  spec.add_runtime_dependency "thistle", "= 0.1.0.pre.3"
  spec.add_runtime_dependency "mcp", "= #{Thistle::MCP::SDK_VERSION}"
end
