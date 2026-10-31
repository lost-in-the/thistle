# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/model_brief_markdown'

module MarkdownBriefFixture
  GENERATION = 'a' * 64
  MODEL = 'b' * 64
  METHOD = 'c' * 64

  def brief
    identity = { 'id' => MODEL, 'kind' => 'rails_model', 'name' => 'Example::Order', 'evidence' => 'observed', 'path' => nil }
    families = Thistle::ModelBriefMarkdown::FAMILIES.to_h do |name|
      [name, { 'generation' => GENERATION, 'fact_id' => MODEL, 'status' => 'not_searched', 'reason' => 'not_admitted',
        'known_omitted' => nil, 'unsearched' => true, 'items' => [] }]
    end
    families['columns'].merge!('status' => 'observed', 'known_omitted' => 2, 'unsearched' => false,
      'output_truncated' => true, 'items' => [{ 'name' => 'state', 'type' => 'string', 'null' => false }])
    families['associations']['items'] = [{ 'name' => 'items', 'target' => 'Example::Item', 'macro' => 'has_many', 'status' => 'recorded_label_binding_unknown' }]
    families['registry_candidates']['items'] = [identity.merge('kind' => 'rails_save_callbacks')]
    families['callbacks']['items'] = [{ 'callback_id' => "#{MODEL}:0", 'registry_id' => MODEL,
      'filter' => { 'kind' => 'method', 'name' => 'deliver', 'owner' => 'Example::Order', 'source' => { 'path' => '/private/secret' } },
      'if' => ['CONDITION_SECRET'], 'explanation' => { 'status' => 'supported_potential', 'binding' => 'descriptor_matched_captured_declaration',
        'method' => { 'id' => METHOD, 'name' => 'Example::Order#deliver', 'path' => 'app/models/order.rb', 'span' => { 'start_byte' => 3, 'end_byte' => 25 } },
        'source' => { 'path' => 'app/models/order.rb', 'sha256' => 'd' * 64 }, 'known_effects_omitted' => 1,
        'effects' => [{ 'receiver' => 'DeliveryJob', 'selector' => 'perform_later', 'source_excerpt' => 'SOURCE_SECRET',
          'provenance' => 'captured_source_potential', 'call_span' => { 'start_byte' => 5, 'end_byte' => 20 } }] } }]
    families['outgoing']['items'] = [{ 'origin' => identity, 'link' => { 'relation' => 'association_target_label', 'target' => 'Example::Item', 'attributes' => { 'secret' => 'LINK_SECRET' } },
      'link_ordinal' => 3, 'candidate_matches' => 1, 'candidate_search_complete' => true, 'candidates' => [identity.merge('id' => METHOD)] }]
    { 'version' => 1, 'generation' => GENERATION, 'root' => identity, 'model' => { 'name' => 'Example::Order', 'coherence' => 'unknown' },
      'coverage' => { 'capture_partial_or_unknown' => true, 'families_not_projected' => 1,
        'families' => [{ 'family' => 'models', 'status' => 'partial' }] },
      'limits' => { 'items_per_family' => 8, 'wire_bytes_including_newline' => 32768 },
      'uncertainty' => 'Labels do not establish binding or execution.', 'families' => families }
  end

  def manifest
    { 'schema_version' => 3, 'producer' => { 'name' => 'thistle', 'prism_version' => '1.9.0', 'ruby_syntax_version' => '4.1', 'parser_policy' => 'prism-default-guarded', 'secret' => 'PRODUCER_SECRET' },
      'files' => Object.new, 'root' => '/private/store' }
  end

  def render(value = brief, **options)
    Thistle::ModelBriefMarkdown.render(value, manifest: manifest, generation: GENERATION, model_id: MODEL, **options)
  end
end

