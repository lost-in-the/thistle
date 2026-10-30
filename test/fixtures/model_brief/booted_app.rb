# frozen_string_literal: true
require 'rails'
require 'action_controller/railtie'
require 'active_record'
require 'active_record/connection_adapters/sql_type_metadata'
require 'active_record/connection_adapters/column'
require 'logger'
require 'stringio'

module BriefFixture
  class SchemaPool
    def schema_cache = self
    def columns_hash(table)
      declarations = case table
      when 'orders' then [['id', :integer, false], ['state', :string, false], ['note_雪', :string, true]]
      when 'items' then [['id', :integer, false], ['order_id', :integer, true]]
      else raise 'unexpected fixture table'
      end
      declarations.to_h do |name, type, nullable|
        metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: type.to_s,
          type: type, limit: nil, precision: nil, scale: nil)
        [name, ActiveRecord::ConnectionAdapters::Column.new(name, nil, nil, metadata, nullable)]
      end
    end
  end

  def self.boot(root)
    app = Class.new(Rails::Application).new
    app.config.root = root
    app.config.eager_load = false
    app.config.secret_key_base = 'brief-fixture-only' * 8
    app.config.logger = Logger.new(StringIO.new)
    app.initialize!
    # Real Rails classes/reflections/registry, with an explicit raw-schema test
    # adapter. This fixture validates the saved evidence workflow, not a database
    # adapter; no database dependency, records or schema discovery is needed.
    load File.join(root, 'records.rb')
    pool = SchemaPool.new
    pool.columns_hash('orders') # Fail the producer if fixture schema support is unavailable.
    [Order, Item].each do |model|
      model.primary_key = 'id'
      model.define_singleton_method(:connection_pool) { pool }
    end
    app
  end
end
