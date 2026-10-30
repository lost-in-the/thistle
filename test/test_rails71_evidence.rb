# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'tmpdir'
require 'open3'
require 'rbconfig'
require 'thistle'

# Explicitly selected isolated-adapter lane. Default 8.1 CI remains unchanged.
# This fixture never provisions a database or substitutes a stock mysql2 gem.
class ThistleRails71EvidenceTest < Minitest::Test
  def test_genuine_target_observation_survives_publication_and_fresh_pinned_consumer
    skip 'Requires an owner-provided isolated Rails 7.1.6/mysql2 fixture' unless ENV['THISTLE_RAILS71_EVIDENCE'] == '1'
    config_path = ENV.fetch('THISTLE_RAILS71_DATABASE_CONFIG')
    raise 'Private log directory required' unless (File.stat(ENV.fetch('THISTLE_RAILS71_LOG_DIR')).mode & 0o777) == 0o700
    core_lib = File.dirname($LOADED_FEATURES.find { |path| path.end_with?('/thistle.rb') } || raise('Loaded Core path missing'))
    fixture = File.expand_path('fixtures/rails71/booted_app.rb', __dir__)
    Dir.mktmpdir('thistle-rails71-') do |store|
      producer = <<~'RUBY'
        require 'thistle'
        require ARGV.fetch(0)
        app = Rails71Fixture.boot(database_config: JSON.parse(File.read(ARGV.fetch(1))))
        root = File.dirname(ARGV.fetch(0))
        manifest = Thistle.capture(root: root, output: ARGV.fetch(2), rails: app)
        # Framework/model overrides must remain unknown without dispatch.
        options = { limits: { max_facts: 100, max_entries: 1000 }, evidence_budget: 200_000 }
        model = Rails71Fixture::Order
        singleton = model.singleton_class
        stored_reader = singleton.instance_method(:__callbacks)
        calls = []
        begin
          singleton.define_method(:abstract_class?) { calls << :abstract; raise 'abstract override executed' }
          data = Thistle::ModelObserver.new(**options).call['models'].find { |m| m['name'] == 'Rails71Fixture::Order' }
          raise 'unknown abstract status was coerced' unless data['abstract'].nil? && data.dig('columns', 'status') == 'unavailable'
          raise 'abstract override dispatched' unless calls.empty?
        ensure
          singleton.remove_method(:abstract_class?)
        end
        begin
          singleton.define_method(:_save_callbacks) { calls << :public_callbacks; raise 'public callback accessor executed' }
          callback = Thistle::CallbackObserver.new(root: root, **options)
          data = callback.call['models'].find { |m| m['name'] == 'Rails71Fixture::Order' }
          raise 'safe stored chain missing' unless data.dig('save', 'status') == 'observed'
          singleton.define_method(:__callbacks) { calls << :storage; raise 'storage override executed' }
          data = callback.call['models'].find { |m| m['name'] == 'Rails71Fixture::Order' }
          raise 'overridden storage accepted' unless data['save'] == { 'status' => 'unavailable', 'entries' => [] }
          raise 'callback accessor dispatched' unless calls.empty?
        ensure
          singleton.remove_method(:_save_callbacks)
          singleton.define_method(:__callbacks, stored_reader)
        end
        newer = Thistle.capture(root: root, output: ARGV.fetch(2))
        raise 'CURRENT did not advance' if newer.fetch('generation') == manifest.fetch('generation')
        puts JSON.generate('generation' => manifest.fetch('generation'), 'current' => newer.fetch('generation'),
          'rails' => Rails::VERSION::STRING, 'active_record' => ActiveRecord::VERSION::STRING)
      RUBY
      out, err, status = Open3.capture3(RbConfig.ruby, '-I', core_lib, '-e', producer, fixture, config_path, store)
      retain_stderr('producer', err)
      assert status.success?, 'Rails71 producer/guard checks failed; no support result (retain private stderr in the execution harness)'
      identity = JSON.parse(out)
      assert_equal '7.1.6', identity['rails']
      assert_equal '7.1.6', identity['active_record']
      refute_equal identity['generation'], identity['current']
      consumer = <<~'RUBY'
        require 'thistle'
        raise 'consumer loaded Rails' if defined?(Rails) || defined?(ActiveRecord)
        reader = Thistle::Reader.new(ARGV.fetch(0), generation: ARGV.fetch(1))
        begin
          facts = reader.facts.select { |f| %w[rails_model rails_save_callbacks route].include?(f['kind']) }
          puts JSON.generate('facts' => facts, 'generation' => reader.generation, 'check' => reader.check)
        ensure
          reader.close
        end
        raise 'consumer loaded Rails' if defined?(Rails) || defined?(ActiveRecord)
      RUBY
      out, err, status = Open3.capture3(RbConfig.ruby, '-I', core_lib, '-e', consumer, store, identity.fetch('generation'))
      retain_stderr('consumer', err)
      assert status.success?, 'Fresh Rails-free pinned consumer failed; no support result'
      saved = JSON.parse(out)
      assert_equal identity['generation'], saved['generation']
      assert_equal identity['generation'], saved.dig('check', 'generation')
      facts = saved.fetch('facts')
      model = facts.find { |f| f['kind'] == 'rails_model' && f['name'] == 'Rails71Fixture::Order' }.dig('attributes', 'model')
      assert_equal '7.1.6', model['active_record_version']
      assert_equal false, model['abstract']
      assert_equal ['id'], model['primary_key']
      assert_equal 'observed', model.dig('columns', 'status')
      state = model['columns']['entries'].find { |column| column['name'] == 'state' }
      assert_equal 'string', state['type']
      assert_equal false, state['null']
      assert_equal({ 'kind' => 'literal', 'value' => 'new' }, state['default'])
      association = model['associations']['entries'].find { |entry| entry['name'] == 'items' }
      assert_equal 'Rails71Fixture::Item', association['target']
      assert_equal 'opaque', association['scope']
      missing = facts.find { |f| f['kind'] == 'rails_model' && f['name'] == 'Rails71Fixture::Missing' }.dig('attributes', 'model')
      assert_equal 'unavailable', missing.dig('columns', 'status')
      assert_equal 'observed', missing.dig('associations', 'status')
      priority = facts.find { |f| f['kind'] == 'rails_model' && f['name'] == 'Rails71Fixture::PriorityOrder' }.dig('attributes', 'model')
      assert_equal 'Rails71Fixture::Order', priority['base_class']
      callbacks = facts.find { |f| f['kind'] == 'rails_save_callbacks' && f['name'] == 'Rails71Fixture::Order' }.dig('attributes', 'callbacks')
      assert_equal '7.1.6', callbacks['active_record_version']
      stamp = callbacks['save']['entries'].find { |entry| entry.dig('filter', 'name') == 'stamp' }
      assert_equal true, stamp['inherited']
      assert_equal 'Rails71Fixture::Order', stamp.dig('filter', 'owner')
      assert_equal 'Rails71Fixture::Parent', stamp.dig('if', 0, 'owner')
      local = callbacks['save']['entries'].find { |entry| entry.dig('filter', 'name') == 'local_stamp' }
      assert_equal 'proc', local.dig('unless', 0, 'kind')
      route = facts.find { |f| f['kind'] == 'route' && f.dig('attributes', 'action') == 'show' }.dig('attributes', 'route_constraints')
      assert_equal 'observed', route['status']
      assert_equal 'admin', route['request'].find { |entry| entry['key'] == 'subdomain' }['value']
      assert_equal '\d+', route['segments'].find { |entry| entry['key'] == 'id' }['value']
      regexp = facts.find { |f| f['kind'] == 'route' && f.dig('attributes', 'action') == 'regexp' }
        .dig('attributes', 'route_constraints', 'request').find { |entry| entry['key'] == 'subdomain' }
      assert_equal 'regexp', regexp['type']
      assert_equal 'admin|staff', regexp['value']
      assert_equal Regexp::IGNORECASE, regexp['options'] & Regexp::IGNORECASE
      object = facts.find { |f| f['kind'] == 'route' && f.dig('attributes', 'action') == 'object' }
      assert_equal 'present', object.dig('attributes', 'route_constraints', 'opaque')
      opaque = facts.find { |f| f['kind'] == 'route' && f.dig('attributes', 'action') == 'index' }
      assert_equal 'present', opaque.dig('attributes', 'route_constraints', 'opaque')
    end
  end

  private

  # The runtime owner supplies an existing private evidence directory for each
  # attempt. Exclusive creation preserves earlier diagnostics and fails closed.
  def retain_stderr(child, bytes)
    directory = ENV.fetch('THISTLE_RAILS71_LOG_DIR')
    raise 'Private log directory required' unless (File.stat(directory).mode & 0o777) == 0o700
    raise 'Child stderr exceeds evidence ceiling' if bytes.bytesize > 4 * 1024 * 1024
    File.open(File.join(directory, "#{child}.stderr"), File::WRONLY | File::CREAT | File::EXCL, 0o600) { |log| log.write(bytes) }
  end
end
