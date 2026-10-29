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

    def self.copy_limits(limits)
      raise InvalidInput, "Capture limits must be a Hash" unless limits.is_a?(Hash)

      limits.each_with_object({}) do |(key, value), copy|
        unless key.is_a?(String) || key.is_a?(Symbol)
          raise InvalidInput, "Capture limit keys must be strings or symbols"
        end
        name = key.to_s
        raise InvalidInput, "Duplicate capture limit keys" if copy.key?(name)

        copy[name] = value
      end.freeze
    end

    def initialize(root:, rails: nil, limits: {})
      @root = root.to_s
      @rails = rails
      @limits = self.class.copy_limits(limits)
    end

    def call
      result = Native.call("op" => "capture", "root" => @root, "limits" => @limits)
      effective = result.fetch("producer").fetch("effective_limits").transform_keys(&:to_sym)
      if @rails
        require_relative "rails_capture"
        remaining = effective.merge(
          max_facts: effective[:max_facts] - result.fetch("facts").length,
          max_links: effective[:max_links] - result.fetch("facts").sum { |fact| fact.fetch("links").length },
          max_diagnostics: effective[:max_diagnostics] - result.fetch("diagnostics").length
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
        require_relative "model_observer"
        observations = ModelObserver.new(
          limits: effective.merge(max_facts: effective[:max_facts] - result.fetch("facts").length),
          evidence_budget: MAX_EVIDENCE_BYTES - JSON.generate(result.fetch("facts")).bytesize
        ).call
        added = Native.call("op" => "model_batch", "observation" => observations, "context" => {
          "limits" => effective.slice(:max_facts, :max_links, :max_entries, :max_diagnostics),
          "facts" => result.fetch("facts").length,
          "links" => result.fetch("facts").sum { |fact| fact.fetch("links").length },
          "diagnostics" => result.fetch("diagnostics").length,
          "fact_bytes" => JSON.generate(result.fetch("facts")).bytesize
        })
        result.fetch("facts").concat(added.fetch("facts"))
        result["coverage"].reject! { |entry| %w[rails_models rails_model_effects].include?(entry["family"]) }
        result.fetch("coverage").concat(added.fetch("coverage"))
        result.fetch("producer")["model_observer"] = added.fetch("model_observer")
      end
      raise LimitError, "Capture exceeds max_facts" if result["facts"].length > effective[:max_facts]
      raise LimitError, "Capture exceeds max_diagnostics" if result["diagnostics"].length > effective[:max_diagnostics]

      result
    end
  end
end
