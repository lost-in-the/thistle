# frozen_string_literal: true
module SourceComprehensionFixture
  class Order < Parent
    include Tagged
    include Module.new {
      def anonymous_label
        'anonymous contribution before Tagged and Parent'
      end
    }
    prepend Decorated
    include Optional if false

    def direct_label
      tag_text
    end

    def display_name
      'order display'
    end

    def duplicate_label
      'earlier saved candidate'
    end

    def duplicate_label
      'later loaded body'
    end

    # A builtin-backed method has no physical Ruby source body to recover.
    define_method(:native_hash, Object.instance_method(:hash))
    # Visibility-only entry for a builtin body beyond the explicit stop boundary.
    private :itself
  end
end
