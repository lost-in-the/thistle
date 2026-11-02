# frozen_string_literal: true
require 'rails'
require 'action_controller/railtie'
require 'active_record'
require 'active_support/concern'
require 'logger'
require 'stringio'

module SourceComprehensionFixture
  def self.boot(root)
    app = Class.new(Rails::Application).new
    app.config.root = root
    app.config.eager_load = false
    app.config.secret_key_base = 'source-comprehension-public-fixture-only' * 8
    app.config.logger = Logger.new(StringIO.new)
    app.initialize!
    %w[parent concerns order caller].each { |name| load File.join(root, "#{name}.rb") }
    # No records/DB/schema are fabricated. Existing ModelObserver records the
    # unavailable schema family; callback registration is genuine Rails.
    Order.table_name = 'orders'
    Order.primary_key = 'id'
    app
  end
end
