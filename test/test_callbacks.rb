# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/thistle'
require_relative 'fixtures/callbacks/booted_app'

# Root-owned hooks must compose the real journey for this test to pass. This is
# intentionally not a presenter-only substitute or an accepted installed test.
class ThistleCallbacksJourneyTest < Minitest::Test
  def test_runtime_batches_do_not_reserialize_the_existing_static_fact_array
    app = CallbackFixture.boot
    original = JSON.method(:generate)
    fact_arrays = 0
    JSON.define_singleton_method(:generate) do |value, *args, **options|
      fact_arrays += 1 if value.is_a?(Array) && value.first.is_a?(Hash) && value.first.key?('id')
      original.call(value, *args, **options)
    end
    capture = Thistle::Capture.new(root: File.join(__dir__, 'fixtures/callbacks'), rails: app).call
    assert capture.fetch('facts').any? { |fact| fact['kind'] == 'rails_save_callbacks' }
    assert_equal 0, fact_arrays, 'Schema3 uses native projected accounting; runtime must charge appended batches only'
  ensure
    JSON.define_singleton_method(:generate, original) if original
  end

  def test_real_capture_publication_fresh_reader_pins_registered_metadata
    app = CallbackFixture.boot
    Dir.mktmpdir('thistle-callback-store-') do |store|
      manifest = Thistle.capture(root: File.join(__dir__, 'fixtures/callbacks'), output: store, rails: app)
      reader = Thistle::Reader.new(store, generation: manifest.fetch('generation'))
      begin
        fact = reader.facts.find { |item| item['kind'] == 'rails_save_callbacks' && item['name'] == 'CallbackFixture::Child' }
        refute_nil fact, 'Capture must compose callback_batch; an inert module is not this journey'
        entries = fact.dig('attributes', 'callbacks', 'save', 'entries')
        stamp = entries.find { |entry| entry.dig('filter', 'name') == 'parent_stamp' }
        assert_equal true, stamp['inherited']
        assert_equal 'CallbackFixture::Child', stamp.dig('filter', 'owner')
        assert_equal 'records.rb', stamp.dig('filter', 'source', 'path')
        assert_equal entries.each_index.to_a, entries.map { |entry| entry['position'] }
        assert_raises(Thistle::Error) { reader.source(fact['id']) }
        assert_equal reader.generation, reader.source_file('records.rb')['generation']
        newer = Thistle.capture(root: File.join(__dir__, 'fixtures/callbacks'), output: store)
        refute_equal manifest['generation'], newer['generation']
        fresh = Thistle::Reader.new(store, generation: manifest['generation'])
        begin
          assert_equal fact, fresh.fact(fact['id'])
          assert_equal manifest['generation'], fresh.check()['generation']
        ensure
          fresh.close
        end
      ensure
        reader.close
      end
    end
  end

  def test_route_join_accounting_preserves_native_counter_and_exact_join_boundaries
    CallbackFixture.boot
    original = Thistle::Native.method(:call)
    contexts = []
    Thistle::Native.define_singleton_method(:call) do |request|
      contexts << request.fetch('context').dup if request['op'] == 'model_batch'
      original.call(request)
    end
    [false, true].each do |with_static|
      [0, 1, 2].each do |route_count|
        Dir.mktmpdir('thistle-route-join-') do |root|
          File.write(File.join(root, 'frame.rb'), "class Frame; end\n") if with_static
          routes = Array.new(route_count) do |index|
            Struct.new(:defaults, :name, :verb, :path).new(
              { controller: 'frames', action: 'show' }, "frame#{index}", 'GET',
              Struct.new(:spec).new("/frames/#{index}"))
          end
          app = Struct.new(:routes).new(Struct.new(:routes).new(routes))
          capture = Thistle::Capture.new(root: root, rails: app).call
          preceding = capture.fetch('facts').reject { |fact| %w[rails_model rails_save_callbacks].include?(fact['kind']) }
          static = preceding.select { |fact| fact['evidence'] == 'static' }
          runtime = preceding.select { |fact| fact['kind'] == 'route' }
          # Static facts here have empty links. Native admission keeps one
          # conservative first separator when that array is nonempty.
          static_charge = JSON.generate(static).bytesize + (static.empty? ? 0 : 1)
          route_charge = runtime.sum { |fact| JSON.generate(fact).bytesize + 1 }
          route_charge -= 1 if static.empty? && !runtime.empty?
          assert_equal static_charge + route_charge, contexts.last.fetch('fact_bytes'),
            "static=#{with_static}, routes=#{route_count}"
        end
      end
    end
  ensure
    Thistle::Native.define_singleton_method(:call, original) if original
  end
end
