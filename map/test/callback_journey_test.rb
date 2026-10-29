# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../test/fixtures/callbacks/booted_app'
require_relative '../lib/thistle/map/callback_presenter'

class ThistleCallbackMapJourneyTest < Minitest::Test
  def test_saved_reader_and_map_use_the_requested_generation_after_current_changes
    app = CallbackFixture.boot
    root = File.expand_path('../../test/fixtures/callbacks', __dir__)
    Dir.mktmpdir('thistle-callback-map-') do |store|
      saved = Thistle.capture(root: root, output: store, rails: app)
      Thistle.capture(root: root, output: store)
      reader = Thistle::Reader.new(store, generation: saved['generation'])
      begin
        fact = reader.facts.find { |item| item['kind'] == 'rails_save_callbacks' && item['name'] == 'CallbackFixture::Child' }
        refute_nil fact, 'Real callback capture/schema hooks must be composed'
        html = Thistle::Map::CallbackPresenter.new(generation: saved['generation'], mount: '/map', reader: reader).render(fact)
        assert_includes html, 'Method :parent_stamp'
        assert_includes html, 'Captured source (coherence unknown)'
        assert_includes html, "generation=#{saved['generation']}"
        assert_includes html, "file=#{Digest::SHA256.hexdigest('records.rb')}"
        view = Thistle::Map::View.new(reader: reader, mount: '/map', params: { 'id' => fact['id'] })
        rendered = view.source
        assert_includes rendered, 'Registered save callbacks', 'View composition belongs to root and must remain a real assertion'
        assert_includes rendered, "generation=#{saved['generation']}"
      ensure
        reader.close
      end
    end
  end
end
