# frozen_string_literal: true

# Thistle-owned public LOS-148 fixture. No application data or Woods engine code.
class DeliveryTimeout < StandardError; end
class MissingRecipient < StandardError; end

class ApplicationJob < ActiveJob::Base
  retry_on DeliveryTimeout, wait: :polynomially_longer, attempts: 4

  def self.perform_later(*) = raise('Job mail enqueue dispatched')
end
