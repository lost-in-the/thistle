# frozen_string_literal: true
require 'rails'
require 'action_controller/railtie'
require 'active_record'
require 'logger'
require 'stringio'

module BriefFixture
  def self.boot(root)
    app = Class.new(Rails::Application).new
    app.config.root = root
    app.config.eager_load = false
    app.config.secret_key_base = 'brief-fixture-only' * 8
    app.config.logger = Logger.new(StringIO.new)
    app.initialize!
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table(:orders) { |t| t.string :state, null: false; t.string :'note_雪' }
      create_table(:items) { |t| t.integer :order_id }
    end
    load File.join(root, 'records.rb')
    app
  end
end
