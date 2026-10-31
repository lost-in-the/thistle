# frozen_string_literal: true

class ReceiptJob < ApplicationJob
  discard_on MissingRecipient do |_job, _error|
    raise 'LOS148 discard handler dispatched'
  end
  rescue_from 'UnloadedDeliveryError', with: :record_failure

  # Install after registration, so setup itself uses the real framework DSL.
  def self.rescue_handlers = raise('LOS148 public registry override dispatched')

  def perform(recipient_id)
    ReceiptMailer.receipt(recipient_id).deliver_later if recipient_id
    ReceiptMailer.archive(recipient_id).deliver_later
    MissingMailer.digest(recipient_id).deliver_later
    ReceiptMailer.dynamic_receipt(recipient_id).deliver_later
    raise 'LOS148 job dispatched'
  end

  private

  def record_failure(_error) = raise('LOS148 rescue handler dispatched')
end

class RegistryOverrideJob < ApplicationJob
  def self.__class_attr_rescue_handlers = raise('LOS148 private registry override dispatched')
  private_class_method :__class_attr_rescue_handlers
end
