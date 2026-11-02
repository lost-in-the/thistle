# frozen_string_literal: true

# AUTHORED UNRUN. Root alone supplies a finite installed producer admission.
raise 'Explicit model-reading producer admission required' unless ENV['THISTLE_MODEL_READING_INSTALLED'] == '1'
gem 'rails', '= 8.1.4'
require 'rails'
require 'active_record/railtie'
require 'active_support/concern'
require 'thistle'
require 'fileutils'
require 'json'
require 'digest'
raise 'Wrong framework' unless Rails.version == '8.1.4'
raise 'Expected one new public fixture directory' unless ARGV.length == 1 && !File.exist?(ARGV[0])
home = File.realpath(ENV.fetch('GEM_HOME'))
raise 'Checkout core loaded' unless File.realpath(Gem.loaded_specs.fetch('thistle').full_gem_path).start_with?(home + '/')
work = File.expand_path(ARGV.fetch(0))
Dir.mkdir(work, 0700)
root = File.join(work, 'app_source')
Dir.mkdir(root, 0700)
FileUtils.cp_r(File.join(__dir__, 'app'), root)
FileUtils.mkdir_p(File.join(root, 'config'))
File.write(File.join(root, 'config/database.yml'), "#{Rails.env}:\n  adapter: sqlite3\n  database: ':memory:'\n")
class ModelReadingFixtureApp < Rails::Application
  config.eager_load = false
  config.secret_key_base = 'public-fixture-only-not-a-real-secret'
  config.hosts = ['fixture.example.invalid']
  config.logger = Logger.new(File::NULL)
end
ModelReadingFixtureApp.config.root = root
app = ModelReadingFixtureApp.initialize!
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:orders) do |t|
    t.integer :user_id
    t.boolean :receipt_enabled, default: false, null: false
    t.string :receipt_state, default: 'pending'
  end
  create_table(:users) { |t| t.string :email }
  create_table(:line_items) { |t| t.integer :order_id; t.integer :quantity, default: 1 }
end
%w[application_record concerns/receipt_policy user order line_item].each { |name| require File.join(root, 'app/models', "#{name}.rb") }
# No records are saved. The callback condition/body and ReceiptJob never run.
raise 'Unexpected job runtime' if Object.const_defined?(:ReceiptJob, false)
capture = Thistle::Capture.new(root: root, rails: app,
  source_comprehension: { models: [Order], stop_before: ActiveRecord::Base }).call
store = File.join(work, 'store')
saved_a = Thistle::Store.new(store).publish(capture).fetch('generation')
registered = Order._save_callbacks.to_a
schedule_position = registered.index { |callback| callback.filter == :schedule_receipt }
raise 'Fixture callback must require full recovery beyond compact8' unless schedule_position && schedule_position >= 8
raise 'Fixture must contain more than8 direct methods' unless Order.instance_methods(false).length > 8
# Independent framework oracle, after A; do not prime columns to fix a capture.
raw_columns = Order.columns.map do |column|
  raw = column.default
  primitive = [NilClass, TrueClass, FalseClass, String, Integer, Float].any? { |type| raw.instance_of?(type) }
  tagged = column.default_function ? { 'kind' => 'expression' } : (primitive ? { 'kind' => 'literal', 'value' => raw } : { 'kind' => 'opaque' })
  { 'name' => column.name, 'type' => column.type.to_s, 'sql_type' => column.sql_type, 'null' => column.null, 'default' => tagged }
end
source_sha256 = Dir.glob(File.join(root, 'app/models/**/*.rb')).sort.to_h { |path| [path.delete_prefix(root + '/'), Digest::SHA256.file(path).hexdigest] }
partial = Marshal.load(Marshal.dump(capture))
partial.fetch('coverage').each { |row| row['status'] = 'partial' if row['family'] == 'ruby_declarations' }
saved_partial = Thistle::Store.new(store).publish(partial).fetch('generation')
path = File.join(root, 'app/models/order.rb')
File.write(path, File.read(path).sub('saved_a', 'current_b'))
saved_b = Thistle.capture(root: root, output: store).fetch('generation')
raise 'CURRENT did not advance' unless [saved_a, saved_partial, saved_b].uniq.length == 3
native = $LOADED_FEATURES.find { |path| path.match?(%r{/thistle/thistle_native\.(so|bundle|dll)\z}) }
raise 'Installed native missing' unless native
puts JSON.generate('store' => store, 'root' => root, 'saved_a' => saved_a, 'partial' => saved_partial, 'current_b' => saved_b,
  'rails_version' => Rails.version, 'raw_order_columns' => raw_columns, 'source_sha256' => source_sha256,
  'schedule_registered_position' => schedule_position,
  'native_path' => native, 'native_sha256' => Digest::SHA256.file(native).hexdigest,
  'scope' => 'public fixture producer; conditions/callbacks/job execution unknown; no served/person acceptance')
