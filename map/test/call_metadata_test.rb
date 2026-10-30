# frozen_string_literal: true

require_relative 'test_helper'

class MapCallMetadataTest < Minitest::Test
  include MapTestSupport

  def test_call_anchors_respect_source_byte_limit
    [Thistle::Map::View::MAX_SOURCE_BYTES, Thistle::Map::View::MAX_SOURCE_BYTES + 1].each do |bytes|
      content = 'self' + 'x' * (bytes - 4)
      location = { 'start_line' => 1, 'end_line' => 1, 'start_byte' => 0, 'end_byte' => 4 }
      fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
        'path' => 'demo.rb', 'location' => location, 'attributes' => {} }
      metadata = { 'version' => 1, 'safe_navigation' => false, 'call_location' => location,
        'receiver_location' => location, 'receiver' => { 'kind' => 'self', 'name' => nil, 'omitted_limit' => false } }
      link = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved',
        'attributes' => { 'thistle_call' => metadata } }
      reader = Reader.new(facts: [fact], links: [link], content: content)
      reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => bytes, 'sha256' => Digest::SHA256.hexdigest(content) }]
      calls = 0
      reader.define_singleton_method(:source) { |id| calls += 1; super(id) }
      body = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID)).last
      assert_includes body, '<br>self ·'
      if bytes == Thistle::Map::View::MAX_SOURCE_BYTES
        assert_equal 1, calls
        assert_includes body, '#L1'
      else
        assert_equal 0, calls
        refute_includes body, '#L1'
        assert_includes body, 'Source exceeds web display limits'
        assert_includes body, "For call line 1, use <code>thistle source #{FACT_ID} --store STORE --generation #{GENERATION}</code>"
      end
    end
  end

  def test_total_newline_budget_and_line_byte_correspondence
    location = { 'start_line' => 1, 'end_line' => 1, 'start_byte' => 0, 'end_byte' => 4 }
    fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => location, 'attributes' => {} }
    metadata = { 'version' => 1, 'safe_navigation' => false, 'call_location' => location,
      'receiver_location' => location, 'receiver' => { 'kind' => 'self', 'name' => nil, 'omitted_limit' => false } }
    link = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved',
      'attributes' => { 'thistle_call' => metadata } }
    [10_000, 10_001].each do |count|
      content = 'self' + "\n" * count
      reader = Reader.new(facts: [fact], links: [link, link], content: content)
      reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => content.bytesize, 'sha256' => Digest::SHA256.hexdigest(content) }]
      calls = 0
      reader.define_singleton_method(:source) { |id| calls += 1; super(id) }
      body = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID)).last
      assert_equal 1, calls
      if count == 10_000
        assert_includes body, '#L1'
      else
        refute_includes body, '#L1'
        assert_includes body, 'Source exceeds web display limits'
        assert_includes body, "--generation #{GENERATION}"
      end
    end
    bad = metadata.merge('call_location' => location.merge('start_line' => 2, 'end_line' => 2))
    reader = Reader.new(facts: [fact], links: [link.merge('attributes' => { 'thistle_call' => bad })], content: 'self')
    reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => 4, 'sha256' => Digest::SHA256.hexdigest('self') }]
    body = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID)).last
    assert_includes body, 'Receiver details unavailable'
    refute_includes body, '#L2'
  end

  def test_source_identity_and_newline_byte_boundaries
    content = "abc\ndef"
    location = { 'start_line' => 1, 'end_line' => 2, 'start_byte' => 3, 'end_byte' => 4 }
    fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => location, 'attributes' => {} }
    metadata = { 'version' => 1, 'safe_navigation' => false, 'call_location' => location,
      'receiver_location' => location, 'receiver' => { 'kind' => 'self', 'name' => nil, 'omitted_limit' => false } }
    link = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved',
      'attributes' => { 'thistle_call' => metadata } }
    reader = Reader.new(facts: [fact], links: [link], content: content)
    reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => content.bytesize, 'sha256' => Digest::SHA256.hexdigest(content) }]
    query = URI.encode_www_form('id' => FACT_ID)
    assert_includes request(make_app(reader), '/links', query: query).last, '#L1'
    reader.define_singleton_method(:source) { |id| super(id).merge('generation' => 'wrong') }
    body = request(make_app(reader), '/links', query: query).last
    assert_includes body, 'Receiver details unavailable'
    refute_includes body, '#L1'
  end

  def test_legacy_links_do_not_load_source
    reader = Reader.new
    reader.define_singleton_method(:source) { |_| raise 'unexpected source read' }
    assert_equal 200, request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID)).first
  end

  def test_spoofed_metadata_types_do_not_format_objects_or_create_anchors
    formatted = false
    name = Object.new
    name.define_singleton_method(:instance_of?) { |klass| klass == String }
    name.define_singleton_method(:empty?) { false }
    name.define_singleton_method(:bytesize) { 1 }
    name.define_singleton_method(:to_s) { formatted = true; raise 'unexpected formatting' }
    hash_type = Class.new(Hash) do
      def instance_of?(klass) = klass == Hash
      def keys = raise('unexpected keys callback')
    end
    location = { 'start_line' => 2, 'end_line' => 2, 'start_byte' => 8, 'end_byte' => 14 }
    metadata = { 'version' => 1, 'safe_navigation' => false, 'call_location' => location,
      'receiver_location' => location, 'receiver' => { 'kind' => 'local', 'name' => 'x', 'omitted_limit' => false } }
    cases = [metadata.merge('receiver' => metadata['receiver'].merge('name' => name)),
      hash_type.new.update(metadata), metadata.merge('call_location' => hash_type.new.update(location)),
      metadata.merge('call_location' => location.merge('end_byte' => 31))]
    fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => location.merge('start_byte' => 0, 'end_byte' => 30), 'attributes' => {} }
    cases.each do |data|
      link = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved',
        'attributes' => { 'thistle_call' => data } }
      reader = Reader.new(facts: [fact], links: [link])
      reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => 30 }]
      status, _, body = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID))
      assert_equal 200, status
      assert_includes body, 'Receiver details unavailable'
      refute_includes body, '#L2'
      refute formatted
    end
  end

  def test_unknown_and_malformed_metadata_never_create_source_anchors
    fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => { 'start_line' => 1, 'end_line' => 2, 'start_byte' => 0, 'end_byte' => 30 }, 'attributes' => {} }
    base = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved' }
    [ { 'version' => 2, 'receiver' => { 'kind' => '<script>' } },
      { 'version' => 1, 'receiver' => { 'kind' => '<script>' }, 'call_location' => { 'start_line' => 999 } },
      { 'version' => 1, 4 => 'unexpected' } ].each do |metadata|
      reader = Reader.new(facts: [fact], links: [base.merge('attributes' => { 'thistle_call' => metadata })])
      status, _, body = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID))
      assert_equal 200, status
      assert_includes body, 'Receiver details unavailable'
      refute_includes body, '#L999'
      refute_includes body, '<script>'
    end
  end
  def test_compact_receiver_null_check_does_not_dispatch_adapter_callbacks
    content = 'self.render'
    fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => {}, 'attributes' => {} }
    [true, :raise].each do |answer|
      called = false
      receiver = Object.new
      receiver.define_singleton_method(:nil?) do
        called = true
        raise 'unexpected nil? callback' if answer == :raise
        answer
      end
      metadata = { 'version' => 2, 'data' => ['implicit', nil, false, false, [0, 11, 1, 1], receiver] }
      link = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved',
        'attributes' => { 'thistle_call' => metadata } }
      reader = Reader.new(facts: [fact], links: [link], content: content)
      reader.manifest['schema_version'] = 2
      reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => content.bytesize, 'sha256' => Digest::SHA256.hexdigest(content) }]
      status, _, body = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID))
      assert_equal 200, status
      assert_includes body, 'Receiver details unavailable'
      refute_includes body, '#L1'
      refute called
    end
  end

  def test_compact_calls_require_explicit_schema_two_or_three_and_validate_fields
    content = 'self.render'
    loc = [0, 11, 1, 1]
    fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => {}, 'attributes' => {} }
    tuple = ['local', '<x>', false, true, loc, [0, 4, 1, 1]]
    metadata = { 'version' => 2, 'data' => tuple }
    link = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved',
      'attributes' => { 'thistle_call' => metadata } }
    reader = Reader.new(facts: [fact], links: [link], content: content)
    reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => content.bytesize, 'sha256' => Digest::SHA256.hexdigest(content) }]
    page = -> { request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID)).last }
    [nil, 1, '2', '3', 3.0, 4].each do |schema|
      reader.manifest['schema_version'] = schema
      assert_includes page.call, 'Receiver details unavailable'
      refute_includes page.call, '#L1'
    end
    [3, 2].each do |schema|
      reader.manifest['schema_version'] = schema
      html = page.call
      assert_includes html, 'local &lt;x&gt; · safe navigation'
      assert_includes html, 'Representative source'
      assert_includes html, '#L1'
    end
    %w[self call literal expression instance_variable].each do |kind|
      name = kind == 'instance_variable' ? '@x' : nil
      tuple.replace([kind, name, false, false, loc, [0, 4, 1, 1]])
      refute_includes page.call, 'Receiver details unavailable'
    end
    tuple.replace(['implicit', nil, false, false, loc, nil])
    assert_includes page.call, 'implicit receiver'
    tuple.replace(['constant', nil, true, false, loc, [0, 4, 1, 1]])
    assert_includes page.call, 'constant — name omitted (limit)'
    tuple.replace(['local', 'x' * 256, false, false, loc, [0, 4, 1, 1]])
    assert_includes page.call, 'local ' + 'x' * 256
    tuple[1] = 'x' * 257
    assert_includes page.call, 'Receiver details unavailable'
    [ ['self', nil, false, false, [0, 11, 2, 2], [0, 4, 1, 1]],
      ['implicit', nil, false, true, loc, nil],
      ['self', nil, false, false, loc, [0, 4, 1]],
      ['self', nil, false, false, loc, [0, 4, 1, 1], 'extra'] ].each do |invalid|
      metadata['data'] = invalid
      html = page.call
      assert_includes html, 'Receiver details unavailable'
      refute_includes html, '#L1'
    end
  end

  def test_schema_three_extended_call_objects_keep_validated_receiver_details
    content = 'self.render'
    fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => {}, 'attributes' => {} }
    opaque = Object.new
    opaque.define_singleton_method(:to_s) { raise 'unexpected extension formatting' }
    tuple = ['self', nil, false, false, [0, 11, 1, 1], [0, 4, 1, 1]]
    metadata = { 'version' => 2, 'data' => tuple, 'future' => opaque }
    link = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved',
      'attributes' => { 'thistle_call' => metadata } }
    reader = Reader.new(facts: [fact], links: [link], content: content)
    reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => content.bytesize, 'sha256' => Digest::SHA256.hexdigest(content) }]
    page = -> { request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID)).last }
    [nil, 1, 2, '3', 3.0].each do |schema|
      reader.manifest['schema_version'] = schema
      assert_includes page.call, 'Receiver details unavailable'
      refute_includes page.call, '#L1'
    end
    reader.manifest['schema_version'] = 3
    html = page.call
    assert_includes html, '<br>self ·'
    assert_includes html, 'Representative source'
    assert_includes html, '#L1'
    assert_includes html, "generation=#{GENERATION}"
    assert_same opaque, metadata['future']
    assert_same tuple, metadata['data']
    metadata['data'] = tuple[0...5]
    assert_includes page.call, 'Receiver details unavailable'
    refute_includes page.call, '#L1'
    metadata['data'] = tuple
    tuple[3] = 'false'
    assert_includes page.call, 'Receiver details unavailable'
    refute_includes page.call, '#L1'
  end

end
