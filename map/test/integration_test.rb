# frozen_string_literal: true

require_relative 'test_helper'

class MapIntegrationTest < Minitest::Test
  include MapTestSupport

  def test_real_reader_and_reused_map_keep_original_source_after_a_new_capture
    Dir.mktmpdir('thistle-map-integration-') do |directory|
      app_dir = File.join(directory, 'app')
      store = File.join(directory, 'store')
      FileUtils.mkdir_p(app_dir)
      original = "class Demo\n  def show = 'first capture'\nend\n"
      File.write(File.join(app_dir, 'demo.rb'), original)
      Thistle.capture(root: app_dir, output: store)
      old = Thistle::Reader.new(store)
      fact = old.find('Demo', limit: 10).find { |item| item['kind'] == 'class' }
      refute_nil fact
      app = Thistle::Map::App.new(store: store)
      query = URI.encode_www_form('id' => fact.fetch('id'), 'generation' => old.generation)
      first = request(app, '/source', query: query)
      assert_equal 200, first.first
      assert_includes first.last, 'first capture'

      File.write(File.join(app_dir, 'demo.rb'), original.sub('first capture', 'second capture'))
      Thistle.capture(root: app_dir, output: store)
      newer = Thistle::Reader.new(store)
      refute_equal old.generation, newer.generation
      pinned = request(app, '/source', query: query)
      assert_equal 200, pinned.first
      assert_includes pinned.last, 'first capture'
      refute_includes pinned.last, 'second capture'
      current_query = URI.encode_www_form('id' => fact.fetch('id'), 'generation' => newer.generation)
      current = request(app, '/source', query: current_query)
      assert_equal 200, current.first
      assert_includes current.last, 'second capture'
      refute Gem.loaded_specs.key?('woods')
      refute $LOADED_FEATURES.any? { |feature| feature.match?(%r{/(?:woods|woods_map)/}) }
    end
  end
end
