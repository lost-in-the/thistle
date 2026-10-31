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

    def initialize(root:, rails: nil, limits: {}, source_comprehension: nil)
      @root = root.to_s
      @rails = rails
      @limits = self.class.copy_limits(limits)
      @source_comprehension = source_comprehension_context(source_comprehension)
    end

    def call
      result = Native.call("op" => "capture", "root" => @root, "limits" => @limits)
      fact_bytes = native_evidence_bytes(result)
      effective = result.fetch("producer").fetch("effective_limits").transform_keys(&:to_sym)
      # One initial link count for explicit observation paths. Append uses native
      # delta charges and never rewalks/serializes earlier facts for each family.
      links = (@rails || @source_comprehension) ? result.fetch("facts").sum { |fact| fact.fetch("links").length } : 0
      if @rails
        require_relative "rails_capture"
        static_fact_count = result.fetch("facts").length
        static_links = links
        remaining = effective.merge(
          max_facts: effective[:max_facts] - static_fact_count,
          max_links: effective[:max_links] - static_links,
          max_diagnostics: effective[:max_diagnostics] - result.fetch("diagnostics").length
        )
        runtime = RailsCapture.new(
          app: @rails, limits: remaining,
          evidence_budget: MAX_EVIDENCE_BYTES - fact_bytes
        ).call
        result["coverage"].reject! { |entry| entry["family"] == "rails_routes" }
        result["facts"].concat(runtime.fetch("facts"))
        result["coverage"].concat(runtime.fetch("coverage"))
        result["diagnostics"].concat(runtime.fetch("diagnostics"))
        result["producer"]["rails_version"] = runtime.fetch("rails_version")
        result["producer"]["ruby_version"] = RUBY_VERSION
        result["producer"]["ruby_engine"] = RUBY_ENGINE
        require_relative "model_observer"
        # RailsCapture already charged each route plus a conservative comma.
        # Joining into [] needs one fewer comma. Keep the native conservative
        # projected charge, without serializing any old static facts again.
        route_bytes = runtime.fetch("evidence_bytes")
        route_bytes -= 1 if static_fact_count.zero? && !runtime.fetch("facts").empty?
        fact_bytes += route_bytes
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
        fact_bytes, links = append_observations(result, effective, "callback", callbacks, fact_bytes, links)
        result.fetch("evidence_accounting")["fact_bytes_upper_bound"] = fact_bytes
      end
      if @source_comprehension
        require_relative "source_comprehension_observer"
        observations = SourceComprehensionObserver.new(
          limits: effective.merge(max_facts: effective[:max_facts] - result.fetch("facts").length),
          evidence_budget: MAX_EVIDENCE_BYTES - fact_bytes
        ).call(**@source_comprehension)
        fact_bytes, = append_observations(result, effective, "source_comprehension", observations, fact_bytes, links,
          { "root" => File.expand_path(@root) })
        result.fetch("evidence_accounting")["fact_bytes_upper_bound"] = fact_bytes
      end
      raise LimitError, "Capture exceeds max_facts" if result["facts"].length > effective[:max_facts]
      raise LimitError, "Capture exceeds max_diagnostics" if result["diagnostics"].length > effective[:max_diagnostics]

      result
    end

    private

    def source_comprehension_context(value)
      exact = Object.instance_method(:instance_of?)
      return nil if exact.bind_call(value, NilClass)
      unless exact.bind_call(value, Hash) && Hash.instance_method(:size).bind_call(value) == 2 &&
          Hash.instance_method(:key?).bind_call(value, :models) && Hash.instance_method(:key?).bind_call(value, :stop_before)
        raise InvalidInput, "Source comprehension requires exactly models and stop_before"
      end
      models = Hash.instance_method(:fetch).bind_call(value, :models)
      boundary = Hash.instance_method(:fetch).bind_call(value, :stop_before)
      unless exact.bind_call(models, Array) && Array.instance_method(:length).bind_call(models) <= 100_000 &&
          (exact.bind_call(boundary, Class) || exact.bind_call(boundary, Module))
        raise InvalidInput, "Source comprehension requires explicit loaded classes and a stop boundary"
      end
      copy = []
      Array.instance_method(:each).bind_call(models) do |model|
        raise InvalidInput, "Source comprehension model must be a loaded Class" unless exact.bind_call(model, Class)
        copy << model
      end
      { models: copy.freeze, stop_before: boundary }.freeze
    end

    # Advisory native context only; Store independently validates actual facts.
    # This path is for this package's explicit schema3 native capture, not legacy
    # caller publication. No full-static JSON sizing fallback is permitted.
    def native_evidence_bytes(result)
      hint = result["evidence_accounting"]
      unless result["schema_version"].is_a?(Integer) && result["schema_version"] == 3 && hint.is_a?(Hash) &&
          hint.size == 2 && hint.key?("schema_version") && hint.key?("fact_bytes_upper_bound") &&
          hint["schema_version"].is_a?(Integer) && hint["schema_version"] == 3 &&
          hint["fact_bytes_upper_bound"].is_a?(Integer) && hint["fact_bytes_upper_bound"] >= 2
        raise InvalidInput, "Missing or invalid native schema3 evidence accounting"
      end
      bytes = hint.fetch("fact_bytes_upper_bound")
      raise LimitError, "Capture fact evidence exceeds the 64 MiB payload budget" if bytes > MAX_EVIDENCE_BYTES
      bytes
    end

    def append_observations(result, effective, family, observation, fact_bytes, links, additional_request_fields = {})
      added = Native.call(additional_request_fields.merge("op" => "#{family}_batch", "observation" => observation, "context" => {
        "limits" => effective.slice(:max_facts, :max_links, :max_entries, :max_diagnostics),
        "facts" => result.fetch("facts").length, "links" => links,
        "diagnostics" => result.fetch("diagnostics").length, "fact_bytes" => fact_bytes,
        "schema_version" => result.fetch("schema_version")
      }))
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
