# frozen_string_literal: true

require 'rails'
require 'action_controller/railtie'
require 'active_record'
require 'logger'
require 'stringio'

module Rails71Fixture
  # Supplied ONLY by the isolated-fixture owner. No provisioning or credentials
  # are embedded here. Connection setup itself requires its own runtime grant.
  def self.boot(database_config:)
    %w[railties activerecord activesupport actionpack].each do |name|
      raise "Genuine #{name} 7.1.6 required" unless Gem.loaded_specs.fetch(name).version.to_s == '7.1.6'
    end
    raise 'Genuine runtime versions required' unless Rails::VERSION::STRING == '7.1.6' && ActiveRecord::VERSION::STRING == '7.1.6'
    raise 'Isolated Mysql2Adapter fixture required' unless database_config.fetch('adapter') == 'mysql2'
    app = Class.new(Rails::Application).new
    app.config.root = __dir__
    app.config.eager_load = false
    app.config.secret_key_base = 'rails71-harmless-fixture-only' * 8
    app.config.logger = Logger.new(StringIO.new)
    app.initialize!
    ActiveRecord::Base.establish_connection(database_config)
    raise 'mysql2 0.5.6 artifact required; fork identity is an external preflight' unless Gem.loaded_specs.fetch('mysql2').version.to_s == '0.5.6'
    require_relative 'records'
    app.routes.draw do
      get '/orders/:id', to: 'orders#show', constraints: { subdomain: 'admin', id: /\d+/ }
      get '/regexp', to: 'orders#regexp', constraints: { subdomain: /admin|staff/i }
      constraints(RouteGuard.new) { get '/object', to: 'orders#object' }
      constraints(->(*) { raise 'route predicate executed' }) do
        get '/opaque', to: 'orders#index'
      end
    end
    def app.eager_load! = raise('eager loading attempted')
    def app.reload_routes! = raise('route reload attempted')
    app
  end
end
