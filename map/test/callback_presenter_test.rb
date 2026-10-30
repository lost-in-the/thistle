# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/callback_presenter'

class ThistleCallbackPresenterTest < Minitest::Test
  GENERATION = 'a' * 64
  class SavedReader
    attr_reader :generation, :manifest, :reads
    def initialize(generation = GENERATION, content: "# <script>fixture</script>\n")
      @generation, @content, @reads = generation, content, []
      @manifest = { 'files' => [{ 'path' => 'records.rb', 'bytes' => @content.bytesize, 'sha256' => Digest::SHA256.hexdigest(@content) }] }
    end
    def source_file(path)
      @reads << path
      { 'generation' => generation, 'file' => manifest['files'][0], 'content' => @content }
    end
  end

  def fact
    { 'kind' => 'rails_save_callbacks', 'attributes' => { 'callbacks' => {
      'version' => 1, 'name' => '<script>Child</script>', 'superclass' => 'Parent', 'active_record_version' => '8.1.4',
      'save' => { 'status' => 'observed', 'entries' => [{ 'position' => 0, 'kind' => 'around', 'inherited' => true,
        'filter' => { 'kind' => 'method', 'name' => '<img onerror=evil>', 'owner' => 'Child', 'source' => { 'path' => 'records.rb', 'line' => 1 } },
        'if' => [{ 'kind' => 'opaque' }], 'unless' => nil }] }
    } } }
  end

  def presenter(reader = nil)
    Thistle::Map::CallbackPresenter.new(generation: GENERATION, mount: '/map', reader: reader)
  end

  def test_registered_limits_owners_conditions_and_pinned_source_link_are_useful_without_javascript
    reader = SavedReader.new
    html = presenter(reader).render(fact)
    assert_includes html, 'not execution chronology'
    assert_includes html, 'effective owner: Child'
    assert_includes html, 'Shared registered entry with superclass Parent'
    assert_includes html, 'Opaque reference; not evaluated'
    assert_includes html, 'unless: Unavailable; not evaluated'
    assert_includes html, "generation=#{GENERATION}"
    assert_includes html, "file=#{Digest::SHA256.hexdigest('records.rb')}#L1"
    assert_includes html, 'coherence unknown'
    assert_includes html, '&lt;img onerror=evil&gt;'
    refute_includes html, '<script>'
    refute_includes html, '<img '
    assert_equal ['records.rb'], reader.reads
  end

  def test_mismatch_absent_or_invalid_source_never_becomes_a_link
    [nil, SavedReader.new('b' * 64)].each do |reader|
      refute_includes presenter(reader).render(fact), '<a '
    end
    data = fact
    data['attributes']['callbacks']['save']['entries'][0]['filter']['source']['line'] = 999
    refute_includes presenter(SavedReader.new).render(data), '<a '
  end

  def test_proc_filter_and_condition_source_hints_render_with_mutable_escaped_text
    data = fact
    entry = data['attributes']['callbacks']['save']['entries'][0]
    reference = { 'kind' => 'proc', 'source' => { 'path' => 'records.rb', 'line' => 1 } }
    entry['filter'] = reference
    entry['if'] = [reference]
    html = presenter(SavedReader.new).render(data)
    assert_equal 2, html.scan('Proc; body opaque and not evaluated').length
    assert_equal 2, html.scan('Captured source (coherence unknown)').length
    assert_includes html, "file=#{Digest::SHA256.hexdigest('records.rb')}#L1"
  end

  def test_source_links_match_rendered_lines_and_destination_display_limit
    [
      ["a\n", 1, true], ["a\n", 2, false], ["a", 1, true],
      ["\n" * 10_000, 10_000, true]
    ].each do |content, line, linked|
      data = fact
      data['attributes']['callbacks']['save']['entries'][0]['filter']['source']['line'] = line
      html = presenter(SavedReader.new(content: content)).render(data)
      assert_equal linked, html.include?('Captured source (coherence unknown)'),
        "bytes=#{content.bytesize}, line=#{line}"
      assert_includes html, "location hint records.rb:#{line}"
      assert_includes html, 'outside display budget' unless linked
    end
  end

  def test_source_link_is_absent_when_the_destination_line_budget_refuses_the_file
    html = presenter(SavedReader.new(content: "\n" * 10_001)).render(fact)
    refute_includes html, 'Captured source (coherence unknown)'
    assert_includes html, 'location hint records.rb:1'
    assert_includes html, 'outside display budget'
  end

  def test_empty_unavailable_partial_unknown_and_display_budget_do_not_claim_complete_evidence
    data = fact
    data['attributes']['callbacks']['save'] = { 'status' => 'unavailable', 'entries' => [] }
    assert_includes presenter.render(data), 'not evidence of an empty chain'
    data['attributes']['callbacks']['save']['status'] = 'observed'
    assert_includes presenter.render(data), 'No registered save callbacks observed'
    data['attributes']['callbacks']['save']['status'] = 'partial'
    assert_includes presenter.render(data), 'Partial chain metadata'
    data['attributes']['callbacks']['version'] = 2
    assert_includes presenter.render(data), 'unknown format'
    data['attributes']['callbacks']['version'] = 1
    data['attributes']['callbacks']['name'] = 'x' * 262_144
    assert_includes presenter.render(data), 'display budget'
  end

  def test_source_expansion_is_cached_and_row_budget_is_explicit
    data = fact
    entry = data['attributes']['callbacks']['save']['entries'][0]
    data['attributes']['callbacks']['save']['entries'] = Array.new(201) { entry }
    reader = SavedReader.new
    html = presenter(reader).render(data)
    assert_includes html, 'Showing 200 of 201 entries'
    assert_equal ['records.rb'], reader.reads
  end
