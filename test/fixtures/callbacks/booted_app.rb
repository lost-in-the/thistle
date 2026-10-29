# frozen_string_literal: true

require 'rails'
require 'action_controller/railtie'
require 'active_record'
require 'logger'
require 'stringio'

module CallbackFixture
  def self.boot
    return @app if @app
    app = Class.new(Rails::Application).new
    app.config.root = __dir__
    app.config.eager_load = false
    app.config.secret_key_base = 'callback-harmless-fixture-only' * 8
    app.config.logger = Logger.new(StringIO.new)
    app.initialize!
    require_relative 'records'
    @app = app
  end
end
