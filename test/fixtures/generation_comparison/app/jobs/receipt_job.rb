# frozen_string_literal: true
class ReceiptJob < ActiveJob::Base
  queue_as :receipts

  def perform(order_id)
    ::Order.find(order_id)
  end
end
