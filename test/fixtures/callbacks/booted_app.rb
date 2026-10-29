# frozen_string_literal: true

require 'rails'
require 'action_controller/railtie'
require 'active_record'
require 'logger'
require 'stringio'

module CallbackFixture
  def self.boot(root = __dir__)
    return @app if @app
    app = Class.new(Rails::Application).new
    app.config.root = root
    app.config.eager_load = false
    app.config.secret_key_base = 'callback-harmless-fixture-only' * 8
    app.config.logger = Logger.new(StringIO.new)
    app.initialize!
    require File.join(File.expand_path(root), 'records')
    @app = app
  end
end
