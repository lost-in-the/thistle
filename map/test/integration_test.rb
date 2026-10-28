# frozen_string_literal: true

require_relative 'test_helper'
require 'action_dispatch'
require 'action_controller/railtie'

class MapIntegrationTest < Minitest::Test
  include MapTestSupport

  def test_runtime_route_source_is_available_as_context_across_generations
    Dir.mktmpdir('thistle-map-route-') do |directory|
      root = File.join(directory, 'app')
      store = File.join(directory, 'store')
      FileUtils.mkdir_p(root)
      routes = ActionDispatch::Routing::RouteSet.new
      routes.draw { get '/baskets/:id', to: 'baskets#show' }
      rails = Struct.new(:routes).new(routes)
      Thistle.capture(root: root, output: store, rails: rails)
      old = Thistle::Reader.new(store)
      fact = old.find('baskets', limit: 10).find { |row| row['kind'] == 'route' }
      refute_nil fact
      error = assert_raises(Thistle::Error) { old.source(fact.fetch('id')) }
      assert_equal 'source_unavailable', error.code
      app = Thistle::Map::App.new(store: store)
      query = URI.encode_www_form('id' => fact.fetch('id'), 'generation' => old.generation)
      found = request(app, '/', query: URI.encode_www_form('q' => 'baskets', 'generation' => old.generation))
      assert_equal 200, found.first
      assert_includes found.last, fact.fetch('name')
      source = request(app, '/source', query: query)
      assert_equal 200, source.first
      assert_includes source.last, fact.fetch('name')
      assert_includes source.last, 'runtime'
      assert_includes source.last, 'No file or line was captured'
      assert_includes source.last, 'Unavailable'
      %w[/links /check].each { |path| assert_equal 200, request(app, path, query: query).first }
      routes.draw { get '/baskets/:id', to: 'baskets#update' }
      Thistle.capture(root: root, output: store, rails: rails)
      newer = Thistle::Reader.new(store)
      refute_equal old.generation, newer.generation
      pinned = request(app, '/source', query: query)
      assert_equal 200, pinned.first
      assert_includes pinned.last, 'baskets#show'
      refute_includes pinned.last, 'baskets#update'
      current = newer.find('baskets', limit: 10).find { |row| row['kind'] == 'route' }
      assert_includes current.fetch('name'), 'baskets#update'
      current_query = URI.encode_www_form('id' => current.fetch('id'), 'generation' => newer.generation)
      current_page = request(app, '/source', query: current_query)
      assert_equal 200, current_page.first
      assert_includes current_page.last, 'baskets#update'
      refute_includes current_page.last, 'baskets#show'
    ensure
      old&.close
      newer&.close
    end
  end

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
