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

    def self.call(request)
      result = JSON.parse(request_raw(JSON.generate(request, allow_nan: false, max_nesting: 64)))
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
