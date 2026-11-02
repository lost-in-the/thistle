class Order < ActiveRecord::Base
  after_save :queue_receipt, if: -> { raise 'Never evaluate a save condition' }

  def queue_receipt
    ::ReceiptJob.perform_later(id)
  end
end
