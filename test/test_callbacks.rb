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
    assert_equal 1, fact_arrays, 'Format2 static admission is counted once; runtime must charge appended batches only'
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
end
