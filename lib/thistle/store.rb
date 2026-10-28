# frozen_string_literal: true

require_relative "native"

module Thistle
  class Store
    def initialize(path)
      @path = Native.path(path)
    end

    def publish(capture)
      Native.call("op" => "publish", "path" => @path, "capture" => capture)
    end
  end
end
