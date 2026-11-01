# frozen_string_literal: true

# Direct App doubles: deliberately does not require test_helper or thistle/map.
require_relative 'model_reading_presenter_test'
# The opt-in pure process uses a highlighter double because it has no Rouge.
# Ordinary repository tests use their real loaded highlighter unchanged.
if ENV['THISTLE_MAP_PURE'] == '1' && !defined?(Thistle::Map::Highlighter)
  module Thistle::Map::Highlighter
    def self.lines(content, **) = content.lines.map { |line| ERB::Util.html_escape(line.chomp) }
    def self.language_for(*) = 'ruby'
  end
  $LOADED_FEATURES << File.expand_path('../lib/thistle/map/highlighter.rb', __dir__)
end
require_relative '../lib/thistle/map/app'
require 'cgi'

class ModelReadingAppTest < Minitest::Test
  include ModelReadingAnswers
  def request(reader, path, extra = {}, method: 'GET')
    app = Thistle::Map::App.new(store: '/unused', reader_factory: ->(*) { reader })
    params = { 'generation' => G, 'id' => MODEL, 'selection' => [MODEL, METHOD].join(','), 'q' => 'Order', 'domain' => 'metadata' }.merge(extra)
    status, headers, body = app.call('REQUEST_METHOD' => method, 'PATH_INFO' => path, 'SCRIPT_NAME' => '/map',
      'QUERY_STRING' => URI.encode_www_form(params), 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1')
    [status, headers, body.join]
  end

  def test_canonical_model_entry_skips_identity_and_exact_source_has_no_fact_fanout
    reader = Reader.new
    status, _, html = request(reader, "/models/#{MODEL}/source")
    assert_equal 200, status
    assert_equal [:comprehension, :comprehension, :source], reader.calls.map(&:first)
    assert reader.closed
    assert_includes html, '<details class="model-find"><summary>Search filters</summary>'
    assert_operator html.index('id="find-query"'), :<, html.index('<details class="model-find">')
    assert_includes html, '<noscript>'
    uri = html.scan(/href="([^"]+)"/).flatten.map { |href| URI(CGI.unescapeHTML(href)) }.find { |href| href.fragment == 'L2' }
    params = URI.decode_www_form(uri.query).to_h
    assert_equal [G, [MODEL, METHOD].join(','), 'Order', 'metadata', METHOD], params.values_at('generation', 'selection', 'q', 'domain', 'id')
    reader = Reader.new
    status, _, source = request(reader, uri.path.delete_prefix('/map'), params)
    assert_equal 200, status
    assert_equal [[:source, METHOD]], reader.calls
    assert_includes source, 'id="L2"'
    returned = source.scan(/href="([^"]+)"[^>]*>Return to model reading/).flatten.fetch(0)
    target = URI(CGI.unescapeHTML(returned))
    assert_equal "reading-file-#{Digest::SHA256.hexdigest(PATH)}-L2", target.fragment
    reader = Reader.new
    status, _, restored = request(reader, target.path.delete_prefix('/map'), URI.decode_www_form(target.query).to_h)
    assert_equal 200, status
    assert_includes restored, "id=\"#{target.fragment}\""
    assert_includes restored, 'name="selection" value="' + [MODEL, METHOD].join(',') + '"'
  end

  def test_legacy_entry_adds_only_one_compact_identity_and_head_closes
    reader = Reader.new
    assert_equal 200, request(reader, '/source')[0]
    assert_equal [:identity, :comprehension, :comprehension, :source], reader.calls.map(&:first)
    reader = Reader.new
    status, headers, body = request(reader, "/models/#{MODEL}/source", {}, method: 'HEAD')
    assert_equal 200, status
    assert_empty body
    assert_operator headers.fetch('content-length').to_i, :>, 0
    assert reader.closed
  end

  def test_invalid_model_scope_and_missing_generation_refuse_before_reader
    reader = Reader.new
    assert_equal 404, request(reader, '/models/invalid/source')[0]
    assert_equal 404, request(reader, "/models/#{MODEL}/investigation")[0]
    assert_equal 400, request(reader, "/models/#{MODEL}/source", { 'generation' => nil })[0]
    assert_empty reader.calls
  end

  def test_explicit_registry_shows_named_conditions_owner_and_physical_source_without_fanout
    reader = Reader.new
    reader.define_singleton_method(:callback_effects) do |id, **options|
      @calls << [:callbacks, id, options]
      { 'version' => 1, 'generation' => G, 'registry_id' => id, 'model' => 'Order', 'registry_status' => 'observed',
        'coherence' => 'unknown', 'execution' => 'unknown', 'coverage' => { 'truncated' => false },
        'callbacks' => [{ 'registry_id' => id, 'registry_provenance' => 'registered_metadata', 'position' => 0, 'kind' => 'after',
          'filter' => { 'kind' => 'method', 'name' => 'schedule_receipt', 'owner' => 'ReceiptPolicy' },
          'if' => [{ 'kind' => 'method', 'name' => 'receipt_due?', 'owner' => 'Order' }], 'unless' => [], 'inherited' => false,
          'explanation' => { 'status' => 'source_supported', 'reason' => 'Recorded descriptor matches saved source',
            'binding' => 'descriptor_matched_captured_declaration', 'source' => { 'path' => PATH, 'lines' => 5, 'bytes' => CONTENT.bytesize },
            'method' => { 'name' => 'ReceiptPolicy#schedule_receipt', 'span' => { 'start_line' => 2 } },
            'effects' => [{ 'operation' => 'ReceiptJob.perform_later' }] } }] }
    end
    status, _, html = request(reader, "/models/#{MODEL}/model-callbacks", { 'id' => 'e' * 64 })
    assert_equal 200, status
    assert_equal [[:callbacks, 'e' * 64, { limit: 8 }]], reader.calls
    %w[schedule_receipt receipt_due? ReceiptPolicy].each { |name| assert_includes html, name }
    assert_includes html, PATH
    assert_includes html, 'Execution unknown'
    assert reader.closed
  end

  def test_method_cursor_survives_physical_source_and_actual_return
    cursor = JSON.generate(['recorded-v1', G, Digest::SHA256.hexdigest(JSON.generate(['source_comprehension', MODEL, 'methods'])), 1, 0])
    prefix = "/models/#{MODEL}/from/methods/#{cursor.unpack1('H*')}"
    reader = Reader.new
    status, _, html = request(reader, prefix + '/comprehension/methods', { 'cursor' => cursor })
    assert_equal 200, status
    assert_equal [:comprehension, :source], reader.calls.map(&:first)
    target = html.scan(/href="([^"]+)"/).flatten.map { |href| URI(CGI.unescapeHTML(href)) }.find { |uri| uri.fragment == 'L2' }
    reader = Reader.new
    status, _, source = request(reader, target.path.delete_prefix('/map'), URI.decode_www_form(target.query).to_h)
    assert_equal 200, status
    returned = URI(CGI.unescapeHTML(source.match(/href="([^"]+)"[^>]*>Return to model reading/)[1]))
    params = URI.decode_www_form(returned.query).to_h
    assert_equal cursor, params['cursor']
    reader = Reader.new
    status, _, restored = request(reader, returned.path.delete_prefix('/map'), params)
    assert_equal 200, status
    assert_equal cursor, reader.calls.first[2][:cursor]
    assert_includes restored, "id=\"#{returned.fragment}\""
    assert_equal [[:source, METHOD]], reader.calls.select { |call| call.first == :source }
  end

  def test_return_to_nonadmitted_file_reveals_position_and_honest_exact_source_recovery
    reader = Reader.new; reader.oversized = true
    file = Digest::SHA256.hexdigest(PATH)
    status, _, restored = request(reader, "/models/#{MODEL}/at/#{file}/2/source")
    assert_equal 200, status
    assert_includes restored, 'Requested physical position is not displayed'
    assert_includes restored, "id=\"reading-file-#{file}-L2\""
    assert_includes restored, 'Open the exact captured file at line 2'
    assert_includes restored, 'No other source was substituted'
    assert_equal 0, reader.calls.count { |call| call.first == :source }
    assert_includes restored, 'name="selection" value="' + [MODEL, METHOD].join(',') + '"'
  end
end
