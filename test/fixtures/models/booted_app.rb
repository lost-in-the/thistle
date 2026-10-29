# frozen_string_literal: true

require 'rails'
require 'action_controller/railtie'
require 'active_record'
require 'logger'
require 'stringio'

module ModelFixture
  def self.boot(root)
    app = Class.new(Rails::Application).new
    app.config.root = root
    app.config.eager_load = false
    app.config.secret_key_base = 'model-fixture-only' * 8
    app.config.logger = Logger.new(StringIO.new)
    app.initialize!
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table(:orders) { |t| t.string :type; t.string :state, null: false, default: 'new' }
      create_table(:items) { |t| t.integer :order_id; t.integer :product_id }
      create_table(:payments) { |t| t.integer :order_id; t.string :subject_type; t.integer :subject_id }
      create_table(:products) { |t| t.string :name }
    end
    # Loaded by the fixture owner, never by Thistle. Independent known answers are
    # in the test, not computed from the observer's reflection output.
    load File.join(__dir__, 'records.rb')
    app
  end
end
