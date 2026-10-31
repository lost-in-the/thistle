# frozen_string_literal: true

require_relative 'test_helper'
require 'uri'

class MapConstantOccurrenceTest < Minitest::Test
  include MapTestSupport

  SOURCE = "class Demo\n  def show\n    take(Widget)\n    value = Widget\n  end\nend\n"

  def origin(content = SOURCE)
    { 'id' => FACT_ID, 'name' => 'Demo#show', 'kind' => 'method', 'evidence' => 'static',
      'path' => 'demo.rb', 'location' => { 'start_byte' => 0, 'end_byte' => content.bytesize,
        'start_line' => 1, 'end_line' => content.lines.length }, 'attributes' => {} }
  end

  def occurrence(content = SOURCE, offset: content.index('Widget'), role: 'argument', syntax: 'Widget')
    first = content.byteslice(0, offset).count("\n") + 1
    last = first + syntax.count("\n")
    { 'relation' => 'references_constant', 'target' => 'Widget', 'resolution' => 'unresolved',
      'attributes' => { 'thistle_constant' => { 'version' => 1, 'syntax' => syntax, 'rooted' => false,
        'lexical_scope' => 'Demo', 'role' => role, 'location' => [offset, offset + syntax.bytesize, first, last] } } }
  end

  def reader_with(links, content = SOURCE, schema: 3)
    reader = Reader.new(facts: [origin(content)], content: content, links: links)
    reader.manifest['schema_version'] = schema
    reader.manifest['files'] = [{ 'path' => 'demo.rb', 'bytes' => content.bytesize,
      'sha256' => Digest::SHA256.hexdigest(content) }]
    reader
  end

  def page(reader)
    request(make_app(reader), '/links', query: URI.encode_www_form('id' => FACT_ID, 'generation' => GENERATION)).last
  end

  def presenter
    Thistle::Map::ConstantOccurrence.new(generation: GENERATION, mount: '/map', schema_version: 3)
  end

  def test_two_same_target_sites_show_line_role_syntax_and_source_with_one_source_read
    links = [occurrence, occurrence(offset: SOURCE.rindex('Widget'), role: 'value')]
    reader = reader_with(links)
    reads = 0
    reader.define_singleton_method(:source) { |id| reads += 1; super(id) }
    html = page(reader)
    assert_equal 1, reads
    assert_equal 2, html.scan('class="constant-site"').length
    assert_includes html, 'Line 3 · Role: argument'
    assert_includes html, 'Line 4 · Role: value'
    assert_equal 2, html.scan('<code>Widget</code>').length
    [3, 4].each do |line|
      assert_includes html, "#L#{line}"
      assert_includes html, "Captured Source line #{line}</a>"
    end
    assert_includes html, "generation=#{GENERATION}"
    assert_includes html, 'Binding unknown'
    assert_includes html, '<noscript>'
    refute_match(/onclick=/, html)
  end

  def test_same_line_sites_keep_distinct_byte_spans
    content = 'Widget; Widget'
    fact = origin(content)
    html = [0, 8].map { |offset| presenter.render(occurrence(content, offset: offset, role: 'value'), origin: fact) }
    assert_includes html.first, 'Bytes 0–6'
    assert_includes html.last, 'Bytes 8–14'
    refute_equal html.first, html.last
  end

  def test_references_render_compact_sites_and_omissions_without_expanding_origins
    links = [occurrence, occurrence(offset: SOURCE.rindex('Widget'), role: 'value')]
    reader = reader_with(links)
    def reader.fact(*) = raise('Incoming occurrence expanded fact')
    def reader.links(*) = raise('Incoming occurrence expanded links')
    def reader.source(*) = raise('Incoming occurrence expanded Source')
    fact = origin
    reader.define_singleton_method(:references) do |id, direction:|
      { 'generation' => generation, 'anchor' => fact, 'direction' => direction,
        'coverage' => { 'known_matches' => 2, 'known_omitted' => 1, 'scan_complete' => false, 'capture_partial' => true },
        'relationships' => links.map { |link| { 'origin' => fact, 'link' => link, 'detail_omitted' => false,
          'candidates' => [], 'candidate_matches' => 0, 'candidate_search_complete' => false } } }
    end
    status, _, html = request(make_app(reader), '/links', query: "id=#{FACT_ID}&direction=incoming")
    assert_equal 200, status
    assert_equal 2, html.scan('class="constant-site"').length
    assert_includes html, '#L3'
    assert_includes html, '#L4'
    assert_includes html, '1 known omitted'
    assert_includes html, 'Relationship scan incomplete'
    assert_includes html, 'Capture partial'
    row = { 'origin' => fact, 'link' => links.first.slice('relation', 'target', 'resolution'), 'detail_omitted' => true,
      'candidates' => [], 'candidate_matches' => 0, 'candidate_search_complete' => true }
    result = { 'generation' => GENERATION, 'direction' => 'incoming', 'coverage' => {
      'known_matches' => 1, 'known_omitted' => 0, 'scan_complete' => true, 'capture_partial' => true }, 'relationships' => [row] }
    omitted = Thistle::Map::ReferencesPresenter.new(generation: GENERATION, mount: '', schema_version: 3).render(result)
    assert_includes omitted, 'Constant site details unavailable'
    assert_includes omitted, 'Link detail omitted by display budget'
    refute_match(/#L\d/, omitted)
  end

  def test_publisher_syntax_is_escaped_and_whitespace_preserved_without_inventing_binding
    syntax = "<script>\n& \"quoted\""
    link = occurrence(syntax, offset: 0, role: 'value', syntax: syntax)
    html = presenter.render(link, origin: origin(syntax))
    assert_includes html, "&lt;script&gt;\n&amp; &quot;quoted&quot;"
    assert_includes html, 'class="check-data"'
    assert_includes html, 'Binding unknown'
    refute_includes html, '<script>'
  end

  def test_malformed_opaque_and_missing_locations_never_create_site_anchors_or_source_reads
    base = occurrence
    changes = [nil, {}, { 'version' => 9 }, base['attributes']['thistle_constant'].merge('location' => nil),
      base['attributes']['thistle_constant'].merge('location' => [0, 6, 0, 0]),
      base['attributes']['thistle_constant'].merge('location' => [40, 30, 3, 3]),
      base['attributes']['thistle_constant'].merge('location' => [0, 6, 999, 999]),
      base['attributes']['thistle_constant'].merge('role' => '<img>'),
      base['attributes']['thistle_constant'].merge('rooted' => true),
      base['attributes']['thistle_constant'].merge('syntax' => 'x' * 1025)]
    changes.each do |data|
      link = base.merge('attributes' => { 'thistle_constant' => data })
      reader = reader_with([link])
      def reader.source(*) = raise('Malformed occurrence requested Source')
      html = page(reader)
      assert_includes html, 'Constant site details unavailable'
      refute_match(/#L\d/, html)
    end
    [1, 2].each do |schema|
      reader = reader_with([base], schema: schema)
      def reader.source(*) = raise('Opaque legacy metadata requested Source')
      assert_includes page(reader), 'Constant site details unavailable'
    end
  end

  def test_exact_source_syntax_line_and_identity_must_match_for_outgoing_anchors
    data = occurrence['attributes']['thistle_constant']
    [data.merge('syntax' => 'Elsexx'), data.merge('location' => data['location'].take(2) + [2, 2])].each do |bad|
      html = page(reader_with([occurrence.merge('attributes' => { 'thistle_constant' => bad })]))
      assert_includes html, 'Constant site details unavailable'
      refute_match(/#L\d/, html)
    end
    reader = reader_with([occurrence])
    reader.define_singleton_method(:source) { |id| super(id).merge('generation' => 'wrong') }
    assert_includes page(reader), 'Constant site details unavailable'
  end

  def test_byte_and_newline_web_limits_use_pinned_cli_without_unreachable_site_links
    large = 'Widget' + ' ' * Thistle::Map::View::MAX_SOURCE_BYTES
    reader = reader_with([occurrence(large, offset: 0)], large)
    def reader.source(*) = raise('Oversized source was expanded')
    html = page(reader)
    assert_includes html, 'Source exceeds web display limits'
    assert_includes html, "thistle source #{FACT_ID} --store STORE --generation #{GENERATION}"
    refute_match(/#L\d/, html)
    lines = 'Widget' + "\n" * (Thistle::Map::View::MAX_SOURCE_LINES + 1)
    html = page(reader_with([occurrence(lines, offset: 0)], lines))
    assert_includes html, 'Source exceeds web display limits'
    refute_match(/#L\d/, html)
  end

  def test_adapter_objects_cannot_spoof_bool_null_or_string_types
    dispatched = false
    spoof = Object.new
    spoof.define_singleton_method(:nil?) { dispatched = true; true }
    spoof.define_singleton_method(:equal?) { |_| dispatched = true; true }
    spoof.define_singleton_method(:to_s) { dispatched = true; raise 'Unexpected formatting' }
    %w[rooted lexical_scope syntax].each do |field|
      data = occurrence['attributes']['thistle_constant'].merge(field => spoof)
      html = presenter.render(occurrence.merge('attributes' => { 'thistle_constant' => data }), origin: origin)
      assert_includes html, 'Constant site details unavailable'
    end
    refute dispatched
  end
end
