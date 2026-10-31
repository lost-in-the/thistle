# frozen_string_literal: true

class ReceiptMailer < ActionMailer::Base
  def receipt(recipient_id)
    @recipient = recipient_id
    mail(to: 'reader@example.test', from: 'sender@example.test', subject: 'Receipt',
      template_path: 'receipt_mailer', template_name: 'receipt')
  end

  def archive(recipient_id)
    @recipient = recipient_id
    mail(template_path: 'receipt_mailer', template_name: 'receipt')
  end

  def dynamic_receipt(recipient_id)
    @template_name = recipient_id
    mail(template_path: 'receipt_mailer', template_name: @template_name)
  end

  def self.method_missing(*) = raise('LOS148 mailer action/delivery dispatched')
end
