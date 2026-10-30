# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/thistle/errors'
require_relative '../lib/thistle/callback_observer'

# VM/layout regression only. No Rails version is changed or simulated as support.
class ThistleCallbackReaderGuardTest < Minitest::Test
  def value_reader(value)
    Class.new.tap do |klass|
      klass.singleton_class.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def __callbacks=(value)
          define_singleton_method(:__callbacks) { value }
        end
      RUBY
      klass.public_send(:__callbacks=, value)
    end
  end

  def observer
    Class.new(Thistle::CallbackObserver) { private; def rails71? = true }
      .new(root: '.', limits: { max_facts: 10, max_entries: 10 }, evidence_budget: 1000)
  end

  def test_separately_compiled_pure_value_readers_are_accepted_without_identity_equality
    first, second = value_reader({ save: [] }), value_reader({ save: [] })
    refute_same RubyVM::InstructionSequence.of(first.method(:__callbacks)),
      RubyVM::InstructionSequence.of(second.method(:__callbacks))
    [first, second].each do |model|
      assert_same model.__callbacks, observer.send(:stored_chains, model)
    end
  end

  def test_application_accessor_is_refused_without_dispatch
    model = value_reader({})
    calls = []
    model.define_singleton_method(:__callbacks) { calls << :override; {} }
    assert_nil observer.send(:stored_chains, model)
    assert_empty calls
    refute observer.send(:captured_value_reader?, nil)
  end
end
