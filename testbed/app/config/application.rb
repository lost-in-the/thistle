# frozen_string_literal: true

require 'rails'
require 'active_record'
require 'action_controller/railtie'
require 'logger'

module ReusableHost
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.load_defaults 7.1
    config.eager_load = false
    config.enable_reloading = false
    config.secret_key_base = 'testbed-only-no-user-sessions-' * 4
    config.hosts = ['localhost', '127.0.0.1']
    config.logger = Logger.new(File::NULL)
    config.paths['log'] = '/work/rails.log'
    config.paths['tmp'] = '/work/tmp'
  end
end
