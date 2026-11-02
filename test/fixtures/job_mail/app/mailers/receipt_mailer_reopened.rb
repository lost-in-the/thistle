# frozen_string_literal: true

# Both saved declarations remain candidates. Loaded override is not inferred.
class ReceiptMailer
  def archive(recipient_id)
    @recipient = recipient_id
    mail(template_path: 'receipt_mailer', template_name: 'receipt')
  end
end
