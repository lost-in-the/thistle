# frozen_string_literal: true

class Order < ActiveRecord::Base
  self.table_name = 'orders'
  has_many :items, inverse_of: :order
  before_save :normalize_reference

  private

  def normalize_reference
    self.reference = reference.strip
  end
end
