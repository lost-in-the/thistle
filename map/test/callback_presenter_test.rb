# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/callback_presenter'

class ThistleCallbackPresenterTest < Minitest::Test
  GENERATION = 'a' * 64
  class SavedReader
    attr_reader :generation, :manifest, :reads
    def initialize(generation = GENERATION)
      @generation, @content, @reads = generation, "# <script>fixture</script>\n", []
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
