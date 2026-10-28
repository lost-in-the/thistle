# frozen_string_literal: true

require_relative "errors"
require_relative "native"

module Thistle
  # Small gem facade: the Rust engine owns inventory and syntax extraction.
  # Ruby is used only to observe an explicitly supplied Rails application.
  class Capture
    Error = Thistle::Error
    LimitError = Thistle::LimitExceeded
    UnsupportedPlatform = Thistle::UnsupportedPlatform
    MAX_EVIDENCE_BYTES = 64 * 1024 * 1024

    DEFAULT_LIMITS = {
      max_files: 10_000,
      max_file_bytes: 2 * 1024 * 1024,
      max_total_bytes: 64 * 1024 * 1024,
      max_entries: 100_000,
      max_depth: 64,
      max_nodes: 1_000_000,
      max_facts: 100_000,
      max_links: 500_000,
      max_routes: 20_000,
      max_diagnostics: 1_000
    }.freeze

    def initialize(root:, rails: nil, limits: {})
      @root = root.to_s
      @rails = rails
      raise InvalidInput, "Capture limits must be a Hash" unless limits.is_a?(Hash)

      supplied = limits.transform_keys { |key| key.to_s.to_sym }
      @limits = DEFAULT_LIMITS.merge(supplied).freeze
    end

    def call
      result = Native.call("op" => "capture", "root" => @root, "limits" => @limits)
      if @rails
        require_relative "rails_capture"
        remaining = @limits.merge(
          max_facts: @limits[:max_facts] - result.fetch("facts").length,
          max_links: @limits[:max_links] - result.fetch("facts").sum { |fact| fact.fetch("links").length },
          max_diagnostics: @limits[:max_diagnostics] - result.fetch("diagnostics").length
        )
        static_evidence_bytes = JSON.generate(result.fetch("facts")).bytesize
        raise LimitError, "Capture fact evidence exceeds the 64 MiB payload budget" if static_evidence_bytes > MAX_EVIDENCE_BYTES

        runtime = RailsCapture.new(
          app: @rails, limits: remaining,
          evidence_budget: MAX_EVIDENCE_BYTES - static_evidence_bytes
        ).call
        result["coverage"].reject! { |entry| entry["family"] == "rails_routes" }
        result["facts"].concat(runtime.fetch("facts"))
        result["coverage"].concat(runtime.fetch("coverage"))
        result["diagnostics"].concat(runtime.fetch("diagnostics"))
        result["producer"]["rails_version"] = runtime.fetch("rails_version")
        result["producer"]["ruby_version"] = RUBY_VERSION
        result["producer"]["ruby_engine"] = RUBY_ENGINE
      end
      raise LimitError, "Capture exceeds max_facts" if result["facts"].length > @limits[:max_facts]
      raise LimitError, "Capture exceeds max_diagnostics" if result["diagnostics"].length > @limits[:max_diagnostics]

      result
    end
  end
end
