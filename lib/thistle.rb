# frozen_string_literal: true

require_relative "thistle/version"
require_relative "thistle/errors"
require_relative "thistle/native"
require_relative "thistle/store"
require_relative "thistle/reader"

module Thistle
  autoload :Capture, File.expand_path("thistle/capture", __dir__)

  def self.capture(root:, output:, rails: nil, limits: {}, source_comprehension: nil, job_mail: nil)
    root = Native.path(root)
    output = Native.path(output)
    if rails || !source_comprehension.nil? || !Object.instance_method(:instance_of?).bind_call(job_mail, NilClass)
      Store.new(output).publish(Capture.new(root: root, rails: rails, limits: limits,
        source_comprehension: source_comprehension, job_mail: job_mail).call)
    else
      Native.call("op" => "capture_publish", "root" => root, "path" => output, "limits" => Capture.copy_limits(limits))
    end
  end
end
