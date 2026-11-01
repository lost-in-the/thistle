# frozen_string_literal: true
class Order < ApplicationRecord
  include ReceiptPolicy
  belongs_to :user, optional: true
  has_many :line_items, dependent: :destroy
  after_save :schedule_receipt, if: :receipt_due?

  def receipt_due?
    receipt_enabled && user_id.present?
  end

  def receipt_marker
    'saved_a'
  end
end
