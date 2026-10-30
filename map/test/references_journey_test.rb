# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'cgi'
require 'thistle'
require 'thistle/map/app'

class ThistleMapReferencesJourneyTest < Minitest::Test
  def request(app, path, query, address: '127.0.0.1')
    status, _, body = app.call('REQUEST_METHOD' => 'GET', 'PATH_INFO' => path, 'SCRIPT_NAME' => '/map',
      'QUERY_STRING' => query, 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => address, 'rack.url_scheme' => 'http')
    [status, body.join]
  end

  def test_runtime_model_association_labels_keep_ambiguity_and_no_source_navigation
    Dir.mktmpdir do |dir|
      root = File.join(dir, 'input'); FileUtils.mkdir_p(root)
      File.write(File.join(root, 'item.rb'), "class Item; end\n")
      capture = Thistle::Capture.new(root: root).call
      observation = JSON.parse(File.read(File.expand_path('../../engine/tests/fixtures/models.json', __dir__)))
      item = JSON.parse(JSON.generate(observation.fetch('models').first))
      item['name'] = 'Item'; item['base_class'] = 'Item'; item['associations']['entries'] = []
      observation.fetch('models') << item
      anonymous = JSON.parse(JSON.generate(item)); anonymous['name'] = nil; anonymous['base_class'] = nil
      observation.fetch('models') << anonymous
      facts = capture.fetch('facts')
      batch = Thistle::Native.call('op' => 'model_batch', 'context' => {
        'schema_version' => capture.fetch('schema_version'),
        'limits' => capture.fetch('producer').fetch('effective_limits').slice('max_facts', 'max_links', 'max_entries', 'max_diagnostics'), 'facts' => facts.length,
        'links' => facts.sum { |fact| fact.fetch('links').length }, 'diagnostics' => capture.fetch('diagnostics').length,
        'fact_bytes' => JSON.generate(facts).bytesize }, 'observation' => observation)
      facts.concat(batch.fetch('facts'))
      capture.fetch('coverage').concat(batch.fetch('coverage'))
      capture.fetch('producer')['model_observer'] = batch.fetch('model_observer')
      store = File.join(dir, 'store')
      generation = Thistle::Store.new(store).publish(capture).fetch('generation')
      reader = Thistle::Reader.new(store)
      begin
        order = reader.find('Order').find { |fact| fact['kind'] == 'rails_model' }
        result = reader.references(order.fetch('id'))
        association = result.fetch('relationships').find { |row| row.dig('link', 'attributes', 'association') == 'items' }
        assert_equal 2, association.fetch('candidate_matches')
        assert_equal %w[class rails_model], association.fetch('candidates').map { |fact| fact.fetch('kind') }.sort
        assert_equal 1, association.fetch('candidates').count { |fact| fact['path'].nil? }
        runtime_item = association.fetch('candidates').find { |fact| fact['kind'] == 'rails_model' }
        incoming = reader.references(runtime_item.fetch('id'), direction: 'incoming')
        assert_includes incoming.fetch('relationships').map { |row| row.fetch('origin').fetch('id') }, order.fetch('id')
        assert_raises(Thistle::Error) { reader.source(runtime_item.fetch('id')) }
        anonymous_fact = reader.find('Anonymous model').first
        assert_empty reader.references(anonymous_fact.fetch('id'), direction: 'incoming').fetch('relationships')
      ensure
        reader.close
      end
      app = Thistle::Map::App.new(store: store)
      status, html = request(app, '/links', URI.encode_www_form('id' => order.fetch('id'), 'generation' => generation))
      assert_equal 200, status
      assert_includes html, 'No captured source'
      assert_includes html, '2 known name-match candidates'
      assert_includes html, 'association_target_label'
      assert_includes html, "generation=#{generation}"
    end
  end

  def test_fresh_native_map_incoming_outgoing_and_exact_old_source_after_swap
    Dir.mktmpdir do |dir|
      root = File.join(dir, 'input'); FileUtils.mkdir_p(root)
      bytes = File.binread(File.expand_path('../../test/fixtures/model_references.rb', __dir__))
      File.binwrite(File.join(root, 'models.rb'), bytes)
      store = File.join(dir, 'store')
      generation = Thistle.capture(root: root, output: store).fetch('generation')
      reader = Thistle::Reader.new(store)
      begin
        user = reader.find('User').find { |fact| fact['name'] == 'User' && fact['kind'] == 'class' }
        method = reader.find('Order#owner').first
      ensure
        reader.close
      end
      app = Thistle::Map::App.new(store: store)
      query = URI.encode_www_form('id' => user.fetch('id'), 'generation' => generation, 'direction' => 'incoming')
      status, html = request(app, '/links', query)
      assert_equal 200, status
      assert_includes html, 'Order#owner'
      assert_includes html, 'binding unknown'
      assert_includes html, 'Incoming references'
      assert_includes html, '<noscript>'
      status, outgoing = request(app, '/links', URI.encode_www_form('id' => method.fetch('id'), 'generation' => generation))
      assert_equal 200, status
      assert_includes outgoing, '2 known name-match candidates'
      assert_includes outgoing, 'constant User'
      assert_includes outgoing, 'Representative source'
      source_href = CGI.unescapeHTML(outgoing.scan(/href="([^"]+)"/).flatten.find { |href| href.start_with?('/map/source?') && href.include?('id=') })
      File.write(File.join(root, 'models.rb'), "class Replacement; end\n")
      Thistle.capture(root: root, output: store)
      uri = URI.parse(source_href)
      status, source = request(app, uri.path.delete_prefix('/map'), uri.query)
      assert_equal 200, status
      assert_includes source, generation[0, 12]
      assert_includes source, 'Order'
      refute_includes source, 'Replacement'
      pinned = Thistle::Reader.new(store, generation: generation)
      begin
        assert_equal bytes, pinned.source(user.fetch('id')).fetch('content')
      ensure
        pinned.close
      end
      assert_equal 400, request(app, '/links', query + '&direction=outgoing').first
      assert_equal 400, request(app, '/links', "id=#{user.fetch('id')}&direction=sideways").first
      assert_equal 400, request(app, '/links', 'q=' + 'a' * 4096).first
      assert_equal 403, request(app, '/links', query, address: '192.0.2.1').first
    end
  end
end
