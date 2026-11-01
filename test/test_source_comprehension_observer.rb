# frozen_string_literal: true

# Pure stdlib/builtin reflection test. Does not load thistle/native or Rails.
require 'minitest/autorun'
require_relative '../lib/thistle/source_comprehension_observer'

module SourceComprehensionUnitFixture
  class Boundary
    def outside_boundary = 'outside'
  end
  class Parent < Boundary
    def inherited = 'parent'
    def label = 'parent label'
  end
  module Included
    private
    def included_label = 'included'
  end
  module Prepended
    def label = super
  end
  class Model < Parent
    include Included
    prepend Prepended
    def label = 'model'
    def own = included_label
    define_method(:native_hash, Object.instance_method(:hash))
    class << self
      def name = raise('application name called')
      def ancestors = raise('application ancestors called')
      def instance_method(*) = raise('application method lookup called')
      def superclass = raise('application superclass called')
      def public_instance_methods(*) = raise('application inventory called')
      def equal?(*) = raise('application identity called')
    end
  end
end

class SourceComprehensionObserverTest < Minitest::Test
  F = SourceComprehensionUnitFixture

  def observer(entries: 100, bytes: 65_536)
    Thistle::SourceComprehensionObserver.new(limits: { max_facts: 2, max_entries: entries }, evidence_budget: bytes)
  end

  def test_observes_prepends_direct_methods_superclass_and_missing_source_without_application_dispatch
    result = observer.call(models: [F::Model], stop_before: F::Boundary)
    model = result.fetch('models').fetch(0)
    assert_equal 'SourceComprehensionUnitFixture::Model', model['name']
    assert_equal 'SourceComprehensionUnitFixture::Parent', model['superclass']
    owners = model.fetch('ancestors')
    assert_equal [F::Prepended, F::Model, F::Included, F::Parent].map { |m| Module.instance_method(:name).bind_call(m) }, owners.map { |row| row['name'] }
    label = model.fetch('effective_methods').find { |row| row['name'] == 'label' }
    assert_equal 0, label['owner_index']
    # The direct row must retain Model's body even with Prepended first in lookup.
    direct = owners[1]['methods'].find { |row| row['name'] == 'label' }
    refute_equal direct['source'], label['source']
    private_row = owners[2]['methods'].find { |row| row['name'] == 'included_label' }
    assert_equal 'private', private_row['visibility']
    assert_nil model['effective_methods'].find { |row| row['name'] == 'native_hash' }['source']
  end

  def test_limits_and_unknown_boundary_refuse_without_partial_success
    assert_raises(Thistle::LimitExceeded) { observer(entries: 1).call(models: [F::Model], stop_before: F::Boundary) }
    assert_raises(Thistle::LimitExceeded) { observer(bytes: 32).call(models: [F::Model], stop_before: F::Boundary) }
    assert_raises(Thistle::InvalidInput) { observer.call(models: [F::Model], stop_before: String) }
    assert_raises(Thistle::InvalidInput) { observer.call(models: Object.new, stop_before: F::Boundary) }
  end

  def test_undef_is_unknown_even_when_a_parent_definition_exists
    child = Class.new(F::Parent) { undef_method :inherited }
    result = observer.call(models: [child], stop_before: F::Boundary)
    row = result['models'][0]['effective_methods'].find { |method| method['name'] == 'inherited' }
    assert_nil row['owner_index']
    assert_nil row['source']
  end

  def test_boundary_external_visibility_entry_is_unknown_without_guessing_a_body
    child = Class.new(F::Boundary) { private :outside_boundary }
    # Builtin-only cohort check: some Rubies resolve ZSUPER to the boundary;
    # Ruby 4.0.9 instead reports a child-owned visibility wrapper. Neither form
    # authorizes guessing a body/owner absent from the direct inventory.
    assert_includes Module.instance_method(:private_instance_methods).bind_call(child, false), :outside_boundary
    descriptor = Module.instance_method(:instance_method).bind_call(child, :outside_boundary)
    resolved = UnboundMethod.instance_method(:owner).bind_call(descriptor)
    assert [child, F::Boundary].any? { |owner| BasicObject.instance_method(:equal?).bind_call(owner, resolved) }
    result = observer.call(models: [child], stop_before: F::Boundary)['models'][0]
    direct = result['ancestors'][0]['methods'].find { |row| row['name'] == 'outside_boundary' }
    assert_equal 'private', direct['visibility']
    effective = result['effective_methods'].find { |row| row['name'] == 'outside_boundary' }
    if BasicObject.instance_method(:equal?).bind_call(resolved, child)
      assert_equal 0, effective['owner_index']
      assert_equal direct['source'], effective['source']
    else
      assert_nil direct['source']
      assert_nil effective['owner_index']
      assert_nil effective['source']
    end
  end

  def test_anonymous_mid_chain_owner_keeps_the_named_suffix_in_the_raw_inventory
    anonymous = Module.new { def anonymous_label = 'anonymous' }
    child = Class.new(F::Parent) { include F::Included; include anonymous }
    result = observer.call(models: [child], stop_before: F::Boundary)['models'][0]
    owners = result['ancestors']
    assert_nil owners[1]['name']
    assert_equal ['SourceComprehensionUnitFixture::Included', 'SourceComprehensionUnitFixture::Parent'], owners.drop(2).map { |row| row['name'] }
    assert_equal 1, result['effective_methods'].find { |row| row['name'] == 'anonymous_label' }['owner_index']
  end

  def test_builtin_descriptors_without_an_inventoried_direct_owner_have_no_source_hint
    child = Class.new(F::Boundary) { def local = 'local' }
    # Real builtin descriptors with finite test inventories, not substituted VM
    # methods: one owner outside the boundary, one absent direct-row witness.
    %i[outside_boundary local].each do |name|
      descriptor = observer.send(:effective_descriptor, child, name, [child], [{}])
      assert_nil descriptor['owner_index']
      assert_nil descriptor['source']
    end
  end
end
