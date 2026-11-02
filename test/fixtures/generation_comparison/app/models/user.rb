# frozen_string_literal: true
class User < ApplicationRecord
  has_many :orders
end

# Two recorded declarations deliberately share one logical label. Neither
# declaration may be silently chosen as the cross-generation representative.
class DuplicateIdentity
  def first; end
end
class DuplicateIdentity
  def second; end
end
