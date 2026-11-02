# frozen_string_literal: true
class Order < ApplicationRecord
  belongs_to :user, optional: true
  after_create :schedule_receipt

  def schedule_receipt(delay: false)
    ReceiptJob.perform_later(id) if normalize_delay(delay)
  end

  def normalize_delay(value)
    !!value
  end
end
