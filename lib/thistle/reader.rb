# frozen_string_literal: true

require_relative "native"

module Thistle
  class Reader
    attr_reader :manifest, :generation

    def initialize(path, generation: nil)
      opened = Native.call("op" => "open", "path" => File.expand_path(path.to_s), "generation" => generation)
      @handle = opened.fetch("handle")
      @generation = opened.fetch("generation").freeze
      @manifest = deep_freeze(opened.fetch("manifest"))
      ObjectSpace.define_finalizer(self, self.class.finalizer(@handle))
    end

    def self.finalizer(handle)
      proc { Native.call("op" => "close", "handle" => handle) rescue nil }
    end

    def close
      return if @closed
      Native.call("op" => "close", "handle" => @handle)
      @closed = true
      ObjectSpace.undefine_finalizer(self)
      nil
    end

    def facts
      request("facts")
    end

    def fact(id)
      request("fact", "id" => id)
    end

    def search(query, limit: 50)
      request("find", "query" => query, "limit" => limit)
    end

    def find(query, limit: 50)
      search(query, limit: limit).fetch("results")
    end

    def source(id)
      request("source", "id" => id)
    end

    def links(id)
      request("links", "id" => id)
    end

    def check
      request("check")
    end

    private

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
