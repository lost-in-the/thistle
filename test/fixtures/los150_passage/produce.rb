# frozen_string_literal: true

# AUTHORED UNRUN. Invoke only in Root's admitted installed producer process.
# Activate the declared framework BEFORE loading it or deriving any answers.
gem 'rails', '= 8.1.4'
require 'rails'
require 'action_controller/railtie'
require 'active_record/railtie'
require 'active_job/railtie'
require 'action_mailer/railtie'
require 'thistle'
require 'fileutils'
require 'json'

raise 'Wrong producer Rails version' unless Rails.version == '8.1.4'
raise 'Expected new public work directory' unless ARGV.length == 1 && !File.exist?(ARGV[0])
work = File.expand_path(ARGV.fetch(0))
Dir.mkdir(work, 0700)
root = File.join(work, 'app_source')
Dir.mkdir(root, 0700)
FileUtils.cp_r(File.join(__dir__, 'app'), root)
class PassageFixtureApp < Rails::Application
  config.eager_load = false
  config.secret_key_base = 'public-fixture-only-not-a-real-secret'
  config.hosts = ['fixture.example.invalid']
  config.logger = Logger.new(File::NULL)
end
PassageFixtureApp.config.root = root
app = PassageFixtureApp.initialize!
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:orders) { |table| table.string :name } }
%w[controllers/application_controller controllers/orders_controller models/order jobs/receipt_job mailers/receipt_mailer].each do |file|
  require File.join(root, 'app', "#{file}.rb")
end
# Actual framework guard probes, AUTHORED UNRUN here. They require the real
# framework class_attribute factory, not the NameError pure-double path.
require 'thistle/controller_filters_observer'
observe = ->(controllers) { Thistle::ControllerFiltersObserver.new(app:app,root:root,controllers:controllers,
  framework_version:Rails.version,limits:{max_entries:1000,max_facts:20},evidence_budget:131072).call }
baseline = observe.call([OrdersController]).fetch('controllers').fetch(0)
raise 'Actual controller storage guard was not reached' unless baseline.fetch('status') == 'observed'
only = baseline.fetch('entries').find { |r| r.dig('filter','name') == 'check_order' }
raise 'Actual action-filter set was not observed' unless only && only.fetch('if').any? { |c| c['kind'] == 'actions' && c['mode'] == 'only' && c['actions'] == ['create'] }
hash_set = Object.instance_method(:instance_variable_get).bind_call(Set.new(['create']),:@hash).instance_of?(Hash)
raise 'Ruby3.4 Set @hash path was not exercised' if RUBY_VERSION.start_with?('3.4.') && !hash_set
guard_calls = 0
guard_probe = Class.new(OrdersController)
guard_probe.define_singleton_method(:__class_attr___callbacks) { guard_calls += 1; raise 'Application override invoked' }
override = observe.call([guard_probe]).fetch('controllers').fetch(0)
raise 'ISeq mismatch guard failed' unless override.fetch('status') == 'unavailable' && guard_calls.zero?
guard_evidence = {'ruby'=>RUBY_VERSION,'registry_observed'=>true,'only_create_observed'=>true,
  'set_hash_backed'=>hash_set,'override_unavailable'=>true,'override_invocations'=>guard_calls}
app.routes.draw do
  constraints(host: 'fixture.example.invalid') do
    get '/orders', to: 'orders#index'
    post '/orders', to: 'orders#create'
    get '/orders/preview', to: 'orders#preview'
    post '/orders/conditional', to: 'orders#conditional'
    get '/orders/show', to: 'orders#show'
    get '/orders/missing', to: 'orders#missing'
  end
  get '/redirect', to: redirect('/orders')
end
store = File.join(work, 'store')
capture = Thistle::Capture.new(root: root, rails: app, controller_filters: [OrdersController],
  job_mail: {jobs:[ReceiptJob],mailers:[ReceiptMailer],templates:['app/views/receipt_mailer/receipt.html.erb']}).call
saved_a = Thistle::Store.new(store).publish(capture).fetch('generation')
# Preserve original complete facts. This partial derivative is a distinct saved
# generation, never a relabelled accepted result or source fixture mutation.
partial = Marshal.load(Marshal.dump(capture))
partial.fetch('coverage').each { |row| row['status'] = 'partial' if row['family'] == 'ruby_declarations' }
saved_partial = Thistle::Store.new(store).publish(partial).fetch('generation')
controller = File.join(root, 'app/controllers/orders_controller.rb')
File.write(controller, File.read(controller).gsub('saved_a', 'saved_b'))
# The loaded app is unchanged; current source/runtime coherence remains unknown.
saved_b = Thistle.capture(root: root, output: store).fetch('generation')
puts JSON.generate({'store'=>store,'root'=>root,'saved_a'=>saved_a,'partial'=>saved_partial,'current_b'=>saved_b,
  'rails_version'=>Rails.version,'source_runtime_coherence'=>'unknown','controller_filter_guard'=>guard_evidence})
