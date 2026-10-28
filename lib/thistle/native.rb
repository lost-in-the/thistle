# frozen_string_literal: true

require "json"
require_relative "errors"
require "thistle/thistle_native"

module Thistle
  module Native
    ERROR_TYPES = {
      "invalid_input" => InvalidInput, "invalid_snapshot" => InvalidSnapshot,
      "not_found" => NotFound, "unsafe_path" => UnsafePath,
      "limit_exceeded" => LimitExceeded, "unsupported_platform" => UnsupportedPlatform
    }.freeze

    def self.path(value)
      if value.nil? || value.to_s.empty?
        raise InvalidInput, "A nonempty filesystem path is required"
      end
      File.expand_path(value.to_s)
    end

    def self.call(request)
      # Native payloads have a 64-level bound; allow headroom for the response
      # envelope so decoding cannot fail after a native resource is acquired.
      result = JSON.parse(request_raw(JSON.generate(request, allow_nan: false, max_nesting: 64)), max_nesting: 128)
      unless result["ok"]
        error = result.fetch("error")
        type = ERROR_TYPES.fetch(error["code"], Error)
        exception = type.new(error.fetch("message"))
        exception.instance_variable_set(:@native_code, error.fetch("code"))
        raise exception
      end
      result.fetch("result")
    end
  end
end
