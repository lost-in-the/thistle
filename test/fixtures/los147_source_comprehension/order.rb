# frozen_string_literal: true
module Los147
  class Order < Parent
    include Tagged
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
  end
end
