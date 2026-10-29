# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/errors'
require_relative '../lib/thistle/callback_observer'
require_relative 'fixtures/callbacks/booted_app'

class ThistleCallbackObserverTest < Minitest::Test
  def setup
    CallbackFixture.boot
  end

  def observer(**limits)
    Thistle::CallbackObserver.new(root: File.join(__dir__, 'fixtures/callbacks'),
      limits: { max_facts: 100, max_entries: 1000 }.merge(limits), evidence_budget: 200_000)
  end

  def child(data)
    data.fetch('models').find { |model| model['name'] == 'CallbackFixture::Child' }.fetch('save')
  end

  def test_real_registered_chain_preserves_skip_inheritance_override_and_opaque_references
    data = observer.call
    assert_equal 'observed', data['status']
    chain = child(data)
    assert_equal 'observed', chain['status']
    entries = chain['entries']
    names = entries.filter_map { |entry| entry.dig('filter', 'name') }
    assert_equal %w[first finished parent_stamp wrap], names
    refute_includes names, 'removed'
    inherited = entries.find { |entry| entry.dig('filter', 'name') == 'parent_stamp' }
    assert_equal true, inherited['inherited']
    assert_equal 'CallbackFixture::Child', inherited.dig('filter', 'owner')
    assert_equal 'allowed?', inherited.dig('if', 0, 'name')
    assert_equal 'CallbackFixture::Parent', inherited.dig('if', 0, 'owner')
    around = entries.find { |entry| entry['kind'] == 'around' }
    assert_equal 'proc', around.dig('unless', 0, 'kind')
    assert around.dig('unless', 0, 'source', 'line').positive?
    assert_equal 'opaque', entries.last.dig('filter', 'kind')
    proc_entry = entries.find { |entry| entry.dig('filter', 'kind') == 'proc' }
    assert_equal %w[proc opaque], proc_entry['if'].map { |condition| condition['kind'] }
    refute_includes JSON.generate(data), '0x'
    skipped = data['models'].find { |model| model['name'] == 'CallbackFixture::ConditionalSkip' }
      .dig('save', 'entries').find { |entry| entry.dig('filter', 'name') == 'parent_stamp' }
    assert_equal 'skip_stamp?', skipped.dig('unless', 0, 'name')
    empty = data['models'].find { |model| model['name'] == 'CallbackFixture::Empty' }
    assert_equal({ 'status' => 'observed', 'entries' => [] }, empty['save'])
  end

  def test_application_callback_accessors_are_never_dispatched
    singleton = CallbackFixture::Child.singleton_class
    calls = []
    %i[_save_callbacks __callbacks].each do |name|
      singleton.define_method(name) { calls << name; raise 'application accessor executed' }
    end
    data = child(observer.call)
    assert_equal 'observed', data['status']
    assert data['entries'].any? { |entry| entry.dig('filter', 'name') == 'parent_stamp' }
    assert_empty calls
  ensure
    %i[_save_callbacks __callbacks].each { |name| singleton.remove_method(name) } if singleton
  end

  def test_overridden_private_storage_is_unavailable_without_executing_it
    singleton = CallbackFixture::Child.singleton_class
    original = singleton.instance_method(:__class_attr___callbacks)
    calls = []
    singleton.define_method(:__class_attr___callbacks) { calls << :storage; raise 'application storage executed' }
    singleton.send(:private, :__class_attr___callbacks)
    assert_equal({ 'status' => 'unavailable', 'entries' => [] }, child(observer.call))
    assert_empty calls
  ensure
    if singleton && original
      singleton.define_method(:__class_attr___callbacks, original)
      singleton.send(:private, :__class_attr___callbacks)
    end
  end

  def test_unknown_chain_entry_and_unreadable_chain_are_not_empty_success
    chain = CallbackFixture::Child._save_callbacks
    original = chain.instance_variable_get(:@chain)
    chain.instance_variable_set(:@chain, [*original, Object.new])
    data = child(observer.call)
    assert_equal 'partial', data['status']
    assert_equal({ 'kind' => 'unavailable' }, data['entries'].last['filter'])
    assert_nil data['entries'].last['if']
    chain.instance_variable_set(:@chain, nil)
    assert_equal({ 'status' => 'unavailable', 'entries' => [] }, child(observer.call))
  ensure
    chain.instance_variable_set(:@chain, original) if chain
  end

  def test_missing_method_and_budget_refusals_are_bounded
    entry = observer.send(:reference, CallbackFixture::Child, :missing_callback)
    assert_equal 'method', entry['kind']
    assert_nil entry['owner']
    assert_nil entry['source']
    assert_raises(Thistle::LimitExceeded) { observer(max_entries: 1).call }
    assert_raises(Thistle::LimitExceeded) { observer(max_facts: 1).call }
  end
end
