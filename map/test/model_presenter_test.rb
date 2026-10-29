# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require_relative '../lib/thistle/map/model_presenter'

class ModelPresenterTest < Minitest::Test
  def fact
    model = JSON.parse(File.read(File.join(__dir__, '../../engine/tests/fixtures/models.json'))).fetch('models').first
    model.merge!('version' => 1, 'active_record_version' => '8.1.4')
    { 'kind' => 'rails_model', 'attributes' => { 'model' => model } }
  end

  def test_separate_associations_and_default_values_are_escaped_and_uncertainty_visible
    input = fact
    input['attributes']['model']['columns']['entries'][0]['default']['value'] = '<script>bad()</script>'
    html = Thistle::Map::ModelPresenter.render(input)
    assert_includes html, 'items'
    assert_includes html, 'payments'
    assert_includes html, 'Allows null'
    assert_includes html, 'STI inheritance column'
    assert_includes html, '&lt;script&gt;'
    refute_includes html, '<script>'
    assert_includes html, 'Source/runtime coherence is unknown'
    assert_includes html, 'source unavailable'
  end

  def test_unavailable_and_display_truncation_are_explicit
    input = fact
    input['attributes']['model']['columns'] = { 'status' => 'unavailable', 'entries' => [] }
    assert_includes Thistle::Map::ModelPresenter.render(input), 'not evidence of an empty family'
    input = fact
    entries = input['attributes']['model']['columns']['entries']
    entries.replace(Array.new(201) { entries.first })
    assert_includes Thistle::Map::ModelPresenter.render(input), 'Showing 200 of 201'
    input['attributes']['model']['version'] = 99
    assert_includes Thistle::Map::ModelPresenter.render(input), 'unknown format'
  end
end
