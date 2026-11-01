# frozen_string_literal: true

# Direct App doubles: deliberately does not require test_helper or thistle/map.
require_relative 'model_reading_presenter_test'
# The opt-in pure process uses a highlighter double because it has no Rouge.
# Ordinary repository tests use their real loaded highlighter unchanged.
if ENV['THISTLE_MAP_PURE'] == '1' && !defined?(Thistle::Map::Highlighter)
  module Thistle::Map::Highlighter
    def self.lines(content, **) = content.lines.map { |line| '<span class="cm">' + ERB::Util.html_escape(line.chomp) + '</span>' }
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
    params = { 'generation' => G, 'id' => MODEL, 'selection' => [MODEL, METHOD].join(','), 'q' => 'Order', 'domain' => 'metadata' }.merge(extra).reject { |_, value| value == :omit }
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
    assert_includes html, '<details class="model-find"><summary>Search filters — domain: metadata</summary>'
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
    assert_match(/<div class="source-row[^"]*" id="#{Regexp.escape(target.fragment)}">/, restored)
    refute_includes restored, 'Requested physical position is not displayed'
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
    status, _, refusal = request(reader, "/models/#{MODEL}/source", { 'generation' => :omit })
    assert_equal 400, status
    assert_includes refusal, 'Model reading requires an explicit saved generation'
    assert_empty reader.calls
  end

  def callback_reader(partial: false)
    reader = Reader.new
    reader.define_singleton_method(:callback_effects) do |id, **options|
      @calls << [:callbacks, id, options]
      ModelReadingAnswers.callback_answer(id, limit: options.fetch(:limit), partial: partial)
    end
    reader
  end

  def test_full_registered_recovery_reaches_ninth_target_with_context_and_shared_visible_coverage
    registry = 'e' * 64
    file = Digest::SHA256.hexdigest(PATH)
    cursor = JSON.generate(['recorded-v1', G, Digest::SHA256.hexdigest(JSON.generate(['source_comprehension', MODEL, 'methods'])), 1, 0])
    prefix = "/models/#{MODEL}/from/methods/#{cursor.unpack1('H*')}/at/#{file}/2"
    reader = callback_reader
    status, _, compact = request(reader, prefix + '/model-callbacks', { 'id' => registry })
    assert_equal 200, status
    assert_equal [[:callbacks, registry, { limit: 8 }]], reader.calls
    refute_includes compact, 'schedule_receipt'
    target = compact.match(/href="([^"]+)"[^>]*>Full registered callbacks \(up to 200\)/)
    refute_nil target
    uri = URI(CGI.unescapeHTML(target[1]))
    assert_equal prefix + '/model-callbacks/full', uri.path.delete_prefix('/map')
    params = URI.decode_www_form(uri.query).to_h
    assert_equal [G, [MODEL, METHOD].join(','), 'Order', registry], params.values_at('generation', 'selection', 'q', 'id')
    reader = callback_reader(partial: true)
    status, _, html = request(reader, uri.path.delete_prefix('/map'), params)
    assert_equal 200, status
    assert_equal [[:callbacks, registry, { limit: 200 }]], reader.calls
    %w[schedule_receipt receipt_due? ReceiptPolicy].each { |name| assert_includes html, name }
    ['Known potential effects omitted: 2', 'Potential effects are non-exhaustive', 'Explanation incomplete:',
      'Source evidence not searched for 1', 'Capture is partial or unknown'].each do |notice|
      assert_includes html, notice
      assert_operator html.index(notice), :<, html.index('Registry identity, coverage and limits')
    end
    assert_includes html, 'Showing at most 200'
    assert_includes html, PATH
    assert_includes html, 'Observed execution: unknown'
    returned = URI(CGI.unescapeHTML(html.match(/href="([^"]+)"[^>]*>Return to model reading/)[1]))
    assert_equal cursor, URI.decode_www_form(returned.query).to_h['cursor']
    assert_equal "reading-file-#{file}-L2", returned.fragment
    status, _, restored = request(Reader.new, returned.path.delete_prefix('/map'), URI.decode_www_form(returned.query).to_h)
    assert_equal 200, status
    assert_match(/<div class="source-row[^"]*" id="#{Regexp.escape(returned.fragment)}">/, restored)
    refute_includes restored, 'Requested physical position is not displayed'
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
    assert_match(/<div class="source-row[^"]*" id="#{Regexp.escape(returned.fragment)}">/, restored)
    refute_includes restored, 'Requested physical position is not displayed'
    assert_equal [[:source, METHOD]], reader.calls.select { |call| call.first == :source }
  end

  def test_return_to_nonadmitted_file_reveals_position_and_honest_exact_source_recovery
    reader = Reader.new; reader.oversized = true
    file = Digest::SHA256.hexdigest(PATH)
    status, _, restored = request(reader, "/models/#{MODEL}/at/#{file}/2/source")
    assert_equal 200, status
    assert_includes restored, 'Requested physical position is not displayed'
    assert_includes restored, "id=\"reading-position-unavailable-#{file}-L2\""
    refute_match(/<div class="source-row[^"]*" id="reading-file-#{file}-L2">/, restored)
    assert_includes restored, 'Open the exact captured file at line 2'
    assert_includes restored, 'No other source was substituted'
    assert_equal 0, reader.calls.count { |call| call.first == :source }
    assert_includes restored, 'name="selection" value="' + [MODEL, METHOD].join(',') + '"'
  end

  def test_two_thousand_admitted_physical_rows_fit_without_duplicate_per_line_ids
    reader = Reader.new
    # A real-shaped Ruby file with comment colour/escaping and a complete suffix.
    content = "class Order\n" + ("  # <&> saved source\n" * 1998) + "end # complete_suffix\n"
    reader.use_content(content)
    ids = [MODEL, METHOD] + (1..22).map { |n| n.to_s(16).rjust(64, '0') }
    status, _, html = request(reader, "/models/#{MODEL}/source", { 'selection' => ids.join(','), 'q' => 'q' * 256 })
    assert_equal 200, status
    assert_operator content.bytesize, :<=, 65_536
    assert_equal 2000, html.scan(/<div class="source-row/).length
    assert_equal 2000, html.scan(/class="ln"/).length
    assert_equal 2000, html.scan(/id="reading-file-/).length
    refute_match(/<span id="reading-file-/, html)
    assert_match(/<div class="source-row[^\"]*" id="reading-file-#{Digest::SHA256.hexdigest(PATH)}-L2000">/, html)
    assert_includes html, 'complete_suffix'
    assert_includes html, '&lt;&amp;&gt;'
    assert_operator html.bytesize, :<=, Thistle::Map::SourceComprehensionPresenter::MAX_BODY_BYTES + 65_536
    assert_equal [:comprehension, :comprehension, :source], reader.calls.map(&:first)
  end

  def test_response_budget_refusal_is_explanatory_and_identity_corruption_stays_invalid
    reader = Reader.new
    original = reader.method(:source_comprehension)
    reader.define_singleton_method(:source_comprehension) { |*args, **options| original.call(*args, **options).merge('semantics' => 'x' * 32768) }
    status, _, body = request(reader, "/models/#{MODEL}/source")
    assert_equal 422, status
    assert_includes body, 'display budget'
    refute_includes body, 'missing or invalid'
    assert_equal [:comprehension], reader.calls.map(&:first)
    reader = Reader.new; reader.bad_generation = true
    status, _, body = request(reader, "/models/#{MODEL}/source")
    assert_equal 422, status
    assert_includes body, 'missing or invalid'
    reader = callback_reader
    original = reader.method(:callback_effects)
    reader.define_singleton_method(:callback_effects) { |*args, **options| original.call(*args, **options).merge('semantics' => 'x' * 32768) }
    status, _, body = request(reader, "/models/#{MODEL}/model-callbacks", { 'id' => 'e' * 64 })
    assert_equal 422, status
    assert_includes body, 'response budget'
    refute_includes body, 'missing or invalid'
  end

  def test_legacy_brief_keeps_partial_capture_and_absence_qualification_visible
    reader = Reader.new
    reader.define_singleton_method(:model_brief) do |id, **options|
      @calls << [:brief, id, options]
      { 'version' => 1, 'generation' => G, 'family' => options.fetch(:family), 'root' => root,
        'uncertainty' => 'Saved declarations only.', 'capture_partial_or_unknown' => true, 'offset' => 0,
        'result' => { 'generation' => G, 'fact_id' => id, 'status' => 'partial', 'reason' => 'capture partial',
          'provenance' => 'recorded_model', 'known_omitted' => 0, 'unsearched' => false, 'items' => [] } }
    end
    status, _, html = request(reader, '/brief/columns')
    assert_equal 200, status
    assert_match(/<p class="notice ui">Capture partial or unknown: true\. Empty or omitted evidence does not establish absence\.<\/p>/, html)
    assert_operator html.index('Capture partial or unknown'), :<, html.index('<details><summary>Page scope')
  end

  def test_other_model_source_has_own_named_entry_without_legacy_brief_fanout
    other = 'f' * 64
    reader = Reader.new
    reader.define_singleton_method(:source) do |id|
      @calls << [:source, id]
      error = Thistle::Error.new('No source'); error.instance_variable_set(:@native_code, 'source_unavailable'); raise error
    end
    reader.define_singleton_method(:fact_identity) do |id|
      @calls << [:identity, id]
      { 'generation' => G, 'fact' => root.merge('id' => other, 'name' => 'User') }
    end
    status, _, html = request(reader, "/models/#{MODEL}/source", { 'id' => other })
    assert_equal 200, status
    assert_equal [[:source, other], [:identity, other]], reader.calls
    assert_includes html, 'Read User in its own model context'
    assert_includes html, "/models/#{other}/source?"
    assert_includes html, "/models/#{MODEL}/comprehension/contributions?"
  end
end