end

class ThistleCallbackEffectsPresenterTest < Minitest::Test
  GENERATION = 'a' * 64
  REGISTRY = 'b' * 64
  class EffectsReader
    attr_reader :generation, :calls
    def initialize(response: nil, error: nil)
      @generation, @response, @error, @calls = GENERATION, response, error, []
    end
    def callback_effects(id, limit:)
      @calls << [id, limit]
      raise @error if @error
      @response
    end
  end

  def fact
    { 'id' => REGISTRY, 'kind' => 'rails_save_callbacks', 'attributes' => { 'callbacks' => {
      'version' => 1, 'name' => 'Child', 'active_record_version' => '8.1.4',
      'save' => { 'status' => 'observed', 'entries' => [] }
    } } }
  end
  def render(reader)
    Thistle::Map::CallbackPresenter.new(generation: GENERATION, mount: '/map', reader: reader).render(fact)
  end
  def response
    { 'generation' => GENERATION, 'registry_id' => REGISTRY, 'model' => '<script>Child</script>',
      'registry_status' => 'partial', 'semantics' => 'Potential only; conditions, dispatch and execution unknown.',
      'callbacks' => [{ 'position' => 0, 'kind' => 'before', 'explanation' => {
        'binding' => 'descriptor_matched_captured_declaration', 'status' => 'supported_potential', 'reason' => 'recorded call',
        'method' => { 'name' => 'Child#deliver', 'span' => { 'start_line' => 1 } },
        'source' => { 'path' => 'records.rb', 'sha256' => 'c' * 64, 'lines' => 2 }, 'known_effects_omitted' => 0,
        'effects' => [{ 'operation' => 'DeliveryJob.perform_later', 'source_excerpt' => 'DeliveryJob.perform_later("<img src=x>")',
          'call_span' => { 'start_byte' => 5, 'end_byte' => 50, 'start_line' => 2 } }] } }],
      'coverage' => { 'capture_partial_or_unknown' => true, 'declaration_scan_complete' => false,
        'truncated' => true, 'rows_not_searched' => 2, 'rows_metadata_omitted' => 0, 'rows_output_omitted' => 1 } }
  end

  def test_explanation_invokes_exact_id_and_renders_escaped_pinned_support_and_limits
    reader = EffectsReader.new(response: response)
    html = render(reader)
    assert_equal [[REGISTRY, 200]], reader.calls
    assert_includes html, 'Potential enqueue-style request'
    assert_includes html, 'DeliveryJob.perform_later'
    assert_includes html, '&lt;script&gt;Child&lt;/script&gt;'
    assert_includes html, '&lt;img src=x&gt;'
    refute_includes html, '<img '
    assert_includes html, 'Descriptor-matched captured declaration'
    assert_includes html, "generation=#{GENERATION}"
    assert_includes html, "file=#{Digest::SHA256.hexdigest('records.rb')}#L2"
    assert_includes html, '2 rows not searched'
    assert_includes html, '1 output rows omitted'
    assert_includes html, 'Possible effects remain unknown'
  end

  def test_complete_candidate_lookup_preserves_capture_partiality_and_unsearched_source
    result = response
    result.fetch('coverage').merge!('truncated' => false, 'declaration_scan_complete' => true,
      'method_directory' => { 'status' => 'complete' }, 'source_rows_not_searched' => 1)
    html = render(EffectsReader.new(response: result))
    assert_includes html, 'Captured method candidate lookup completed'
    assert_includes html, 'original capture coverage is separate'
    assert_includes html, 'Capture is partial or unknown'
    assert_includes html, 'Source evidence not searched for 1 returned callbacks'
    refute_includes html, 'Explanation incomplete:'
    assert_includes html, "generation=#{GENERATION}"
    assert_includes html, 'runtime/source coherence unknown'
  end

  def test_only_missing_api_and_resource_refusals_become_optional_unavailability
    assert_includes render(nil), 'Reader callback_effects API unavailable'
    assert_includes render(EffectsReader.new(error: Thistle::LimitExceeded.new('full'))), 'resource limit'
    assert_includes render(EffectsReader.new(error: Thistle::InvalidInput.new('Unknown native operation'))), 'native callback_effects API unavailable'
    [Thistle::InvalidInput.new('bad ID'), Thistle::InvalidSnapshot.new('corrupt'), Thistle::NotFound.new('missing registry'),
     NoMethodError.new('internal implementation bug')].each do |error|
      assert_raises(error.class) { render(EffectsReader.new(error: error)) }
    end
    bad = response; bad['generation'] = 'd' * 64
    assert_raises(Thistle::InvalidSnapshot) { render(EffectsReader.new(response: bad)) }
    bad = response; bad['registry_id'] = 'd' * 64
    assert_raises(Thistle::InvalidSnapshot) { render(EffectsReader.new(response: bad)) }
  end

  def test_hint_source_corruption_is_not_swallowed_as_unavailable
    data = ThistleCallbackPresenterTest.new('unused').fact
    reader = ThistleCallbackPresenterTest::SavedReader.new
    def reader.source_file(*) = raise(Thistle::InvalidSnapshot, 'corrupt source')
    assert_raises(Thistle::InvalidSnapshot) do
      Thistle::Map::CallbackPresenter.new(generation: GENERATION, reader: reader).render(data)
    end
  end
end
