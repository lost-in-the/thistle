# frozen_string_literal: true

require "digest"
require "json"

module Thistle
  # Observes the supplied application's route set. It does not boot, reload,
  # eager-load or execute a request. The caller owns application authority.
  class RailsCapture
    def initialize(app:, limits:, evidence_budget: Capture::MAX_EVIDENCE_BYTES)
      @app = app
      @limits = limits
      @evidence_budget = evidence_budget
    end

    def call
      facts = []
      diagnostics = []
      failed = false
      links = 0
      evidence_bytes = 0
      capture = proc do
        @app.routes.routes.each_with_index do |route, index|
          raise Capture::LimitError, "Runtime route set exceeds max_routes" if index >= @limits[:max_routes]
          raise Capture::LimitError, "Combined capture exceeds max_facts" if facts.length >= @limits[:max_facts]

          begin
            fact = route_fact(route, index)
            links += fact.fetch("links").length
            raise Capture::LimitError, "Combined capture exceeds max_links" if links > @limits[:max_links]

            evidence_bytes += JSON.generate(fact).bytesize + 1
            raise Capture::LimitError, "Combined capture fact evidence exceeds the 64 MiB payload budget" if evidence_bytes > @evidence_budget

            facts << fact
          rescue StandardError => error
            raise if error.is_a?(Capture::Error)

            failed = true
            diagnostics << {
              "code" => "route_unavailable",
              "message" => "Route #{index} could not be represented (#{error.class.name}); route implementation details were not serialized"
            }
            raise Capture::LimitError, "Runtime diagnostics exceed max_diagnostics" if diagnostics.length > @limits[:max_diagnostics]
          end
        end
      end
      if @app.respond_to?(:executor)
        @app.executor.wrap(&capture)
      else
        capture.call
      end
      {
        "facts" => facts, "diagnostics" => diagnostics,
        "rails_version" => defined?(Rails::VERSION::STRING) ? Rails::VERSION::STRING : nil,
        "coverage" => [
          {
            "family" => "rails_routes", "status" => failed ? "partial" : "complete",
            "scope" => "Ordered top-level runtime route entries: verb, path, helper name and controller/action defaults",
            "reason" => failed ? "Some route entries could not be represented; see diagnostics" : nil
          },
          {
            "family" => "rails_route_resolution", "status" => "unavailable",
            "scope" => "Mounted engine internals, arbitrary constraints, request recognition and executed controller behavior",
            "reason" => "No request was executed; route presence is not proof that it matches a particular request"
          },
          {
            "family" => "runtime_source_coherence", "status" => "unavailable",
            "scope" => "Loaded application epoch versus captured source bytes",
            "reason" => "This is a live observation supplied by the caller. No immutable boot inputs or validated mutation sequence were provided; runtime facts have no asserted source location"
          }
        ]
      }
    rescue Capture::Error
      raise
    rescue StandardError => error
      {
        "facts" => [],
        "diagnostics" => [{ "code" => "rails_capture_failed", "message" => "Runtime route capture failed (#{error.class.name})" }],
        "rails_version" => defined?(Rails::VERSION::STRING) ? Rails::VERSION::STRING : nil,
        "coverage" => [{ "family" => "rails_routes", "status" => "unavailable", "scope" => "live application route set", "reason" => "Capture failed; this is not an empty successful route set" }]
      }
    end

    private

    def route_fact(route, index)
      defaults = route.defaults
      controller = plain_string(defaults[:controller])
      action = plain_string(defaults[:action])
      route_name = plain_string(route.name)
      verb = route.verb.is_a?(Regexp) ? route.verb.source : plain_string(route.verb)
      path = plain_string(route.path.spec.to_s)
      endpoint = [controller, action].compact.join("#")
      name = [verb.to_s.empty? ? "ANY" : verb, path, endpoint.empty? ? nil : endpoint].compact.join(" ")
      raise Capture::LimitError, "Runtime route label exceeds 4096 bytes" if name.bytesize > 4_096
      {
        "id" => Digest::SHA256.hexdigest(JSON.generate(["rails_route", index, verb, path, controller, action, route_name])),
        "kind" => "route", "name" => name, "path" => nil, "location" => nil,
        "evidence" => "runtime",
        "attributes" => {
          "order" => index, "verb" => verb, "route_path" => path,
          "route_name" => route_name, "controller" => controller, "action" => action,
          "source_status" => "unavailable", "coherence" => "unknown"
        },
        "links" => endpoint.empty? ? [] : [{ "relation" => "routes_to", "target" => endpoint, "resolution" => "unresolved" }]
      }
    end

    def plain_string(value)
      return nil if value.nil?
      raise TypeError, "Expected a plain route string" unless value.is_a?(String) || value.is_a?(Symbol)

      string = value.to_s.encode(Encoding::UTF_8)
      raise TypeError, "Route string exceeds 8192 bytes" if string.bytesize > 8_192
      string
    end
  end
end
