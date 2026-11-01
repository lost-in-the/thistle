# frozen_string_literal: true

# AUTHORED UNRUN. Root must admit runtime/build/installed resources separately.
gem 'rails', '= 8.1.4'
require 'rails'
require 'active_record/railtie'
require 'active_job/railtie'
require 'thistle'
require 'fileutils'
require 'json'
require 'digest'

raise 'Wrong framework version' unless Rails.version == '8.1.4'
installed = File.realpath(ENV.fetch('THISTLE_FIXTURE_INSTALLED_ROOT'))
loaded = File.realpath(Gem.loaded_specs.fetch('thistle').full_gem_path)
raise 'Checkout Core used' unless loaded.start_with?(installed + File::SEPARATOR)
raise 'Expected one new public directory' unless ARGV.length == 1 && !File.exist?(ARGV[0])
work = File.expand_path(ARGV.fetch(0))
Dir.mkdir(work, 0700)
root = File.join(work, 'app_source')
Dir.mkdir(root, 0700)
FileUtils.cp_r(File.join(__dir__, 'app'), root)
FileUtils.mkdir_p(File.join(root, 'config'))
# Must precede Active Record lazy loading and application initialization.
File.write(File.join(root, 'config/database.yml'), "#{Rails.env}:\n  adapter: sqlite3\n  database: ':memory:'\n")
class GenerationComparisonFixtureApp < Rails::Application
  config.eager_load = false
  config.secret_key_base = 'public-fixture-only-not-a-real-secret'
  config.hosts = ['fixture.example.invalid']
  config.logger = Logger.new(File::NULL)
  config.active_job.queue_adapter = :test
end
GenerationComparisonFixtureApp.config.root = root
# User's file contains multiple explicit declarations. They are captured syntax;
# load it ourselves rather than asking Zeitwerk to resolve those extra names.
Rails.autoloaders.main.ignore(File.join(root, 'app/models/user.rb'))
app = GenerationComparisonFixtureApp.initialize!
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:users) { |t| t.string :email }
  create_table(:orders) { |t| t.integer :user_id; t.boolean :delayed, default: false, null: false; t.string :nullable_note, default: nil }
  create_table(:archived_orders) { |t| t.integer :user_id; t.boolean :delayed, default: true, null: false; t.string :nullable_note, default: nil }
end
%w[application_record user order].each { |name| require File.join(root, 'app/models', "#{name}.rb") }
require File.join(root, 'app/jobs/receipt_job.rb')
retired = File.join(root, 'retired.rb')
File.write(retired, "class RetiredInvestigation\nend\n")
store = File.join(work, 'store')
capture_a = Thistle::Capture.new(root: root, rails: app).call
saved_a = Thistle::Store.new(store).publish(capture_a).fetch('generation')
# Independent raw adapter oracle AFTER capture; preserve its actual typed value
# rather than casting SQLite's default into an expected Ruby boolean.
def delayed_default(table)
  columns = ActiveRecord::Base.connection_pool.schema_cache.columns_hash(table)
  { 'index' => columns.keys.index('delayed'), 'value' => columns.fetch('delayed').default,
    'nullable_index' => columns.keys.index('nullable_note') }
end
default_a = delayed_default('orders')

# Edit the PUBLIC fixture source. This is capture preparation, never a Reader or
# Map request, and no application records/jobs are executed. Loaded definitions
# remain separate from captured bytes; there is no eval/reload of edited source.
path = File.join(root, 'app/models/order.rb')
edited = File.read(path).sub('after_create :schedule_receipt', 'after_create_commit :schedule_receipt')
  .sub('delay: false', 'delay: true').sub('ReceiptJob.perform_later(id)', 'PriorityReceiptJob.perform_later(id)')
  .sub('!!value', 'value == true')
File.write(path, edited)
Order.table_name = 'archived_orders'
File.unlink(retired)
File.write(File.join(root, 'added.rb'), "class AddedInvestigation\nend\n")
File.write(File.join(root, 'unrelated.rb'), "class UnrelatedChange\nend\n")
capture_b = Thistle::Capture.new(root: root, rails: app).call
saved_b = Thistle::Store.new(store).publish(capture_b).fetch('generation')
default_b = delayed_default('archived_orders')
raise 'Default change oracle must be discriminating' if default_a.fetch('value') == default_b.fetch('value')
raise 'Expected same positional column index' unless default_a.fetch('index') == default_b.fetch('index')
partial = Marshal.load(Marshal.dump(capture_b))
partial.fetch('coverage').each { |row| row['status'] = 'partial' if row['family'] == 'source_inventory' }
saved_partial = Thistle::Store.new(store).publish(partial).fetch('generation')
# C is explicitly a different capture. A fresh consumer must still use A/B.
File.write(path, "class CurrentOnlyOrder < ApplicationRecord\nend\n")
saved_c = Thistle::Store.new(store).publish(Thistle::Capture.new(root: root, rails: app).call).fetch('generation')
raise 'Expected distinct saved versions' unless [saved_a, saved_b, saved_partial, saved_c].uniq.length == 4

protected_paths = ['CURRENT'] + [saved_a, saved_b, saved_partial, saved_c].flat_map do |generation|
  %w[manifest.json facts.json].map { |name| "generations/#{generation}/#{name}" }
end
protected_paths += Dir.children(File.join(store, 'blobs')).sort.map { |name| "blobs/#{name}" }
protected_files = protected_paths.to_h { |name| [name, Digest::SHA256.file(File.join(store, name)).hexdigest] }
puts JSON.generate({ 'version' => 1, 'store' => store, 'saved_a' => saved_a, 'saved_b' => saved_b,
  'saved_partial' => saved_partial, 'current_c' => saved_c, 'protected_files' => protected_files,
  'default_a' => default_a, 'default_b' => default_b,
  'producer' => { 'rails' => Rails.version, 'sqlite' => ':memory:', 'edited_source_reloaded' => false,
    'git_used' => false, 'records_or_jobs_executed' => false } })
