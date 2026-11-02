# frozen_string_literal: true
module SourceComprehensionFixture
  module Tagged
    extend ActiveSupport::Concern
    included do
      before_save :normalize_tag, if: :tag_ready?
    end

    def tag_text
      'tagged'
    end

    private

    def normalize_tag
      tag_text
    end

    def tag_ready?
      false
    end
  end

  module Decorated
    def display_name
      "decorated #{super}"
    end
  end

  module Optional
    def optional_label
      'not registered in this fixture'
    end
  end
end
