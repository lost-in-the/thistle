# frozen_string_literal: true

# AUTHORED UNRUN. Root's separately admitted real installed producer only.
gem 'rails', '= 8.1.4'
require 'rails'
require 'active_record/railtie'
require 'thistle'
require 'fileutils'
require 'json'
raise 'Wrong framework' unless Rails.version == '8.1.4'
raise 'Expected a new public fixture directory' unless ARGV.length == 1 && !File.exist?(ARGV[0])
work = File.expand_path(ARGV.fetch(0))
Dir.mkdir(work, 0700)
root = File.join(work, 'app_source')
Dir.mkdir(root, 0700)
FileUtils.cp_r(File.join(__dir__, 'app'), root)
# Public SQLite memory configuration MUST precede Rails' Active Record lazy load.
FileUtils.mkdir_p(File.join(root, 'config'))
File.write(File.join(root, 'config/database.yml'), "#{Rails.env}:\n  adapter: sqlite3\n  database: ':memory:'\n")
class NeighborhoodFixtureApp < Rails::Application
  config.eager_load = false
  config.secret_key_base = 'public-fixture-only-not-a-real-secret'
  config.hosts = ['fixture.example.invalid']
  config.logger = Logger.new(File::NULL)
end
NeighborhoodFixtureApp.config.root = root
app = NeighborhoodFixtureApp.initialize!
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:orders) do |t|
    t.integer :user_id
    t.integer :subject_id
    t.string :subject_type
    t.boolean :enabled, default: false, null: false
    t.integer :quantity, default: 0
    t.string :note, default: ''
    t.string :nullable_note, default: nil
    t.datetime :generated_at, default: -> { 'CURRENT_TIMESTAMP' }
  end
  create_table(:items) { |t| t.integer :order_id; t.integer :user_id }
  create_table(:users) { |t| t.integer :order_id }
  create_table(:admin_users) { |t| t.string :name }
  create_table(:attachments) { |t| t.integer :attachable_id; t.string :attachable_type }
end
%w[application_record user duplicate_user admin/user order item attachment].each { |name| require File.join(root, 'app/models', "#{name}.rb") }
require File.join(root, 'app/services/report_builder.rb')
raise 'Ghost loaded unexpectedly' if Object.const_defined?(:NotLoadedGhost, false)
# Independent raw adapter oracle: preserve actual primitive types; never typecast
# raw SQLite defaults into Ruby boolean/integer values to satisfy answer cards.
raw_columns = Order.columns.map do |column|
  raw = column.default
  primitive = [NilClass, TrueClass, FalseClass, String, Integer, Float].any? { |klass| raw.instance_of?(klass) }
  tagged = if column.default_function
             { 'kind' => 'expression' }
           elsif primitive
             { 'kind' => 'literal', 'value' => raw }
           else
             { 'kind' => 'opaque' }
           end
  { 'name' => column.name, 'type' => column.type.to_s, 'sql_type' => column.sql_type, 'null' => column.null, 'default' => tagged }
end
capture = Thistle::Capture.new(root: root, rails: app).call
store = File.join(work, 'store')
saved_a = Thistle::Store.new(store).publish(capture).fetch('generation')
partial = Marshal.load(Marshal.dump(capture))
partial.fetch('coverage').each { |row| row['status'] = 'partial' if row['family'] == 'ruby_declarations' }
partial.fetch('coverage').first.merge!('status' => 'partial', 'reason' => 'Intentionally partial public LOS149 fixture derivative')
saved_partial = Thistle::Store.new(store).publish(partial).fetch('generation')
path = File.join(root, 'app/services/report_builder.rb')
File.write(path, File.read(path).sub('saved_a', 'saved_b'))
saved_b = Thistle.capture(root: root, output: store).fetch('generation')
puts JSON.generate({ 'store' => store, 'root' => root, 'saved_a' => saved_a, 'partial' => saved_partial, 'current_b' => saved_b,
  'rails_version' => Rails.version, 'raw_order_columns' => raw_columns, 'ghost_loaded' => false })
