# frozen_string_literal: true

# Real hyperlinks over a pure Reader double. This is not installed/browser QA.
require_relative 'test_helper'
require 'cgi'

class NavigationJourneyTest < Minitest::Test
  include MapTestSupport
  FACT_ID = MapTestSupport::FACT_ID
  GENERATION = MapTestSupport::GENERATION
  ORIGIN = 'c' * 64
  TARGET = 'd' * 64
  REGISTRY = 'e' * 64
  SELECTION = 'f' * 64
  SEARCH = { 'q' => 'Order', 'domain' => 'metadata', 'kind' => 'rails_model', 'prefix' => 'app/' }.freeze

  class Reader < MapTestSupport::Reader
    attr_reader :calls, :closes
    attr_accessor :failure

    def initialize
      super
      @calls, @closes = [], 0
      @content = "class Order\n  def inspect = Order\nend\n"
      @facts = [[FACT_ID, 'Order', 'rails_model'], [ORIGIN, 'Inspection#inspect', 'method'],
        [TARGET, 'OrderCandidate', 'class'], [REGISTRY, 'Order callbacks', 'rails_save_callbacks']].map do |id, name, kind|
        { 'id' => id, 'name' => name, 'kind' => kind, 'evidence' => 'static', 'path' => 'app/order.rb',
          'location' => { 'start_byte' => 0, 'end_byte' => @content.bytesize, 'start_line' => 1, 'end_line' => 3 }, 'attributes' => {} }
      end
      @facts.last['attributes']['callbacks'] = { 'version' => 1, 'name' => 'Order', 'active_record_version' => 'saved',
        'save' => { 'status' => 'observed', 'entries' => [{ 'position' => 0, 'kind' => 'before', 'inherited' => false,
          'filter' => { 'kind' => 'method', 'name' => '<normalize>', 'owner' => 'Order', 'source' => { 'path' => 'app/order.rb', 'line' => 2 } },
          'if' => [], 'unless' => [] }] } }
      @manifest['schema_version'] = 3
      @manifest['files'] = [{ 'path' => 'app/order.rb', 'bytes' => @content.bytesize, 'sha256' => Digest::SHA256.hexdigest(@content) }]
    end

    def close = @closes += 1
    def fact(id)
      @calls << [:fact, id]
      super
    end
    def links(id)
      @calls << [:links, id]
      []
    end
    def source(id)
      @calls << [:source, id]
      super
    end
    def source_file(path)
      @calls << [:source_file, path]
      { 'generation' => generation, 'file' => manifest['files'].first, 'content' => @content, 'sha256' => Digest::SHA256.hexdigest(@content) }
    end
    def search_evidence(query, **options)
      @calls << [:search, query, options]
      { 'generation' => generation, 'status' => 'complete', 'truncated' => false,
        'results' => [{ 'origin' => 'metadata', 'name' => 'Order', 'fact_id' => FACT_ID, 'path' => nil }] }
    end

    def cursor(scope, offset)
      JSON.generate(['recorded-v1', generation, Digest::SHA256.hexdigest(JSON.generate(scope)), offset, 0])
    end
    def identity(id)
      @facts.find { |fact| fact['id'] == id }.slice('id', 'kind', 'name', 'path', 'location', 'evidence')
    end
    def family(items = [])
      { 'generation' => generation, 'fact_id' => FACT_ID, 'status' => 'observed', 'reason' => 'saved', 'provenance' => 'recorded_model_metadata',
        'known_omitted' => 0, 'unsearched' => false, 'items' => items }
    end
    def model_brief(id, **options)
      @calls << [:model_brief, id, options]
      raise failure if failure
      if (name = options[:family])
        offset = options[:cursor] ? JSON.parse(options[:cursor])[3] : 0
        items = (offset...[offset + 8, 11].min).map do |n|
          case name
          when 'columns' then { 'name' => "column#{n + 1}", 'type' => 'integer', 'null' => false }
          when 'associations' then { 'name' => "association#{n + 1}", 'macro' => 'has_many', 'target' => 'Item', 'polymorphic' => false, 'status' => 'recorded_label_binding_unknown' }
          else identity(TARGET)
          end
        end
        { 'version' => 1, 'generation' => generation, 'root' => identity(id), 'family' => name,
          'result' => family(items).merge('known_omitted' => 11 - offset - items.length), 'offset' => offset,
          'next_cursor' => offset.zero? ? cursor(['model_brief', id, name], 8) : nil,
          'capture_partial_or_unknown' => true, 'uncertainty' => 'No execution or binding inferred.' }
      else
        families = %w[columns associations registry_candidates callbacks incoming outgoing].to_h { |name| [name, family] }
        families['columns']['followup'] = { 'operation' => 'model_brief', 'generation' => generation, 'id' => id, 'family' => 'columns', 'cursor' => nil }
        { 'version' => 1, 'generation' => generation, 'root' => identity(id), 'families' => families,
          'uncertainty' => 'No execution inferred.', 'coverage' => {}, 'limits' => {}, 'usage' => {} }
      end
    end
    def references(id, direction:, cursor: nil, limit: 50, candidate_link: nil)
      @calls << [:references, id, { direction: direction, cursor: cursor, limit: limit, candidate_link: candidate_link }]
      raise failure if failure
      offset = cursor ? JSON.parse(cursor)[3] : 0
      if candidate_link
        return { 'generation' => generation, 'anchor' => identity(id), 'candidate_link' => candidate_link,
          'candidate_status' => 'ambiguous', 'candidate_search_complete' => true, 'candidate_matches' => 11,
          'coverage' => { 'capture_partial' => true }, 'candidates' => Array.new(offset.zero? ? 8 : 3) { identity(TARGET) },
          'next_cursor' => offset.zero? ? self.cursor(['references', id, false, candidate_link], 8) : nil }
      end
      rows = Array.new(limit == 8 ? (offset.zero? ? 8 : 3) : 1) do |n|
        { 'origin' => identity(ORIGIN), 'link' => { 'relation' => 'references', 'target' => "Order#{offset + n + 1}", 'resolution' => 'unresolved' },
          'detail_omitted' => false, 'candidate_matches' => 11, 'candidate_search_complete' => true, 'candidates' => [identity(TARGET)],
          'candidate_followup' => { 'generation' => generation, 'id' => ORIGIN, 'candidate_link' => 0 } }
      end
      { 'generation' => generation, 'anchor' => identity(id), 'direction' => direction, 'relationships' => rows,
        'coverage' => { 'known_matches' => rows.length, 'known_omitted' => offset.zero? ? 3 : 0, 'scan_complete' => offset > 0, 'capture_partial' => true },
        'next_cursor' => offset.zero? ? self.cursor(['references', id, direction == 'incoming', nil], 8) : nil }
    end
  end

  # Unlike the small journey double, this models a populated result set and
  # honors the requested limit and cursor. A default 50-row page must not hide
  # a collection-size rendering refusal behind a one-row fixture.
  class FullReferencesReader < Reader
    def references(id, direction:, cursor: nil, limit: 50, candidate_link: nil)
      return super if candidate_link

      @calls << [:references, id, { direction: direction, cursor: cursor, limit: limit }]
      offset = cursor ? JSON.parse(cursor)[3] : 0
      count = [limit, 50 - offset].min
      rows = Array.new(count) do |n|
        { 'origin' => identity(ORIGIN),
          'link' => { 'relation' => 'references', 'target' => "recorded-row-#{offset + n + 1}", 'resolution' => 'unresolved' },
          'detail_omitted' => false, 'candidate_matches' => 4, 'candidate_search_complete' => true,
          'candidates' => [FACT_ID, ORIGIN, TARGET, REGISTRY].map { |target| identity(target) } }
      end
      { 'generation' => generation, 'anchor' => identity(id), 'direction' => direction, 'relationships' => rows,
        'coverage' => { 'known_matches' => 50, 'known_omitted' => 50 - offset - count,
          'scan_complete' => offset + count == 50, 'capture_partial' => true },
        'next_cursor' => offset + count < 50 ? self.cursor(['references', id, direction == 'incoming', nil], offset + count) : nil }
    end
  end

  def query(extra = {})
    URI.encode_www_form(SEARCH.merge('generation' => GENERATION, 'selection' => SELECTION).merge(extra))
  end
  def href(html, label)
    escaped = html[/<a[^>]*href="([^"]+)"[^>]*>#{Regexp.escape(label)}<\/a>/, 1]
    refute_nil escaped, "Missing link #{label}"
    URI.parse(CGI.unescapeHTML(escaped))
  end
  def follow(app, uri, method: 'GET')
    request(app, uri.path, query: uri.query, method: method)
  end
  def assert_context(uri, ids: SELECTION)
    params = URI.decode_www_form(uri.query).to_h
    assert_equal SEARCH, params.slice(*SEARCH.keys)
    assert_equal GENERATION, params['generation']
    assert_equal ids, params['selection']
  end

  def test_find_model_collect_incoming_origin_and_candidate_source_return_to_results
    app = make_app(Reader.new)
    _, _, find = request(app, '/', query: query)
    source = URI.parse(CGI.unescapeHTML(find[/data-result-link href="([^"]+)"/, 1]))
    _, _, model = follow(app, source)
    collected = href(model, 'Collect in investigation')
    assert_equal '/source', collected.path
    selected = [SELECTION, FACT_ID].join(',')
    assert_context(collected, ids: selected)
    _, _, model = follow(app, collected)
    assert_context(href(model, 'Find'), ids: selected)
    links = href(model, 'Links')
    _, _, outgoing = follow(app, links)
    _, _, incoming = follow(app, href(outgoing, 'Incoming references'))
    origin = href(incoming, 'Captured Source: app/order.rb')
    assert_context(origin, ids: selected)
    _, _, origin_html = follow(app, origin)
    assert_context(href(origin_html, 'Find'), ids: selected)
    assert_context(href(origin_html, 'Investigation (2)'), ids: selected)
    candidate = incoming.scan(/href="([^"]+)"/).flatten.map { |url| URI.parse(CGI.unescapeHTML(url)) }.find do |uri|
      uri.path == '/source' && URI.decode_www_form(uri.query).to_h['id'] == TARGET
    end
    assert_context(candidate, ids: selected)
    _, _, candidate_html = follow(app, candidate)
    assert_context(href(candidate_html, 'Find'), ids: selected)
    removed = href(model, 'Remove from investigation')
    assert_equal '/source', removed.path
    assert_context(removed)
  end

  def test_callback_file_source_hop_and_focus_url_have_distinct_context_contracts
    app = make_app(Reader.new)
    _, _, callbacks = request(app, '/source', query: query('id' => REGISTRY))
    source = href(callbacks, 'Captured source (coherence unknown)')
    assert_context(source)
    params = URI.decode_www_form(source.query).to_h
    refute params.key?('id')
    assert_equal Digest::SHA256.hexdigest('app/order.rb'), params['file']
    assert_equal 'L2', source.fragment
    status, _, html = follow(app, source)
    assert_equal 200, status
    assert_context(href(html, 'Find'))
    # Empty selection needs no identity method on this old Reader double.
    _, _, collection = request(app, '/investigation', query: query('selection' => ''))
    focus = href(collection, 'Reopen this investigation')
    assert_includes collection, "This page's address can also carry your search"
    assert_equal({ 'generation' => GENERATION, 'selection' => '' }, URI.decode_www_form(focus.query).to_h)
    assert_equal SEARCH, URI.decode_www_form(href(collection, 'Find').query).to_h.slice(*SEARCH.keys)
  end

  def test_full_collection_links_and_next_page_fit_without_discarding_search_or_selection
    selected = (16...40).map { |n| n.to_s(16).rjust(64, '0') }.join(',')
    ['app/', '雪' * 150].each do |prefix|
      %w[incoming outgoing].each do |direction|
        reader = FullReferencesReader.new
        app = make_app(reader)
        search = SEARCH.merge('prefix' => prefix)
        encoded = URI.encode_www_form(search.merge('generation' => GENERATION,
          'selection' => selected, 'id' => FACT_ID, 'direction' => direction))
        assert_operator encoded.bytesize, :<=, 4096
        status, _, page = request(app, '/links', query: encoded)
        assert_equal 200, status
        call = reader.calls.find { |entry| entry.first == :references }
        assert_operator call.last[:limit], :<, 50
        assert_operator call.last[:limit], :>=, 1
        target = href(page, 'Next recorded references page')
        parameters = URI.decode_www_form(target.query).to_h
        assert_equal selected, parameters['selection']
        assert_equal search, parameters.slice(*search.keys)
        assert_equal call.last[:limit], JSON.parse(parameters.fetch('cursor'))[3]
        status, _, next_page = follow(app, target)
        assert_equal 200, status
        assert_includes next_page, "recorded-row-#{call.last[:limit] + 1}"
        assert_equal 2, reader.closes
      end
    end
  end

  def test_small_navigation_context_keeps_the_existing_fifty_row_links_limit
    reader = FullReferencesReader.new
    status, _, page = request(make_app(reader), '/links',
      query: query('selection' => '', 'id' => FACT_ID, 'direction' => 'incoming'))
    assert_equal 200, status
    assert_equal 50, reader.calls.find { |entry| entry.first == :references }.last[:limit]
    assert_includes page, 'recorded-row-50'
    refute_includes page, 'Next recorded references page'
  end

  def test_incoming_recorded_origin_links_open_outgoing_with_the_collection_intact
    reader = FullReferencesReader.new
    app = make_app(reader)
    status, _, page = request(app, '/links', query: query('id' => FACT_ID, 'direction' => 'incoming'))
    assert_equal 200, status
    origin = href(page, 'Inspection#inspect (method)')
    assert_context(origin)
    refute URI.decode_www_form(origin.query).to_h.key?('direction')
    assert_equal ORIGIN, URI.decode_www_form(origin.query).to_h['id']
    anchor_candidate = href(page, 'Order (rails_model); name match / binding unknown')
    assert_equal FACT_ID, URI.decode_www_form(anchor_candidate.query).to_h['id']
    refute URI.decode_www_form(anchor_candidate.query).to_h.key?('direction')
    status, _, = follow(app, origin)
    assert_equal 200, status
    assert_equal 'outgoing', reader.calls.reverse.find { |entry| entry.first == :references }.last[:direction]
  end

  def test_brief_entry_labels_describe_prefix_replay_and_reference_destinations
    reader = Reader.new
    def reader.model_brief(id, **options)
      super.tap do |result|
        next if options[:family]
        result['families']['incoming']['followup'] = { 'operation' => 'references',
          'generation' => generation, 'id' => id, 'direction' => 'incoming', 'cursor' => nil }
      end
    end
    app = make_app(reader)
    status, _, model = request(app, '/source', query: query('id' => FACT_ID))
    assert_equal 200, status
    columns = href(model, 'Browse all saved columns, eight per page')
    assert_equal '/brief/columns', columns.path
    assert_context(columns)
    status, _, first_page = follow(app, columns)
    assert_equal 200, status
    assert_includes first_page, 'column1'
    assert_includes first_page, 'column8'
    refute_includes first_page, 'column9'
    references = href(model, 'Inspect incoming references, up to eight per page')
    assert_equal '/references/incoming', references.path
    assert_context(references)
  end

  def test_model_family_and_reference_pages_reach_beyond_eight_without_expansion
    reader = Reader.new
    app = make_app(reader)
    code, _, page = request(app, '/brief/columns', query: query('id' => FACT_ID))
    assert_equal 200, code
    assert_includes page, 'column8'
    refute_includes page, 'column9'
    next_page = href(page, 'Next columns page')
    assert_context(next_page)
    code, _, page = follow(app, next_page)
    assert_equal 200, code
    assert_includes page, 'column9'
    assert_includes page, 'column11'
    refute_includes page, 'Next columns page'
    assert_equal [:model_brief, :model_brief], reader.calls.map(&:first)
    assert_equal({ family: 'columns', cursor: nil, limit: 8, max_bytes: 32768 }, reader.calls.first.last)
    reader.calls.clear
    code, _, page = request(app, '/references/incoming', query: query('id' => FACT_ID))
    assert_equal 200, code
    code, _, second = follow(app, href(page, 'Next recorded references page'))
    assert_equal 200, code
    assert_includes second, 'Order9'
    assert_includes second, 'Order11'
    refute_includes second, 'Next recorded references page'
    assert_equal [:references, :references], reader.calls.map(&:first)
    assert reader.calls.all? { |call| call.last[:limit] == 8 }
    assert_equal 4, reader.closes
  end

  def test_candidate_pages_preserve_scope_and_context_past_initial_candidates
    reader = Reader.new
    app = make_app(reader)
    code, _, page = request(app, '/references/outgoing', query: query('id' => FACT_ID))
    assert_equal 200, code
    browse = href(page, 'Browse recorded label candidates')
    assert_context(browse)
    code, _, candidates = follow(app, browse)
    assert_equal 200, code
    code, _, last = follow(app, href(candidates, 'Next recorded candidates page'))
    assert_equal 200, code
    refute_includes last, 'Next recorded candidates page'
    assert_equal 0, reader.calls.last.last[:candidate_link]
    assert_equal ORIGIN, reader.calls.last[1]
  end

  def test_other_model_families_keep_pinned_browser_continuation_without_ruby_selection
    %w[associations registry_candidates].each do |family|
      reader = Reader.new
      app = make_app(reader)
      code, _, page = request(app, "/brief/#{family}", query: query('id' => FACT_ID))
      assert_equal 200, code
      assert_includes page, 'Known omitted: 3'
      target = href(page, "Next #{family.tr('_', ' ')} page")
      assert_context(target)
      code, _, page = follow(app, target)
      assert_equal 200, code
      assert_includes page, 'Known omitted: 0'
      assert_includes page, '<noscript>'
      assert_equal [:model_brief, :model_brief], reader.calls.map(&:first)
      assert_equal 2, reader.closes
    end
  end

  def test_foreign_malformed_or_unscoped_cursors_refuse_before_open
    opened = 0
    app = Thistle::Map::App.new(store: '/unused', reader_factory: ->(*) { opened += 1; raise 'Must not open' })
    reader = Reader.new
    cursor = reader.cursor(['model_brief', FACT_ID, 'columns'], 8)
    [['/brief/associations', query('id' => FACT_ID, 'cursor' => cursor)],
      ['/brief/columns', query('id' => TARGET, 'cursor' => cursor)],
      ['/brief/columns', query('id' => FACT_ID, 'generation' => '0' * 64, 'cursor' => cursor)],
      ['/brief/columns', query('id' => FACT_ID, 'cursor' => 'x' * 513)],
      ['/brief/columns', query('id' => FACT_ID, 'cursor' => '{}')],
      ['/brief/columns', query('id' => FACT_ID, 'candidate' => '0')],
      ['/source', query('id' => FACT_ID, 'cursor' => cursor)],
      ['/references/incoming', query('id' => FACT_ID, 'candidate' => '0')]].each do |path, query|
      assert_equal 400, request(app, path, query: query).first
    end
    assert_equal 0, opened
  end

  def test_continuation_head_access_errors_and_close_without_partial_success
    reader = Reader.new
    app = make_app(reader)
    code, headers, body = request(app, '/brief/columns', query: query('id' => FACT_ID), method: 'HEAD')
    assert_equal 200, code
    assert_empty body
    assert_operator headers['content-length'].to_i, :>, 0
    assert_equal 403, request(app, '/brief/columns', query: query('id' => FACT_ID), env: { 'REMOTE_ADDR' => '192.0.2.4' }).first
    assert_equal 405, request(app, '/references/incoming', query: query('id' => FACT_ID), method: 'POST').first
    code, _, body = request(app, '/references/incoming', query: query('id' => FACT_ID), method: 'HEAD')
    assert_equal 200, code
    assert_empty body
    [Thistle::LimitExceeded.new, Thistle::NotFound.new, Thistle::InvalidInput.new].each do |error|
      reader.failure = error
      %w[/brief/columns /references/incoming].each do |path|
        code, _, body = request(app, path, query: query('id' => FACT_ID))
        assert_equal error.is_a?(Thistle::NotFound) ? 404 : 422, code
        refute_includes body, '<h1'
      end
    end
    assert_equal 8, reader.closes
  end

  def test_row_and_escaped_output_refusals_close_without_successful_partial_pages
    reader = Reader.new
    def reader.model_brief(id, **options)
      super.tap { |result| result['result']['items'] << result['result']['items'].first }
    end
    code, _, body = request(make_app(reader), '/brief/columns', query: query('id' => FACT_ID))
    assert_equal 422, code
    refute_includes body, 'column1'
    assert_equal 1, reader.closes
    reader = Reader.new
    def reader.references(id, **options)
      super.tap do |result|
        result['relationships'].each do |row|
          row['origin']['name'] = '&' * 4096
          row['candidates'] = Array.new(4) { row['origin'] }
        end
      end
    end
    code, _, body = request(make_app(reader), '/references/incoming', query: query('id' => FACT_ID))
    assert_equal 422, code
    refute_includes body, '<article>'
    assert_equal 1, reader.closes
  end
end
