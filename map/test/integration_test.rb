# frozen_string_literal: true

require_relative 'test_helper'
require 'action_dispatch'
require 'action_controller/railtie'

class MapIntegrationTest < Minitest::Test
  include MapTestSupport

  def test_structured_calls_follow_pinned_source_through_real_reader
    Dir.mktmpdir('thistle-call-journey-') do |directory|
      root = File.join(directory, 'app')
      store = File.join(directory, 'store')
      FileUtils.mkdir_p(root)
      source = "class Parcel\n  def show(x)\n    x&.render; x.render; x.render\n    [1].same; [2].same; \"#{'a' * 8192}\".size\n  end\nend\n"
      source = source.sub("\nend\n", "\n  def note = <<~TEXT\n    \#{self.render}\n  TEXT\nend\n")
      File.write(File.join(root, 'parcel.rb'), source)
      Thistle.capture(root: root, output: store)
      old = Thistle::Reader.new(store)
      fact = old.find('Parcel#show', limit: 10).find { |item| item['name'] == 'Parcel#show' }
      refute_nil fact
      links = old.links(fact.fetch('id'))
      assert_equal 2, links.count { |link| link['target'] == 'render' }
      assert_equal 2, links.count { |link| link['target'] == 'same' }
      long = links.find { |link| link['target'] == 'size' }
      assert_equal 'literal', long.dig('attributes', 'thistle_call', 'receiver', 'kind')
      location = long.dig('attributes', 'thistle_call', 'receiver_location')
      assert_equal "\"#{'a' * 8192}\"", source.b.byteslice(location['start_byte']...location['end_byte'])
      app = Thistle::Map::App.new(store: store)
      query = URI.encode_www_form('id' => fact['id'], 'generation' => old.generation)
      html = request(app, '/links', query: query).last
      assert_includes html, 'local x'
      assert_includes html, 'safe navigation'
      assert_includes html, 'Representative source'
      assert_includes html, '#L3'
      assert_includes html, old.generation
      note = old.find('Parcel#note', limit: 10).find { |item| item['name'] == 'Parcel#note' }
      line = source.lines.index { |text| text.include?('#{self.render}') } + 1
      assert_operator line, :>, note.fetch('location').fetch('end_line')
      note_query = URI.encode_www_form('id' => note.fetch('id'), 'generation' => old.generation)
      note_page = request(app, '/links', query: note_query)
      assert_equal 200, note_page.first
      assert_includes note_page.last, '<br>self ·'
      href = note_page.last[/href="([^"]+#L#{line})"/, 1]
      refute_nil href
      source_uri = URI.parse(href.gsub('&amp;', '&'))
      assert_equal source, old.source(fact['id'])['content']
      assert_equal 'verified', old.check['integrity']
      File.write(File.join(root, 'parcel.rb'), source.sub('[1]', '[3]'))
      Thistle.capture(root: root, output: store)
      newer = Thistle::Reader.new(store)
      refute_equal old.generation, newer.generation
      assert_equal source, old.source(fact['id'])['content']
      pinned = request(app, '/source', query: query)
      assert_equal 200, pinned.first
      assert_includes pinned.last, old.generation
      assert_includes pinned.last, 'id="L3"'
      followed = request(app, source_uri.path, query: source_uri.query)
      assert_equal 200, followed.first
      assert_includes followed.last, old.generation
      assert_includes followed.last, "id=\"L#{line}\""
      assert_equal source, old.source(note.fetch('id')).fetch('content')
      assert_equal 200, request(app, '/check', query: query).first
    ensure
      old&.close
      newer&.close
    end
  end

  def test_real_route_conditions_survive_publish_reader_and_escaped_map
    Dir.mktmpdir('thistle-map-constraints-') do |directory|
      root = File.join(directory, 'app')
      store = File.join(directory, 'store')
      FileUtils.mkdir_p(root)
      routes = ActionDispatch::Routing::RouteSet.new
      routes.draw do
        get '/orders', to: 'orders#index', constraints: { host: '<script>bad</script>' }
        get '/orders', to: 'orders#index', constraints: { subdomain: /api/i }
      end
      rails = Struct.new(:routes).new(routes)
      Thistle.capture(root: root, output: store, rails: rails)
      reader = Thistle::Reader.new(store)
      facts = reader.find('orders', limit: 10).select { |f| f['kind'] == 'route' }
      assert_equal 2, facts.length
      refute_equal facts[0]['id'], facts[1]['id']
      app = Thistle::Map::App.new(store: store)
      find = request(app, '/', query: URI.encode_www_form('q' => 'orders', 'generation' => reader.generation))
      assert_equal 200, find.first
      assert_includes find.last, '&lt;script&gt;bad&lt;/script&gt;'
      refute_includes find.last, '<script>bad</script>'
      assert_includes find.last, 'subdomain'
      query = URI.encode_www_form('id' => facts[0]['id'], 'generation' => reader.generation)
      source = request(app, '/source', query: query)
      assert_equal 200, source.first
      assert_includes source.last, '&lt;script&gt;bad&lt;/script&gt;'
      assert_includes source.last, 'No file or line was captured'
      assert_includes source.last, 'does not prove a request will match'
      assert_includes source.last, reader.generation
      routes.draw { get '/orders', to: 'orders#index', constraints: { host: 'new.example' } }
      Thistle.capture(root: root, output: store, rails: rails)
      newer = Thistle::Reader.new(store)
      refute_equal reader.generation, newer.generation
      new_fact = newer.find('orders', limit: 10).find { |f| f['kind'] == 'route' }
      assert_equal facts[0]['id'], new_fact['id']
      new_query = URI.encode_www_form('id' => new_fact['id'], 'generation' => newer.generation)
      assert_includes request(app, '/source', query: new_query).last, 'new.example'
      pinned = request(app, '/source', query: query)
      assert_equal 200, pinned.first
      assert_includes pinned.last, '&lt;script&gt;bad&lt;/script&gt;'
    ensure
      reader&.close
      newer&.close
    end
  end

  def test_schema_valid_untrusted_route_metadata_is_bounded_by_map
    Dir.mktmpdir('thistle-map-untrusted-constraints-') do |directory|
      root = File.join(directory, 'app')
      store = File.join(directory, 'store')
      FileUtils.mkdir_p(root)
      capture = Thistle::Capture.new(root: root).call
      fact = {
        'id' => Digest::SHA256.hexdigest('untrusted-route'), 'kind' => 'route',
        'name' => 'GET /untrusted orders#index', 'evidence' => 'runtime',
        'path' => nil, 'location' => nil, 'links' => [], 'attributes' => {}
      }
      capture['facts'] << fact
      [nil, '<' * 8_193].each do |value|
        fact['attributes']['route_constraints'] = {
          'status' => 'observed', 'opaque' => 'none observed', 'segments' => [],
          'request' => [{ 'key' => 'host', 'type' => 'string', 'value' => value, 'encoding' => 'UTF-8' }]
        }
        manifest = Thistle::Store.new(store).publish(capture)
        query = URI.encode_www_form('id' => fact['id'], 'generation' => manifest['generation'])
        status, _, body = request(Thistle::Map::App.new(store: store), '/source', query: query)
        assert_equal 200, status
        assert_includes body, 'Unknown; conditions are invalid or exceed the display budget'
        assert_includes body, 'No file or line was captured'
        assert_operator body.bytesize, :<, 10_000
      end
    end
  end

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
