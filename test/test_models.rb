# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'thistle'

class ThistleModelsTest < Minitest::Test
  def test_booted_schema_known_answers_survive_publish_and_fresh_reader
    Dir.mktmpdir('thistle-models-') do |directory|
      root = File.join(directory, 'source')
      store = File.join(directory, 'store')
      Dir.mkdir(root)
      FileUtils.cp(File.join(__dir__, 'fixtures/models/records.rb'), root)
      # Isolate Rails boot and class inventory from other Core tests. A second
      # fresh process opens the snapshot without loading Rails or the fixture.
      producer = <<~'SCRIPT'
        require 'thistle'
        require File.expand_path('test/fixtures/models/booted_app', Dir.pwd)
        app = ModelFixture.boot(ARGV[0])
        # All canaries are installed after boot, before observation.
        def app.eager_load! = raise('eager load attempted')
        def app.reload_routes! = raise('reload attempted')
        ModelFixture::Item.reflect_on_association(:product).define_singleton_method(:klass) { raise 'target loaded' }
        capture = Thistle::Capture.new(root: ARGV[0], rails: app).call
        manifest = Thistle::Store.new(ARGV[1]).publish(capture)
        puts JSON.generate(manifest)
      SCRIPT
      out, err, status = Open3.capture3(RbConfig.ruby, '-Ilib', '-e', producer, root, store)
      assert status.success?, err
      generation = JSON.parse(out).fetch('generation')
      consumer = <<~'SCRIPT'
        require 'thistle'
        reader = Thistle::Reader.new(ARGV[0], generation: ARGV[1])
        begin
          facts = reader.facts.select { |f| f['kind'] == 'rails_model' }
          model = facts.find { |f| f['name'] == 'ModelFixture::Order' }
          begin
            reader.source(model.fetch('id'))
            raise 'fabricated runtime source'
          rescue Thistle::Error => e
            raise unless e.code == 'source_unavailable'
          end
          puts JSON.generate('facts' => facts, 'links' => reader.links(model.fetch('id')), 'check' => reader.check, 'generation' => reader.generation)
        ensure
          reader.close
        end
      SCRIPT
      out, err, status = Open3.capture3(RbConfig.ruby, '-Ilib', '-e', consumer, store, generation)
      assert status.success?, err
      result = JSON.parse(out)
      assert_equal generation, result['generation']
      by_name = result.fetch('facts').to_h { |fact| [fact['name'], fact.dig('attributes', 'model')] }
      order = by_name.fetch('ModelFixture::Order')
      assert_equal 'orders', order['table']
      assert_equal ['id'], order['primary_key']
      assert_equal 'ModelFixture::Order', by_name.fetch('ModelFixture::PriorityOrder')['base_class']
      assert_equal 'type', by_name.fetch('ModelFixture::PriorityOrder')['inheritance_column']
      state = order['columns']['entries'].find { |c| c['name'] == 'state' }
      assert_equal 'string', state['type']
      assert_equal false, state['null']
      assert_equal({ 'kind' => 'literal', 'value' => 'new' }, state['default'])
      associations = order['associations']['entries'].to_h { |a| [a['name'], a] }
      assert_equal %w[items payments products], associations.keys.sort
      assert_equal 'ModelFixture::Item', associations['items']['target']
      assert_equal 'ModelFixture::Payment', associations['payments']['target']
      assert_equal %w[has_many has_many], %w[items payments].map { |name| associations[name]['macro'] }
      assert_equal 'opaque', associations['items']['scope']
      assert_equal 'items', associations['products']['through']
      assert_nil associations['products']['target']
      polymorphic = by_name.fetch('ModelFixture::Payment')['associations']['entries'].find { |a| a['name'] == 'subject' }
      assert_equal true, polymorphic['polymorphic']
      assert_nil polymorphic['target']
      assert_equal 'unavailable', by_name.fetch('ModelFixture::MissingTable')['columns']['status']
      assert_equal 'observed', by_name.fetch('ModelFixture::MissingTable')['associations']['status']
      assert result['links'].all? { |link| link['resolution'] == 'unresolved' }
      assert_equal %w[items payments], result['links'].filter_map { |link| link.dig('attributes', 'association') }.sort
    end
  end

  def test_refused_model_publication_preserves_current_generation
    Dir.mktmpdir('thistle-model-limits-') do |directory|
      root = File.join(directory, 'source')
      Dir.mkdir(root)
      store = File.join(directory, 'store')
      capture = Thistle::Capture.new(root: root, limits: { max_links: 1 }).call
      original = Thistle::Store.new(store).publish(capture)
      observation = JSON.parse(File.read(File.join(__dir__, '../engine/tests/fixtures/models.json')))
      assert_raises(Thistle::LimitExceeded) { Thistle::Native.call('op' => 'append_models', 'capture' => capture, 'observation' => observation) }
      reader = Thistle::Reader.new(store)
      assert_equal original['generation'], reader.generation
    ensure
      reader&.close
    end
  end
end
