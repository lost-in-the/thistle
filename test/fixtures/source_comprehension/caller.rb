# frozen_string_literal: true
module SourceComprehensionFixture
  class LabelReader
    def read(order)
      order.direct_label
    end
  end
end
