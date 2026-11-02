# frozen_string_literal: true

require_relative "native"

module Thistle
  class Reader
    attr_reader :manifest, :generation

    def initialize(path, generation: nil)
      constructed = false
      # Defer asynchronous exceptions until the acquired native resource has an
      # owner. The outer ensure also covers a pending exception delivered as the
      # interrupt mask is lifted, before initialize can return to its caller.
      Thread.handle_interrupt(Object => :never) do
        opened = Native.call("op" => "open", "path" => Native.path(path), "generation" => generation)
        @handle = opened.fetch("handle")
        @generation = opened.fetch("generation").freeze
        @manifest = deep_freeze(opened.fetch("manifest"))
        ObjectSpace.define_finalizer(self, self.class.finalizer(@handle))
      end
      constructed = true
    ensure
      unless constructed || !@handle
        Thread.handle_interrupt(Object => :never) do
          begin
            Native.call("op" => "close", "handle" => @handle)
          ensure
            @closed = true
            ObjectSpace.undefine_finalizer(self)
          end
        end
      end
    end

    def self.finalizer(handle)
      proc { Native.call("op" => "close", "handle" => handle) rescue nil }
    end

    def close
      Thread.handle_interrupt(Object => :never) do
        return if @closed
        Native.call("op" => "close", "handle" => @handle)
        @closed = true
        ObjectSpace.undefine_finalizer(self)
      end
      nil
    end

    def facts
      request("facts")
    end

    def fact(id)
      request("fact", "id" => id)
    end

    # Fixed saved identity only: no attributes, links, source or candidate lookup.
    def fact_identity(id)
      request("fact_identity", "id" => id)
    end

    def search(query, limit: 50)
      request("find", "query" => query, "limit" => limit)
    end

    def find(query, limit: 50)
      search(query, limit: limit).fetch("results")
    end

    # Literal source and explicitly allowlisted metadata, with coverage and spans.
    # Legacy search/find retain their name discovery contract.
    def search_evidence(query, limit: 50, kind: nil, path: nil, domain: nil)
      request("find_evidence", "query" => query, "limit" => limit,
        "kind" => kind, "path_prefix" => path, "domain" => domain)
    end

    def source_file(path)
      request("source_file", "file_path" => path)
    end

    # Explicit point-in-time comparison with the recorded digest. Never expand
    # a root here: nil and relative roots must retain their native semantics.
    def source_freshness(file_path, workspace_root: nil, max_bytes: 2_097_152)
      request("source_freshness", "file_path" => file_path,
        "workspace_root" => workspace_root, "max_bytes" => max_bytes)
    end

    # Rust compares two already pinned Readers; neither store is reopened here.
    def generation_comparison(other, selection:, family: "entity", direction: "incoming", limit: 8, max_bytes: 32768, cursor: nil)
      raise Error, "Other comparison version must be a Reader" unless other.is_a?(Reader)
      request("generation_comparison", "other_handle" => other.send(:comparison_handle),
        "selection" => selection, "family" => family, "direction" => direction,
        "limit" => limit, "max_bytes" => max_bytes, "cursor" => cursor)
    end

    def source(id)
      request("source", "id" => id)
    end

    def links(id)
      request("links", "id" => id)
    end

    def references(id, direction: "outgoing", limit: 50, cursor: nil, candidate_link: nil)
      request("references", "id" => id, "direction" => direction, "limit" => limit,
        "cursor" => cursor, "candidate_link" => candidate_link)
    end

    def callback_effects(id, limit: 50)
      request("callback_effects", "id" => id, "limit" => limit)
    end

    def model_brief(id, limit: 8, max_bytes: 32768, family: nil, cursor: nil)
      request("model_brief", "id" => id, "limit" => limit, "max_bytes" => max_bytes,
        "family" => family, "cursor" => cursor)
    end

    def model_neighborhood(id, family: 'edges', direction: 'outgoing', type: 'all', candidate: nil, limit: 8, cursor: nil, max_bytes: 32768)
      request('model_neighborhood', 'id' => id, 'family' => family, 'direction' => direction,
        'type' => type, 'candidate' => candidate, 'limit' => limit, 'cursor' => cursor, 'max_bytes' => max_bytes)
    end

    def source_comprehension(id, family: nil, limit: 8, cursor: nil, max_bytes: 32768)
      request("source_comprehension", "id" => id, "family" => family, "limit" => limit,
        "cursor" => cursor, "max_bytes" => max_bytes)
    end

    def job_mail(id, family: nil, limit: 8, cursor: nil, max_bytes: 32768)
      request("job_mail", "id" => id, "family" => family, "limit" => limit,
        "cursor" => cursor, "max_bytes" => max_bytes)
    end

    def check
      request("check")
    end

    def route_actions(id, limit: 8, cursor: nil, max_bytes: 32768)
      request("route_actions", "id" => id, "limit" => limit,
        "cursor" => cursor, "max_bytes" => max_bytes)
    end

    def passage(id, action: nil, family: 'sequence', limit: 8, cursor: nil, max_bytes: 32768)
      request('passage', 'id' => id, 'action' => action, 'family' => family,
        'limit' => limit, 'cursor' => cursor, 'max_bytes' => max_bytes)
    end

    private

    def comparison_handle
      raise Error, "Reader has been closed" if @closed
      @handle
    end

    def request(operation, arguments = {})
      raise Error, "Reader has been closed" if @closed
      Native.call(arguments.merge("op" => operation, "handle" => @handle))
    end

    def deep_freeze(value)
      case value
      when Hash then value.each { |key, item| key.freeze; deep_freeze(item) }
      when Array then value.each { |item| deep_freeze(item) }
      end
      value.freeze
    end
  end
end
