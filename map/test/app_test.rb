# frozen_string_literal: true

require_relative 'test_helper'

class MapAppTest < Minitest::Test
  include MapTestSupport

  def test_find_source_links_and_check_share_one_generation
    seen = []
    app = Thistle::Map::App.new(store: '/tmp/unused', reader_factory: ->(_, generation) { seen << generation; Reader.new(generation) })
    status, headers, body = request(app, '/', query: 'q=Demo')
    assert_equal 200, status
    assert_includes body, "generation=#{GENERATION}"
    assert_includes body, 'Demo#show'
    refute_includes body, 'Route conditions'
    assert_equal 'no-store', headers['cache-control']
    assert_nil seen.first
    %w[/source /links /check].each do |path|
      code, _, html = request(app, path, query: "id=#{FACT_ID}&generation=#{GENERATION}")
      assert_equal 200, code
      assert_includes html, 'live freshness not checked'
      assert_equal GENERATION, seen.last
    end
  end

  def test_source_is_escaped_and_security_headers_apply
    status, headers, body = request(make_app, '/source', query: "id=#{FACT_ID}")
    assert_equal 200, status
    refute_includes body, '<script>alert'
    assert_includes body, '&lt;script&gt;'
    assert_includes body, 'class="source-row selected" id="L2"'
    assert_includes headers['content-security-policy'], "frame-ancestors 'none'"
    refute_includes headers['content-security-policy'], 'unsafe-inline'
    assert_equal 'no-referrer', headers['referrer-policy']
    assert_equal 'nosniff', headers['x-content-type-options']
  end

  def test_query_and_fact_text_cannot_create_markup
    fact = Reader.new.fact(FACT_ID).merge('name' => '<img src=x onerror=alert(1)>', 'path' => 'x"><script>x</script>')
    status, _, body = request(make_app(Reader.new(facts: [fact])), '/', query: URI.encode_www_form('q' => '<img'))
    assert_equal 200, status
    refute_includes body, '<img'
    refute_includes body, '<script>x'
    assert_includes body, '&lt;img'
  end

  def test_route_condition_literals_keep_whitespace_and_controls_visible
    samples = {
      'Client A' => '&quot;Client A&quot;',
      'Client  A' => '&quot;Client  A&quot;',
      "line\tpart\n<img>\x7f" => '&quot;line\tpart\n&lt;img&gt;\u007f&quot;'
    }
    samples.each do |value, displayed|
      entries = [
        { 'key' => 'host', 'type' => 'string', 'value' => value, 'encoding' => 'UTF-8' },
        { 'key' => 'subdomain', 'type' => 'regexp', 'value' => value, 'options' => 1,
          'encoding' => 'UTF-8', 'regexp_encoding' => 'US-ASCII' }
      ]
      conditions = { 'status' => 'observed', 'request' => entries, 'segments' => [], 'opaque' => 'none observed' }
      fact = Reader.new.fact(FACT_ID).merge('kind' => 'route', 'attributes' => { 'route_constraints' => conditions })
      app = make_app(Reader.new(facts: [fact]))
      [['/', 'q=Demo'], ['/source', "id=#{FACT_ID}"]].each do |path, query|
        status, _, html = request(app, path, query: query)
        assert_equal 200, status
        assert_includes html, "string #{displayed}"
        assert_includes html, "pattern #{displayed}"
        assert_includes html, 'ignore letter case; options 1'
        assert_includes html, 'class="route-conditions"'
        refute_includes html, '<img>'
      end
    end
    status, _, css = request(make_app, '/assets/map.css')
    assert_equal 200, status
    assert_match(/\.route-conditions\{[^}]*white-space:pre-wrap/, css)
  end

  def test_malformed_or_oversized_route_conditions_are_unknown_before_formatting
    entry = { 'key' => 'host', 'type' => 'string', 'value' => 'test', 'encoding' => 'UTF-8' }
    hostile_string = Class.new(String) do
      def instance_of?(_) = true
      def bytesize = raise('subclass bytes read')
      def to_s = raise('subclass formatted')
      def to_json(*) = raise('subclass serialized')
    end.new('unsafe')
    invalid_entries = [
      entry.merge('value' => nil), entry.merge('value' => []),
      entry.merge('value' => '<' * 8_193), entry.merge('value' => hostile_string),
      entry.merge('encoding' => nil), entry.merge('encoding' => 'not-an-encoding'),
      entry.merge('type' => 'unsupported'), entry.merge('key' => nil),
      entry.merge('extra' => { 'nested' => Object.new }),
      *[-1, 1.5, '1', 2**64].map { |options| entry.merge('type' => 'regexp', 'regexp_encoding' => 'UTF-8', 'options' => options) }
    ]
    families = invalid_entries.map { |invalid| [invalid] } + [Array.new(33) { entry }]
    families.each do |family|
      conditions = { 'status' => 'observed', 'request' => family, 'segments' => [], 'opaque' => 'none observed' }
      fact = Reader.new.fact(FACT_ID).merge('kind' => 'route', 'attributes' => { 'route_constraints' => conditions })
      app = make_app(Reader.new(facts: [fact]))
      [['/', 'q=Demo'], ['/source', "id=#{FACT_ID}"]].each do |path, query|
        status, _, body = request(app, path, query: query)
        assert_equal 200, status
        assert_includes body, 'Unknown; conditions are invalid or exceed the display budget'
        refute_includes body, 'No conditions observed'
        assert_operator body.bytesize, :<, 10_000
      end
    end
  end

  def test_map_enforces_the_complete_encoded_constraint_family_boundary
    entry = { 'key' => 'host', 'type' => 'string', 'value' => '', 'encoding' => 'UTF-8' }
    overhead = JSON.generate([entry]).bytesize
    entry['value'] = 'x' * (8_192 - overhead)
    conditions = { 'status' => 'observed', 'request' => [entry], 'segments' => [], 'opaque' => 'none observed' }
    fact = Reader.new.fact(FACT_ID).merge('kind' => 'route', 'attributes' => { 'route_constraints' => conditions })
    app = make_app(Reader.new(facts: [fact]))
    assert_equal 8_192, JSON.generate(conditions['request']).bytesize
    status, _, accepted = request(app, '/', query: 'q=Demo')
    assert_equal 200, status
    assert_includes accepted, 'string &quot;xxxxx'
    refute_includes accepted, 'conditions are invalid'
    entry['value'] += 'x'
    status, _, refused = request(app, '/', query: 'q=Demo')
    assert_equal 200, status
    assert_includes refused, 'Unknown; conditions are invalid or exceed the display budget'
    refute_includes refused, 'string &quot;xxxxx'
  end

  def test_default_gate_rejects_remote_peers_rebinding_and_forwarded_headers
    [
      { 'REMOTE_ADDR' => '192.0.2.8' },
      { 'HTTP_HOST' => 'attacker.example' },
      { 'HTTP_HOST' => 'localhost.attacker.example' },
      { 'HTTP_HOST' => 'localhost:70000' },
      { 'HTTP_HOST' => 'localhost@attacker.example' },
      { 'REMOTE_ADDR' => '192.0.2.8', 'HTTP_X_FORWARDED_FOR' => '127.0.0.1' },
      { 'HTTP_HOST' => 'attacker.example', 'HTTP_X_FORWARDED_HOST' => 'localhost' },
      { 'HTTP_ORIGIN' => 'https://attacker.example' },
      { 'HTTP_ORIGIN' => 'null' },
      { 'HTTP_SEC_FETCH_SITE' => 'cross-site' }
    ].each { |env| assert_equal 403, request(make_app, env: env).first, env.inspect }
    assert_equal 200, request(make_app, env: { 'REMOTE_ADDR' => '::1', 'HTTP_HOST' => '[::1]' }).first
    assert_equal 200, request(make_app, env: { 'HTTP_ORIGIN' => 'http://localhost' }).first
  end

  def test_explicit_authorization_is_required_and_cannot_skip_host_check
    app = make_app(authorize: ->(env) { env['verified_user'] == 'reader' }, allowed_hosts: ['code.example'])
    assert_equal 403, request(app, env: { 'HTTP_HOST' => 'code.example', 'REMOTE_ADDR' => '192.0.2.8' }).first
    assert_equal 200, request(app, env: { 'HTTP_HOST' => 'code.example', 'REMOTE_ADDR' => '192.0.2.8', 'verified_user' => 'reader' }).first
    assert_equal 403, request(app, env: { 'HTTP_HOST' => 'evil.example', 'verified_user' => 'reader' }).first
    assert_equal 403, request(make_app(authorize: ->(_) { raise 'secret' })).first
  end

  def test_no_write_method_or_arbitrary_asset_reads
    %w[POST PUT PATCH DELETE OPTIONS].each do |method|
      status, headers, = request(make_app, method: method)
      assert_equal 405, status
      assert_equal 'GET, HEAD', headers['allow']
    end
    assert_equal 404, request(make_app, '/assets/../../Gemfile').first
    assert_equal 404, request(make_app, '/source/../../etc/passwd').first
    status, headers, body = request(make_app, '/assets/map.js')
    assert_equal 200, status
    assert_includes headers['content-type'], 'javascript'
    assert_includes body, 'event.isComposing'
  end

  def test_head_never_returns_a_body
    status, headers, body = request(make_app, method: 'HEAD')
    assert_equal 200, status
    assert_operator headers['content-length'].to_i, :>, 0
    assert_empty body
    assert_empty request(make_app, method: 'HEAD', env: { 'HTTP_HOST' => 'evil.example' }).last
  end

  def test_invalid_and_oversized_queries_fail_before_reader_opens
    calls = 0
    app = Thistle::Map::App.new(store: '/tmp/unused', reader_factory: ->(_, _) { calls += 1; Reader.new })
    [
      'id=../../etc/passwd', 'generation=latest', 'q=a&q=b', 'q=%xx', 'q=%00', 'q=%ff',
      'token=secret', 'page=0', 'page=-1', 'page=10000', 'q=' + ('a' * 257), 'q=' + ('a' * 4096)
    ].each { |query| assert_equal 400, request(app, query: query).first, query[0, 80] }
    assert_equal 0, calls
    assert_equal 400, request(app, '/source').first
    assert_equal 0, calls
  end

  def test_mounted_urls_stay_local_and_generation_pinned
    status, _, body = request(make_app, '/', query: 'q=Demo', env: { 'SCRIPT_NAME' => '/tools/thistle' })
    assert_equal 200, status
    assert_includes body, '/tools/thistle/source?'
    assert_includes body, '/tools/thistle/assets/map.js'
    assert_equal 400, request(make_app, env: { 'SCRIPT_NAME' => '//evil.example' }).first
    assert_equal 400, request(make_app, env: { 'SCRIPT_NAME' => '/a/../b' }).first
  end

  def test_unavailable_generation_is_not_replaced_and_errors_hide_paths
    calls = []
    app = Thistle::Map::App.new(store: '/tmp/unused', reader_factory: lambda { |_, generation|
      calls << generation
      raise Thistle::InvalidSnapshot, '/private/app/.thistle/generation is corrupt'
    })
    status, _, body = request(app, query: "generation=#{GENERATION}")
    assert_equal 422, status
    assert_equal [GENERATION], calls
    refute_includes body, '/private'
    assert_includes body, 'No other capture'
  end

  def test_consumer_rejects_a_reader_that_substitutes_a_different_capture
    app = make_app(Reader.new('c' * 64))
    assert_equal 422, request(app, query: "generation=#{GENERATION}").first
  end

  def test_consumer_rejects_source_from_another_generation
    reader = Reader.new
    def reader.source(id)
      super.merge('generation' => 'c' * 64)
    end
    assert_equal 422, request(make_app(reader), '/source', query: "id=#{FACT_ID}").first
  end

  def test_unexpected_errors_do_not_disclose_paths_or_source
    app = Thistle::Map::App.new(store: '/tmp/unused', reader_factory: ->(_, _) { raise 'secret source /private/project' })
    status, _, body = request(app)
    assert_equal 500, status
    refute_includes body, 'secret'
    refute_includes body, '/private'
  end

  def test_reader_handle_is_closed_after_success_or_failure
    reader = Reader.new
    closed = []
    reader.define_singleton_method(:close) { closed << true }
    app = make_app(reader)
    assert_equal 200, request(app).first
    assert_equal [true], closed
    assert_equal 404, request(app, '/source', query: "id=#{'c' * 64}").first
    assert_equal [true, true], closed
  end

  def test_large_source_is_refused_without_truncation
    app = make_app(Reader.new(content: 'x' * (Thistle::Map::View::MAX_SOURCE_BYTES + 1)))
    status, _, body = request(app, '/source', query: "id=#{FACT_ID}")
    assert_equal 422, status
    assert_includes body, 'complete file'
    assert_operator body.bytesize, :<, 512
  end

  def test_fact_with_no_source_keeps_its_context_and_explains_the_gap
    fact = Reader.new.fact(FACT_ID).merge('kind' => 'route', 'evidence' => 'runtime', 'path' => nil, 'location' => nil)
    reader = Reader.new(facts: [fact])
    def reader.source(_id)
      error = Thistle::Error.new('No captured file')
      error.instance_variable_set(:@native_code, 'source_unavailable')
      raise error
    end
    status, _, body = request(make_app(reader), '/source', query: "id=#{FACT_ID}")
    assert_equal 200, status
    assert_includes body, 'No file or line was captured'
    assert_includes body, 'Unknown; conditions were not captured'
    assert_includes body, '/links?'
    assert_includes body, "generation=#{GENERATION}"
  end

  def test_unavailable_source_requires_matching_identity_and_both_source_fields_absent
    original = Reader.new.fact(FACT_ID)
    [original, original.merge('path' => nil), original.merge('location' => nil),
     original.merge('id' => 'c' * 64, 'path' => nil, 'location' => nil)].each do |fact|
      reader = Reader.new
      reader.define_singleton_method(:fact) { |_id| fact }
      def reader.source(_id)
        error = Thistle::Error.new('source failure')
        error.instance_variable_set(:@native_code, 'source_unavailable')
        raise error
      end
      assert_equal 422, request(make_app(reader), '/source', query: "id=#{FACT_ID}").first
    end
  end

  def test_other_errors_do_not_attempt_source_less_fallback
    fact = Reader.new.fact(FACT_ID).merge('path' => nil, 'location' => nil)
    reader = Reader.new(facts: [fact])
    lookups = []
    reader.define_singleton_method(:fact) { |id| lookups << id; fact }
    def reader.source(_id)
      raise Thistle::InvalidSnapshot, 'corrupt source'
    end
    assert_equal 422, request(make_app(reader), '/source', query: "id=#{FACT_ID}").first
    assert_empty lookups
  end

  def test_links_are_paged_and_unresolved_targets_are_not_promoted_to_hyperlinks
    links = 51.times.map { |i| { 'relation' => 'calls', 'target' => "method#{i}", 'resolution' => 'unresolved' } }
    app = make_app(Reader.new(links: links))
    _, _, first = request(app, '/links', query: "id=#{FACT_ID}")
    assert_includes first, 'Page 1 of 2'
    refute_includes first, '<td>method50</td>'
    refute_match(/href=[^>]*method0/, first)
    _, _, second = request(app, '/links', query: "id=#{FACT_ID}&page=2")
    assert_includes second, '<td>method50</td>'
    assert_equal 422, request(app, '/links', query: "id=#{FACT_ID}&page=3").first
  end
end
