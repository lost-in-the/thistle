# frozen_string_literal: true

require_relative 'test_helper'

class MapCallMetadataTest < Minitest::Test
  include MapTestSupport

  def test_call_anchors_respect_known_source_display_limits_without_loading_source
    [[Thistle::Map::View::MAX_SOURCE_BYTES, 2, true],
      [Thistle::Map::View::MAX_SOURCE_BYTES + 1, 2, false],
      [30_000, Thistle::Map::View::MAX_SOURCE_LINES + 1, false]].each do |bytes, line, anchored|
      location = { 'start_line' => line, 'end_line' => line, 'start_byte' => bytes - 6, 'end_byte' => bytes }
      fact = { 'id' => FACT_ID, 'name' => 'Demo', 'kind' => 'method', 'evidence' => 'static',
        'path' => 'demo.rb', 'location' => location, 'attributes' => {} }
      metadata = { 'version' => 1, 'safe_navigation' => false, 'call_location' => location,
        'receiver_location' => location, 'receiver' => { 'kind' => 'self', 'name' => nil, 'omitted_limit' => false } }
      link = { 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved',
        'attributes' => { 'thistle_call' => metadata } }
      reader = Reader.new(facts: [fact], links: [link])
      reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => bytes }]
      reader.define_singleton_method(:source) { |_| raise 'Links must not load source' }
      status, _, body = request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID))
      assert_equal 200, status
      assert_includes body, '<br>self ·'
      if anchored
        assert_includes body, "#L#{line}"
        refute_includes body, 'Source exceeds web display limits'
      else
        refute_includes body, "#L#{line}"
        assert_includes body, 'Source exceeds web display limits; use the Thistle source command.'
      end
    end
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
end
