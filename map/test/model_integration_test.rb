# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'rbconfig'

class ModelIntegrationTest < Minitest::Test
  include MapTestSupport

  def test_saved_model_is_usable_on_source_unavailable_and_links_pages
    Dir.mktmpdir('thistle-model-map-') do |directory|
      root = File.join(directory, 'source')
      store = File.join(directory, 'store')
      Dir.mkdir(root)
      fixture = File.expand_path('../../test/fixtures/models/booted_app.rb', __dir__)
      # Rails exists only in the producing process. Map must reopen the saved
      # evidence without the application, then keep that generation after publish.
      producer = <<~'SCRIPT'
        require 'thistle'
        require ARGV[0]
        app = ModelFixture.boot(ARGV[1])
        captured = Thistle::Capture.new(root: ARGV[1], rails: app).call
        manifest = Thistle::Store.new(ARGV[2]).publish(captured)
        fact = captured.fetch('facts').find { |f| f['kind'] == 'rails_model' && f['name'] == 'ModelFixture::Order' }
        puts JSON.generate('generation' => manifest.fetch('generation'), 'id' => fact.fetch('id'))
      SCRIPT
      out, err, status = Open3.capture3(RbConfig.ruby, '-I' + File.expand_path('../../lib', __dir__), '-e', producer, fixture, root, store)
      assert status.success?, err
      selected = JSON.parse(out)
      replacement = Thistle.capture(root: root, output: store)
      refute_equal selected.fetch('generation'), replacement.fetch('generation')
      app = Thistle::Map::App.new(store: store)
      query = URI.encode_www_form('generation' => selected.fetch('generation'), 'id' => selected.fetch('id'))
      %w[/source /links].each do |path|
        status, _, body = request(app, path, query: query)
        assert_equal 200, status
        assert_includes body, 'Loaded model'
        assert_includes body, 'ModelFixture::Order'
        assert_includes body, 'orders'
        assert_includes body, 'state'
        assert_includes body, 'items'
        assert_includes body, 'payments'
        assert_includes body, 'generation=' + selected.fetch('generation')
        assert_includes body, 'source unavailable'
      end
    end
  end
end