class ThistleModelBriefMarkdownTest < Minitest::Test
  include MarkdownBriefFixture

  def test_readable_pinned_evidence_with_scoped_partiality_and_no_extra_expansion
    report = render
    %w[columns associations callbacks outgoing incoming].each { |name| assert_includes report, "## #{name}" }
    assert_includes report, 'prism version: ` 1.9.0 `'
    assert_includes report, 'schema version: ` 3 `'
    assert_includes report, 'known omitted: ` 2 `'
    assert_includes report, 'known omitted: unknown'
    assert_includes report, 'output truncated: ` true `'
    assert_includes report, 'capture partial or unknown: ` true `'
    assert_includes report, "thistle source #{METHOD} --store STORE --generation #{GENERATION}"
    assert_includes report, 'app/models/order.rb'
    assert_includes report, 'start byte: ` 5 `'
    assert_includes report, 'captured_source_potential'
    refute_match(/SECRET|\/private\//, report)
    assert_operator report.bytesize, :<=, 32768
  end

  def test_hostile_markdown_stays_in_one_literal_span_and_controls_cannot_break_lines
    value = brief
    hostile = "` `` ``` <script>alert(1)</script> [click](evil) ![x](y) &amp;\n# heading\r\t\u202e雪"
    value['root']['name'] = hostile
    report = render(value)
    assert_includes report, "```` ` `` ``` <script>alert(1)</script> [click](evil) ![x](y) &amp;\\u000a# heading\\u000d\\u0009\\u202e雪 ````"
    refute_includes report, "\n# heading"
  end

  def test_urls_absolute_paths_and_home_paths_are_withheld_even_as_labels
    ['https://example.test/?token=SECRET', 'https:/example.test/?token=SECRET', 'javascript:alert(1)', '/home/user/store', '~/.store', 'C:\\Users\\owner', 'prefix /home/user/store'].each do |text|
      value = brief
      value['root']['name'] = text
      report = render(value)
      refute_includes report, text
      assert_includes report, '[withheld path or URL]'
    end
  end

  def test_malformed_utf8_and_shape_refuse_without_repairing_evidence
    value = brief
    value['root']['name'] = "bad\xff".b.force_encoding('UTF-8')
    assert_raises(Thistle::InvalidSnapshot) { render(value) }
    value = brief
    value['model']['name'] = { 'attributes' => 'secret' }
    assert_raises(Thistle::InvalidSnapshot) { render(value) }
    value = brief
    value['families']['columns']['generation'] = 'f' * 64
    assert_raises(Thistle::InvalidSnapshot) { render(value) }
    assert_raises(Thistle::InvalidSnapshot) { render(brief.merge('version' => 2)) }
  end

  def test_exact_encoded_budget_includes_escape_expansion_and_last_newline
    value = brief
    value['root']['name'] = "\x01" * 500
    report = render(value, max_bytes: 65536)
    assert report.end_with?("\n")
    assert_equal report.bytesize, render(value, max_bytes: report.bytesize).bytesize
    assert_raises(Thistle::LimitExceeded) { render(value, max_bytes: report.bytesize - 1) }
    assert_raises(Thistle::LimitExceeded) { render(value, max_bytes: 1) }
    [0, -1, 65537, '32768'].each { |limit| assert_raises(Thistle::InvalidInput) { render(max_bytes: limit) } }
  end

  def test_long_literal_labels_and_backtick_fences_are_bounded_without_shortening_rows
    value = brief
    value['root']['name'] = 'a' * 12000
    assert_includes render(value, max_bytes: 65536), '` ' + ('a' * 12000) + ' `'
    value['root']['name'] = '`' * 12000
    assert_raises(Thistle::LimitExceeded) { render(value, max_bytes: 32768) }
  end

  def test_deterministic_order_ignores_hash_insertion_order_work_and_unrelated_manifest_data
    value = brief
    first = render(value)
    value['cost'] = { 'built_this_request' => true }
    value['model'] = value['model'].to_a.reverse.to_h
    value['families'] = value['families'].to_a.reverse.to_h
    assert_equal first, render(value)
  end
end
