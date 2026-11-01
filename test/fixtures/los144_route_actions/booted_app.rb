# frozen_string_literal: true

# UNRUN real Rails producer. Only Root's admitted installed lane may boot it.
gem 'rails', '= 8.1.4'
require 'rails'
require 'action_controller/railtie'
module RouteActionsFixture
  class Application < Rails::Application
    config.root = __dir__
    config.eager_load = false
    config.secret_key_base = 'public-los144-fixture-key-not-a-credential'
    config.logger = Logger.new(File::NULL)
    config.hosts.clear
  end
  def self.boot
    app = Application.instance
    app.initialize!
    app.routes.draw do
      get '/orders', to: 'orders#index', as: :orders
      get '/all-orders', to: 'orders#index', as: :all_orders
      get '/orders/:id', to: 'orders#show', constraints: {id: /[0-9]+/}, as: :order
      scope module: :legacy do
        get '/admin-orders', to: '/admin/orders#index', as: :admin_orders
      end
      get '/missing', to: 'orders#missing', as: :missing_action
      get '/class-only', to: 'orders#class_only', as: :class_only
      get '/inherited', to: 'orders#inherited', as: :inherited_action
      get '/custom', to: 'api/orders#index', as: :custom_acronym
      get '/rack', to: ->(*) { raise 'Route endpoint must never execute during capture/query' }, as: :rack_endpoint
      get '/redirect', to: redirect('/orders'), as: :redirect_endpoint
    end
    app
  end
end
