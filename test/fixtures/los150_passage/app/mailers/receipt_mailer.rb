class ReceiptMailer < ActionMailer::Base
  def receipt(order_id)
    @order_id = order_id
    mail(to: 'public-fixture@example.invalid', from: 'fixture@example.invalid', subject: 'Receipt',
      template_path: 'receipt_mailer', template_name: 'receipt')
  end
end
