# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'rbconfig'
require 'cgi'

class ModelBriefJourneyTest < Minitest::Test
  include MapTestSupport

  # The existing known-answer Core fixture has real Rails reflections/callbacks
  # and explicit declared-column test metadata. It never queries a live database.
  def test_saved_model_brief_then_exact_saved_source_and_links_after_current_advances
    Dir.mktmpdir('thistle-map-model-brief-') do |directory|
      root, store = %w[source store].map { |part| File.join(directory, part) }
      FileUtils.mkdir_p(root)
      fixture = File.expand_path('../../test/fixtures/model_brief', __dir__)
      bytes = File.binread(File.join(fixture, 'records.rb'))
      File.binwrite(File.join(root, 'records.rb'), bytes)
      producer = <<~'RUBY'
        require 'json'; require 'thistle'
        require ARGV[0]
        app = BriefFixture.boot(ARGV[1])
        saved = Thistle.capture(root: ARGV[1], output: ARGV[2], rails: app)
        File.write(File.join(ARGV[1], 'records.rb'), 'class CurrentReplacement; end')
        newer = Thistle.capture(root: ARGV[1], output: ARGV[2])
        puts JSON.generate('generation' => saved.fetch('generation'), 'newer' => newer.fetch('generation'))
      RUBY
      out, err, process = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__),
        '-e', producer, File.join(fixture, 'booted_app.rb'), root, store)
      assert process.success?, err
      receipt = JSON.parse(out.lines.last)
      generation = receipt.fetch('generation')
      refute_equal generation, receipt.fetch('newer')
      consumer = <<~'RUBY'
        require 'json'; require 'uri'; require 'cgi'; require 'thistle/map'
        raise 'Producing framework loaded in consumer' if defined?(Rails) || defined?(ActiveRecord)
        reader = Thistle::Reader.new(ARGV[0], generation: ARGV[1])
        begin
          model = reader.find('BriefFixture::Order').find { |fact| fact['kind'] == 'rails_model' }
        ensure
          reader.close
        end
        app = Thistle::Map::App.new(store: ARGV[0])
        request = lambda do |path, query|
          status, _, body = app.call('REQUEST_METHOD' => 'GET', 'PATH_INFO' => path, 'QUERY_STRING' => query,
            'SCRIPT_NAME' => '', 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1', 'rack.url_scheme' => 'http')
          [status, body.join]
        end
        status, html = request.call('/links', URI.encode_www_form('id' => model.fetch('id'), 'generation' => ARGV[1]))
        raise "Brief request failed: #{status}" unless status == 200
        hrefs = html.scan(/href="([^"]+)"/).flatten.map { |href| CGI.unescapeHTML(href) }
        source = hrefs.find { |href| URI.parse(href).fragment == 'L10' }
        raise 'Missing supporting call anchor' unless source
        uri = URI.parse(source)
        source_status, source_html = request.call(uri.path, uri.query)
        method_id = URI.decode_www_form(uri.query).to_h.fetch('id')
        target = hrefs.find do |href|
          uri = URI.parse(href)
          uri.path == '/links' && URI.decode_www_form(uri.query || '').to_h['id'] == method_id
        end
        raise 'Missing captured method Links destination' unless target
        uri = URI.parse(target)
        link_status, link_html = request.call(uri.path, uri.query)
        query = URI.encode_www_form('id' => model.fetch('id'), 'generation' => ARGV[1])
        model_source_status, model_source = request.call('/source', query)
        denied, = app.call('REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/links', 'QUERY_STRING' => query,
          'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '192.0.2.1')
        missing, = request.call('/links', query.sub(ARGV[1], 'f' * 64))
        puts JSON.generate('source_status' => source_status, 'source' => source_html,
          'links_status' => link_status, 'links' => link_html, 'method_id' => method_id,
          'model_source_status' => model_source_status, 'model_source' => model_source,
          'brief' => html, 'denied_status' => denied, 'missing_status' => missing)
      RUBY
      fresh, err, process = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__),
        '-I', File.expand_path('../lib', __dir__), '-e', consumer, store, generation)
      assert process.success?, err
      fresh = JSON.parse(fresh)
      assert_equal 200, fresh.fetch('source_status')
      assert_equal 200, fresh.fetch('links_status')
      assert_includes fresh.fetch('source'), 'Source SHA-256: ' + Digest::SHA256.hexdigest(bytes)
      refute_includes fresh.fetch('source'), 'CurrentReplacement'
      assert_includes fresh.fetch('links'), 'perform_later'
      assert_includes fresh.fetch('links'), "generation=#{generation}"
      expected_id = Digest::SHA256.hexdigest(JSON.generate(['ruby', 'method', 'BriefFixture::Parent#deliver',
        'records.rb', bytes.index('def deliver'.b)]))
      assert_equal expected_id, fresh.fetch('method_id')
      assert_equal 200, fresh.fetch('model_source_status')
      source_html = fresh.fetch('model_source')
      assert_includes source_html, 'Saved model investigation'
      assert_includes source_html, 'No file or line was captured'
      assert_includes source_html, 'state'
      assert_includes source_html, 'note_雪'
      assert_includes source_html, 'Recorded associations'
      assert_includes source_html, 'BriefFixture::Item'
      html = fresh.fetch('brief')
      assert_includes html, 'BriefFixture::Parent'
      assert_includes html, 'DeliveryJob.perform_later'
      assert_includes html, 'captured_source_potential'
      assert_includes html, Digest::SHA256.hexdigest(bytes)
      assert_includes html, 'opaque_or_incomplete_observed_method_descriptor'
      assert_includes fresh.fetch('source'), 'id="L10"'
      assert_includes fresh.fetch('source'), generation[0, 12]
      assert_equal 403, fresh.fetch('denied_status')
      assert_equal 404, fresh.fetch('missing_status')
    end
  end
end
