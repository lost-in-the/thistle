# frozen_string_literal: true

module HostDatabase
  SCHEMA = 'los139-schema-v1'
  SEED = 'los139-seed-v1'
  TABLES = %w[host_metadata items orders].freeze
  module_function

  def signature(connection)
    TABLES.to_h do |table|
      [table, { 'columns' => connection.select_rows("SHOW COLUMNS FROM #{table}"),
        'indexes' => connection.indexes(table).map { |i| [i.name, i.columns, i.unique] }.sort,
        'foreign_keys' => connection.foreign_keys(table).map { |f| [f.name, f.to_table, f.column, f.primary_key] }.sort }]
    end
  end

  def verify(initialize_empty: false)
    connection = ActiveRecord::Base.connection
    uuid = connection.select_value('SELECT @@server_uuid')
    raise 'Database UUID drift' unless uuid == HostProfile.config.fetch('server_uuid')
    raise 'Server version drift' unless connection.select_value('SELECT VERSION()') == '8.4.13'
    tables = connection.tables.sort
    if initialize_empty
      # A one-time, explicit new-app initialization. DDL is not atomic in MySQL.
      # A partial failure remains partial and the next attempt refuses it.
      raise 'New app schema is not empty' unless tables.empty?
      require Rails.root.join('db/migrate/001_create_fixture').to_s
      require Rails.root.join('db/seeds').to_s
      ActiveRecord::Migration.verbose = false
      CreateFixture.new.up
      FixtureSeed.create(connection)
      HostProfile.write('/work/schema.json', signature(connection))
    end
    raise 'App table drift' unless connection.tables.sort == TABLES
    expected = JSON.parse(File.read(Rails.root.join('expected.json')))
    expected.fetch('columns').each do |table, columns|
      actual = connection.columns(table).map { |c| [c.name, c.type.to_s, c.null] }.sort
      raise 'Fixture columns differ' unless actual == columns.sort
    end
    raise 'Schema signature missing or changed' unless signature(connection) == JSON.parse(File.read('/work/schema.json'))
    raise 'Schema/seed version drift' unless connection.select_rows('SELECT schema_version, seed_version FROM host_metadata') == [[SCHEMA, SEED]]
    raise 'Retained seed changed' unless connection.select_rows('SELECT id, reference FROM orders ORDER BY id') == expected.fetch('orders')
    raise 'Retained items changed' unless connection.select_rows('SELECT id, order_id, quantity FROM items ORDER BY id') == expected.fetch('items')
    { 'server_uuid' => uuid, 'schema' => SCHEMA, 'seed' => SEED, 'orders' => 1, 'items' => 2,
      'signature' => signature(connection) }
  end
end
