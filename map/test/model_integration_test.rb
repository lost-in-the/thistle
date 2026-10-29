# frozen_string_literal: true

require_relative 'test_helper'

class ModelIntegrationTest < Minitest::Test
  include MapTestSupport

  def test_saved_model_is_usable_on_source_unavailable_and_links_pages
    Dir.mktmpdir('thistle-model-map-') do |directory|
      root = File.join(directory, 'source')
      store = File.join(directory, 'store')
      Dir.mkdir(root)
      observation = JSON.parse(File.read(File.join(__dir__, '../../engine/tests/fixtures/models.json')))
      captured = Thistle::Native.call('op' => 'append_models', 'capture' => Thistle::Capture.new(root: root).call, 'observation' => observation)
      manifest = Thistle::Store.new(store).publish(captured)
      fact = captured.fetch('facts').find { |f| f['kind'] == 'rails_model' }
      app = Thistle::Map::App.new(store: store)
      query = URI.encode_www_form('generation' => manifest.fetch('generation'), 'id' => fact.fetch('id'))
      %w[/source /links].each do |path|
        status, _, body = request(app, path, query: query)
        assert_equal 200, status
        assert_includes body, 'Loaded model'
        assert_includes body, 'items'
        assert_includes body, 'payments'
        assert_includes body, 'generation=' + manifest.fetch('generation')
        assert_includes body, 'source unavailable'
      end
    end
  end
end
