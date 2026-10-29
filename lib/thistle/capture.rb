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
        static_links = result.fetch("facts").sum { |fact| fact.fetch("links").length }
        remaining = effective.merge(
          max_facts: effective[:max_facts] - result.fetch("facts").length,
          max_links: effective[:max_links] - static_links,
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
        # Count only the returned route batch; never rescan all static facts.
        fact_bytes = static_evidence_bytes + runtime.fetch("facts").sum { |fact| JSON.generate(fact).bytesize + 1 }
        links = static_links + runtime.fetch("facts").sum { |fact| fact.fetch("links").length }
        observations = ModelObserver.new(
          limits: effective.merge(max_facts: effective[:max_facts] - result.fetch("facts").length),
          evidence_budget: MAX_EVIDENCE_BYTES - fact_bytes
        ).call
        fact_bytes, links = append_observations(result, effective, "model", observations, fact_bytes, links)
        require_relative "callback_observer"
        callbacks = CallbackObserver.new(
          root: File.expand_path(@root),
          limits: effective.merge(max_facts: effective[:max_facts] - result.fetch("facts").length),
          evidence_budget: MAX_EVIDENCE_BYTES - fact_bytes
        ).call
        append_observations(result, effective, "callback", callbacks, fact_bytes, links)
      end
      raise LimitError, "Capture exceeds max_facts" if result["facts"].length > effective[:max_facts]
      raise LimitError, "Capture exceeds max_diagnostics" if result["diagnostics"].length > effective[:max_diagnostics]

      result
    end

    private

    def append_observations(result, effective, family, observation, fact_bytes, links)
      added = Native.call("op" => "#{family}_batch", "observation" => observation, "context" => {
        "limits" => effective.slice(:max_facts, :max_links, :max_entries, :max_diagnostics),
        "facts" => result.fetch("facts").length, "links" => links,
        "diagnostics" => result.fetch("diagnostics").length, "fact_bytes" => fact_bytes
      })
      result.fetch("facts").concat(added.fetch("facts"))
      families = added.fetch("coverage").map { |entry| entry.fetch("family") }
      result.fetch("coverage").reject! { |entry| families.include?(entry["family"]) }
      result.fetch("coverage").concat(added.fetch("coverage"))
      result.fetch("producer")["#{family}_observer"] = added.fetch("#{family}_observer")
      charge = added.fetch("appended")
      [fact_bytes + charge.fetch("fact_bytes"), links + charge.fetch("links")]
    end
  end
end
