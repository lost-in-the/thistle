# frozen_string_literal: true
# Harmless stdlib-only controller helpers; no Rails, Thistle, DB, server or native
# candidate is loaded. Database method receivers below are explicit metadata stubs.
require 'json'
require 'tmpdir'
require 'pathname'
require 'ostruct'
require_relative '../control/profile'
require_relative '../control/session_log'
require_relative '../control/database'
require_relative '../control/answers'

checks = []
def assert(value, code)
  raise code unless value
end
def refuses(code)
  begin
    yield
  rescue RuntimeError, KeyError, Errno::EEXIST
    return true
  end
  raise code
end

Dir.mktmpdir('los139-ruby-helpers-') do |directory|
  File.chmod(0o700, directory)
  %w[a b].each { |name| Dir.mkdir(File.join(directory, name * 32), 0o700) }
  first, log = SessionLog.open(directory, 'a' * 32)
  log.write('first session')
  log.close
  SessionLog.failure(first, { 'program' => 'host', 'code' => 'STUB_START_FAILED' })
  second, log = SessionLog.open(directory, 'b' * 32)
  log.write('second start, same process/PID')
  log.close
  assert(File.read(File.join(first, 'host.log')) == 'first session', 'F02_OLD_LOG_CHANGED')
  assert(File.read(File.join(second, 'host.log')).include?('second start'), 'F02_SECOND_START')
  refuses('F02_EXCLUSIVE_LOG') { SessionLog.open(directory, 'a' * 32) }
  assert(Dir[File.join(first, 'host-failure-*.json')].length == 1, 'F02_FAILED_START_DIAGNOSTIC')
  assert((File.stat(File.join(second, 'host.log')).mode & 0o777) == 0o600, 'F02_LOG_MODE')
  checks << 'F02_session_logs_second_start_failed_start'

  receipt = File.join(directory, 'receipt.json')
  HostProfile.write(receipt, { 'complete' => true })
  refuses('F10_OVERWRITE') { HostProfile.write(receipt, { 'complete' => false }) }
  assert(JSON.parse(File.read(receipt)) == { 'complete' => true }, 'F10_IMMUTABLE_RECEIPT')
  assert((File.stat(receipt).mode & 0o777) == 0o600, 'F10_RECEIPT_MODE')
  checks << 'F10_atomic_exclusive_receipt'

  refuses('F12_BUILTIN_IS_NOT_A_FILE') { HostProfile.file_identity('enumerator.so') }
  spec = OpenStruct.new(version: '1.2.3', full_gem_path: directory, loaded_from: receipt)
  def spec.default_gem? = false
  refuses('F12_OUTSIDE_SAME_VERSION') { HostProfile.verify_spec!('example', spec, { 'example' => '1.2.3' }, {}) }
  assert(HostProfile.admitted_gem_root?('/dependencies/gems/example'), 'F12_ADMITTED_ROOT')
  assert(!HostProfile.admitted_gem_root?('/dependencies-escape/gems/example'), 'F12_PREFIX_ESCAPE')
  def spec.default_gem? = true
  providers = { 'specs' => { 'example' => { 'version' => '1.2.3', 'gemspec_path' => receipt,
    'gemspec_sha256' => Digest::SHA256.file(receipt).hexdigest } } }
  HostProfile.verify_spec!('example', spec, {}, providers)
  providers['specs']['example']['gemspec_sha256'] = '0' * 64
  refuses('F12_DEFAULT_HASH_DRIFT') { HostProfile.verify_spec!('example', spec, {}, providers) }
  Object.const_set(:ActiveSupport, Module.new)
  refuses('F12_ACTIVE_SUPPORT') { HostProfile.framework_free! }
  Object.send(:remove_const, :ActiveSupport)
  checks << 'F12_actual_provider_roots_default_hash_and_framework_guard'
end

fixture = JSON.parse(File.read(File.expand_path('../app/expected.json', __dir__)))
assert(fixture.fetch('indexes').fetch('items') == [['items_order_id_idx', ['order_id'], false]], 'F03_DECLARED_INDEX')
assert(fixture.fetch('foreign_keys').fetch('items') == [['fk_items_orders', 'orders', 'order_id', 'id']], 'F03_DECLARED_FK')
connection = Object.new
connection.define_singleton_method(:tables) { %w[host_metadata items orders] }
connection.define_singleton_method(:select_value) { |sql| sql.include?('server_uuid') ? 'fixture-uuid' : '8.4.13' }
connection.define_singleton_method(:select_rows) do |sql|
  case sql
  when 'SELECT schema_version, seed_version FROM host_metadata' then [['los139-schema-v1', 'los139-seed-v1']]
  when 'SELECT id, reference FROM orders ORDER BY id' then [[1, 'retained-order-1']]
  when 'SELECT id, order_id, quantity FROM items ORDER BY id' then [[1, 1, 2], [2, 1, 3]]
  else [['stub raw columns; evidence only']]
  end
