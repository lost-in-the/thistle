# frozen_string_literal: true

require_relative "thistle/version"
require_relative "thistle/errors"
require_relative "thistle/native"
require_relative "thistle/store"
require_relative "thistle/reader"

module Thistle
  autoload :Capture, File.expand_path("thistle/capture", __dir__)

  def self.capture(root:, output:, rails: nil, limits: {})
    root = Native.path(root)
    output = Native.path(output)
    if rails
      Store.new(output).publish(Capture.new(root: root, rails: rails, limits: limits).call)
    else
      Native.call("op" => "capture_publish", "root" => root, "path" => output, "limits" => Capture.copy_limits(limits))
    end
  end
end
