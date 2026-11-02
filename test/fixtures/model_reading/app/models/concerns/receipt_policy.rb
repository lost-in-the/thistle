# frozen_string_literal: true
module ReceiptPolicy
  extend ActiveSupport::Concern

  def schedule_receipt
    ReceiptJob.perform_later(id)
  end
end