end
connection.define_singleton_method(:columns) { |table| fixture.fetch('columns').fetch(table).map { |n, t, null| OpenStruct.new(name: n, type: t.to_sym, null: null) } }
connection.define_singleton_method(:indexes) { |table| table == 'items' ? [OpenStruct.new(name: 'items_order_id_idx', columns: ['order_id'], unique: false)] : [] }
connection.define_singleton_method(:foreign_keys) { |table| table == 'items' ? [OpenStruct.new(name: 'fk_items_orders', to_table: 'orders', column: 'order_id', primary_key: 'id')] : [] }
Object.const_set(:ActiveRecord, Module.new)
ActiveRecord.const_set(:Base, Class.new)
ActiveRecord::Base.define_singleton_method(:connection) { connection }
Object.const_set(:Rails, Module.new)
Rails.define_singleton_method(:root) { Pathname.new(File.expand_path('../app', __dir__)) }
HostProfile.define_singleton_method(:config) { { 'server_uuid' => 'fixture-uuid' } }
2.times do
  Dir.mktmpdir('los139-new-artifact-instance-') do |directory|
    Dir.chdir(directory) { HostDatabase.verify }
    assert(Dir.children(directory).empty?, 'F03_NO_INSTANCE_GATE_OR_RESET')
  end
end
connection.define_singleton_method(:indexes) { |_| [] }
refuses('F03_MISSING_INDEX') { HostDatabase.verify }
connection.define_singleton_method(:indexes) { |table| table == 'items' ? [OpenStruct.new(name: 'items_order_id_idx', columns: ['order_id'], unique: false)] : [] }
connection.define_singleton_method(:foreign_keys) { |table| table == 'items' ? [OpenStruct.new(name: 'fk_items_orders', to_table: 'wrong', column: 'order_id', primary_key: 'id')] : [] }
refuses('F03_WRONG_FK') { HostDatabase.verify }
Object.send(:remove_const, :Rails)
Object.send(:remove_const, :ActiveRecord)
checks << 'F03_fixture_metadata_new_instance_reuse_no_schema_gate'

oracle = { 'saved' => 'a' * 64, 'origin_id' => 'b' * 64, 'source_sha256' => 'c' * 64, 'site_lines' => [7, 8], 'site_count' => 2 }
hidden = "<input value=\"#{oracle['saved']}\">"
refuses('F08_FIND_NO_MATCH') { MapAnswers.verify('find', hidden + 'No matches', oracle) }
find = hidden + "<a data-result-link href=\"/source?id=#{oracle['origin_id']}&amp;generation=#{oracle['saved']}\">Inspection#sites</a>"
MapAnswers.verify('find', find, oracle)
failed = hidden + '<pre class="check-data">' + CGI.escapeHTML(JSON.generate('integrity' => 'failed', 'generation' => oracle['saved'])) + '</pre>'
refuses('F08_FAILED_INTEGRITY') { MapAnswers.verify('check', failed, oracle) }
verified = failed.sub('failed', 'verified')
MapAnswers.verify('check', verified, oracle)
site_rows = [7, 8].map do |line|
  "<span class=\"constant-site\">Role: #{line == 7 ? 'argument' : 'value'}<a href=\"/source?id=#{oracle['origin_id']}&amp;generation=#{oracle['saved']}#L#{line}\">site</a></span>"
end
sites = hidden + site_rows.join
MapAnswers.verify('links', sites, oracle)
refuses('F08_WRONG_PINNED_SITE_ID') { MapAnswers.verify('links', sites.gsub(oracle['origin_id'], 'd' * 64), oracle) }
checks << 'F08_meaningful_find_and_check_negatives'
raise 'Framework/native candidate unexpectedly loaded' if Gem.loaded_specs.keys.any? { |name| %w[thistle thistle-map rails railties activerecord actionpack activesupport].include?(name) }
puts JSON.generate('status' => 'passed', 'checks' => checks, 'scope' => 'stdlib controller helpers and declared metadata stubs only; no SQL/framework/product runtime')
