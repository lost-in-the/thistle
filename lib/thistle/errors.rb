# frozen_string_literal: true

module Thistle
  class Error < StandardError
    def code
      return @native_code if @native_code
      self.class.name.split("::").last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
    end
  end

  class InvalidInput < Error; end
  class InvalidSnapshot < Error; end
  class NotFound < Error; end
  class UnsafePath < Error; end
  class LimitExceeded < Error; end
  class Busy < Error; end
  class UnsupportedPlatform < Error; end
end
