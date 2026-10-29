# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/errors'
require_relative '../lib/thistle/model_observer'

class ThistleModelObserverTest < Minitest::Test
  class SchemaPool
    attr_reader :attempts
    def initialize(error: nil)
      @error, @attempts = error, []
    end
    def schema_cache = self
    def columns_hash(table)
      @attempts << table
      raise @error, 'connection detail must remain private' if @error
      raise ActiveRecord::StatementInvalid, 'missing table detail' if table == 'missing'
      {}
    end
  end

  def model_for(pool, table:, lazy_key: false)
    reflection = Struct.new(:name, :macro, :options, :scope, :class_name)
      .new(:items, :has_many, {}, nil, 'Item')
    Class.new.tap do |model|
      model.define_singleton_method(:base_class) { self }
      model.define_singleton_method(:abstract_class?) { false }
      model.define_singleton_method(:inheritance_column) { 'type' }
      model.define_singleton_method(:connection_pool) { pool }
      model.define_singleton_method(:table_name) { table }
      model.define_singleton_method(:primary_key) { pool.columns_hash(table) if lazy_key; 'id' }
      model.define_singleton_method(:reflect_on_all_associations) { [reflection] }
    end
  end

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

  def test_connection_failures_are_capture_local_per_pool_including_lazy_primary_keys
    require 'active_record'
    [false, true].each do |lazy_key|
      failed = SchemaPool.new(error: ActiveRecord::ConnectionTimeoutError)
      healthy = SchemaPool.new
      capture_observer = observer
      unavailable = %w[first second].map do |table|
        capture_observer.send(:observe, model_for(failed, table: table, lazy_key: lazy_key))
      end
      assert_equal ['first'], failed.attempts
      unavailable.each do |data|
        assert_equal 'unavailable', data.dig('columns', 'status')
        assert_equal 'observed', data.dig('associations', 'status')
        assert_equal 'items', data.dig('associations', 'entries', 0, 'name')
      end
      missing = capture_observer.send(:observe, model_for(healthy, table: 'missing'))
      good = capture_observer.send(:observe, model_for(healthy, table: 'good'))
      assert_equal 'unavailable', missing.dig('columns', 'status')
      assert_equal 'observed', good.dig('columns', 'status')
      assert_equal %w[missing good], healthy.attempts
      refute_includes JSON.generate(unavailable + [missing, good]), 'detail'
      # A new capture gets one fresh attempt, not a process-wide poisoned pool.
      observer.send(:observe, model_for(failed, table: 'new_capture', lazy_key: lazy_key))
      assert_equal %w[first new_capture], failed.attempts
    end
  end
end
