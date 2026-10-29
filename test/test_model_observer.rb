# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/errors'
require_relative '../lib/thistle/model_observer'

class ThistleModelObserverTest < Minitest::Test
  def observer
    Thistle::ModelObserver.new(limits: { max_facts: 100, max_entries: 100 }, evidence_budget: 100_000)
  end

  def test_opaque_values_and_singleton_overrides_are_never_executed_or_formatted
    hostile = Object.new
    def hostile.inspect = raise('inspected')
    def hostile.to_s = raise('stringified')
    def hostile.to_json(*) = raise('serialized')
    def hostile.instance_of?(*) = raise('type dispatch')
    def hostile.nil? = raise('nil dispatch')
    [hostile, -> { raise 'default executed' }, ['not recursively traversed'], { nested: hostile }].each do |value|
      assert_equal({ 'kind' => 'opaque' }, observer.send(:scalar, value))
    end
    text = +'<script>secret</script>' # Mutable exact String for singleton dispatch canaries.
    def text.to_json(*) = raise('custom JSON executed')
    def text.encode(*) = raise('custom encoding executed')
    assert_equal({ 'kind' => 'literal', 'value' => '<script>secret</script>' }, observer.send(:scalar, text))
    assert_equal({ 'kind' => 'literal', 'value' => '' }, observer.send(:scalar, ''))
    assert_equal({ 'kind' => 'symbol', 'value' => 'destroy' }, observer.send(:scalar, :destroy))
    assert_equal({ 'kind' => 'opaque' }, observer.send(:scalar, 2**80))
    assert_equal({ 'kind' => 'opaque' }, observer.send(:scalar, Float::INFINITY))
  end

  def test_through_targets_do_not_resolve_and_opaque_options_are_bounded
    reflection = Struct.new(:name, :macro, :options, :scope).new(:products, :has_many, { through: :items, dependent: -> { raise 'predicate executed' } }, -> { raise 'scope executed' })
    def reflection.class_name = raise('target resolution attempted')
    result = observer.send(:observe_association, reflection)
    assert_equal 'products', result['name']
    assert_equal 'items', result['through']
    assert_nil result['target']
    assert_equal 'opaque', result['scope']
    assert_equal({ 'kind' => 'opaque' }, result['options']['dependent'])
    tiny = Thistle::ModelObserver.new(limits: { max_facts: 1, max_entries: 0 }, evidence_budget: 1000)
    assert_raises(Thistle::LimitExceeded) { tiny.send(:observe_association, reflection) }
  end
end
