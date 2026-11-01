# frozen_string_literal: true

# Pure registry doubles; actual Rails layout remains an installed gate.
if $PROGRAM_NAME == __FILE__
require 'minitest/autorun'
require 'set'
require_relative '../lib/thistle/errors'
require_relative '../lib/thistle/controller_filters_observer'

module ActiveSupport
  module Callbacks
    class Callback
      def initialize(kind, filter, yes = [], no = [])
        @kind, @filter, @if, @unless = kind, filter, yes, no
      end
    end unless const_defined?(:Callback, false)
    class CallbackChain
      def initialize(rows) = @chain = rows
    end unless const_defined?(:CallbackChain, false)
  end
end
module AbstractController
  module Callbacks
    class ActionFilter
      def initialize(mode, names) = (@conditional_key, @actions = mode, names.to_set)
    end unless const_defined?(:ActionFilter, false)
  end
end

class ControllerFiltersObserverTest < Minitest::Test
  class Parent
    def authenticate = raise('filter ran')
  end
  class Child < Parent
    def self.__class_attr___callbacks = raise('application storage getter ran')
    def self._process_action_callbacks = raise('application registry getter ran')
    def create = raise('action ran')
  end
  class Raw < Thistle::ControllerFiltersObserver
    def initialize(registries:, **options)
      @registries = registries
      super(**options)
    end
    private
    def stored_chains(controller) = @registries[controller]
  end

  def options
    {app: Object.new, root: '/fixture', controllers: [Child], framework_version: '8.1.4',
      limits: {max_entries: 40, max_facts: 10}, evidence_budget: 32768}
  end

  def test_inherited_ownership_action_conditions_and_opaque_forward_traversal
    shared = ActiveSupport::Callbacks::Callback.new(:before, :authenticate)
    action = AbstractController::Callbacks::ActionFilter.new(:only, ['create'])
    opaque = Object.new
    def opaque.to_json(*) = raise('opaque serialization')
    def opaque.call(*) = raise('condition ran')
    rows = [shared, ActiveSupport::Callbacks::Callback.new(:before, :create, [action, opaque]),
      Object.new, ActiveSupport::Callbacks::Callback.new(:after, proc { raise 'filter proc ran' })]
    registry = {Parent=>{process_action: ActiveSupport::Callbacks::CallbackChain.new([shared])},
      Child=>{process_action: ActiveSupport::Callbacks::CallbackChain.new(rows)}}
    data = Raw.new(**options, registries: registry).call.fetch('controllers').first
    assert_equal 'observed', data['status']
    assert_equal [true,false,nil,false], data['entries'].map { |row| row['inherited'] }
    assert_equal 'ControllerFiltersObserverTest::Parent', data['entries'][0].dig('filter','owner')
    assert_equal [{'kind'=>'actions','mode'=>'only','actions'=>['create']},{'kind'=>'opaque'}], data['entries'][1]['if']
    assert_equal 'unavailable', data['entries'][2].dig('filter','kind')
    assert_equal 'proc', data['entries'][3].dig('filter','kind')
  end

  # No class_attribute exists in this pure fixture: this exercises unavailable
  # storage via NameError, not the real framework ISeq mismatch guard.
  def test_missing_framework_storage_is_unavailable_without_dispatch
    row = Thistle::ControllerFiltersObserver.new(**options).call.fetch('controllers').first
    assert_equal 'unavailable', row['status']
    assert_empty row['entries']
    assert_equal 'unavailable', Thistle::ControllerFiltersObserver.new(**options.merge(framework_version: 'future')).call['status']
  end

  def test_limits_and_unknown_rows_do_not_hide_later_entries
    registry = {Child=>{process_action: ActiveSupport::Callbacks::CallbackChain.new([Object.new, Object.new])}}
    assert_raises(Thistle::LimitExceeded) do
      Raw.new(**options.merge(limits: {max_entries: 1,max_facts: 10}), registries: registry).call
    end
    assert_raises(Thistle::LimitExceeded) { Raw.new(**options.merge(evidence_budget: 32), registries: registry).call }
    assert_equal 2, Raw.new(**options, registries: registry).call.fetch('controllers').first.fetch('entries').length
  end
end
end
