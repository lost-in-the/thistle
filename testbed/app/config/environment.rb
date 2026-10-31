# frozen_string_literal: true

require_relative 'application'
ReusableHost::Application.initialize!
raise 'Rails/AR cohort drift' unless Rails.version == '7.1.6' && ActiveRecord::VERSION::STRING == '7.1.6'
# No database.yml or URL interpolation: the private file is never rendered,
# included in capture, or passed in argv. The controller admits this socket first.
database = JSON.parse(File.read('/private/database.json'))
raise 'Unexpected app schema' unless database.fetch('database') == 'thistle_los139_app_v1'
raise 'TCP database connection refused' unless database.fetch('socket') == '/socket/mysql.sock'
raise 'Database config keys refused' unless (database.keys - %w[adapter database username password socket encoding]).empty?
raise 'Wrong adapter' unless database.fetch('adapter') == 'mysql2'
ActiveRecord::Base.establish_connection(database)
require_relative '../app/models/order'
require_relative '../app/models/item'
require_relative '../app/controllers/orders_controller'
require_relative '../app/services/inspection'
