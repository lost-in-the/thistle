class ReceiptJob < ActiveJob::Base
  def perform(order_id)
    ::ReceiptMailer.receipt(order_id).deliver_later
  end
end
