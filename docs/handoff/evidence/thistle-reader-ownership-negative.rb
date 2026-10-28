# frozen_string_literal: true

# Negative-control fixture: the pre-review Reader constructor. This deliberately
# leaks an acquired native reader if interruption or consumer initialization
# fails before the finalizer is attached. Never load this into the product.
module Thistle
  class Reader
    def initialize(path, generation: nil)
      opened = Native.call("op" => "open", "path" => File.expand_path(path.to_s), "generation" => generation)
      @handle = opened.fetch("handle")
      @generation = opened.fetch("generation").freeze
      @manifest = deep_freeze(opened.fetch("manifest"))
      ObjectSpace.define_finalizer(self, self.class.finalizer(@handle))
    end
  end
end
