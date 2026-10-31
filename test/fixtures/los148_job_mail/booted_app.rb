# frozen_string_literal: true

# Real framework fixture. Authoring this file does not execute or qualify it.
gem 'rails', '= 8.1.4'
require 'rails'
require 'action_mailer/railtie'
require 'active_job/railtie'

module JobMailFixture
  class Application < Rails::Application
    config.root = __dir__
    config.eager_load = false
    config.secret_key_base = 'public-los148-fixture-key-not-a-credential'
    config.logger = Logger.new(File::NULL)
    config.action_mailer.perform_deliveries = false
  end

  def self.boot
    @app ||= begin
      app = Application.instance
      app.initialize!
      # Explicit loading, owned by fixture setup, never by the observer.
      %w[app/jobs/application_job.rb app/jobs/receipt_job.rb app/mailers/receipt_mailer.rb
        app/mailers/receipt_mailer_reopened.rb app/helpers/receipt_helper.rb].each { |path| require_relative path }
      app
    end
  end
end
