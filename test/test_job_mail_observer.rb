# frozen_string_literal: true

# Source-only stdlib doubles: no Rails boot or Thistle native library loaded.
require 'minitest/autorun'
require_relative '../lib/thistle/errors'
require_relative '../lib/thistle/job_mail_observer'

class JobMailObserverTest < Minitest::Test
  class Parent
    def self.rescue_handlers = raise('application getter dispatched')
  end
  class Child < Parent
    def record_failure(*) = raise('handler dispatched')
    def self.__class_attr_rescue_handlers = raise('private getter dispatched')
  end
  class RawDouble < Thistle::JobMailObserver
    def initialize(registries:, **options)
      @registries = registries
      super(**options)
    end
    private
    def registry(klass, _attribute) = @registries[klass]
  end

  def options
    { app: Object.new, root: '/public/fixture', jobs: [Child], mailers: [], framework_version: '8.1.4',
      limits: { max_entries: 30, max_facts: 10 }, evidence_budget: 32_000 }
  end

  def test_order_identity_inheritance_and_opaque_handlers_without_dispatch
    inherited = ['Timeout', proc { raise 'proc dispatched' }]
    opaque = Object.new
    def opaque.to_s = raise('formatted opaque')
    def opaque.inspect = raise('inspected opaque')
    def opaque.to_json(*) = raise('serialized opaque')
    rows = [inherited, ['Missing', :record_failure], ['Unknown', opaque]]
    result = RawDouble.new(**options, registries: { Parent => [inherited], Child => rows }).call
    entries = result.fetch('classes').first.fetch('rescue_handlers').fetch('entries')
    assert_equal %w[Timeout Missing Unknown], entries.map { |r| r['exception'] }
    assert_equal [true, false, false], entries.map { |r| r['shared_with_superclass'] }
    assert_equal %w[proc method opaque], entries.map { |r| r.dig('handler', 'kind') }
    assert_equal 'JobMailObserverTest::Child', entries[1].dig('handler', 'owner')
    assert_equal 'explicit_loaded_app', result['boundary']
  end

  def test_real_guard_refuses_application_private_storage_without_calling_it
    result = Thistle::JobMailObserver.new(**options).call
    assert_equal({ 'status' => 'unavailable', 'entries' => [] }, result.fetch('classes').first['rescue_handlers'])
  end

  def test_public_override_is_unavailable_on_unverified_71_path_without_dispatch
    result = Thistle::JobMailObserver.new(**options.merge(framework_version: '7.1.6')).call
    assert_equal({ 'status' => 'unavailable', 'entries' => [] }, result.fetch('classes').first['rescue_handlers'])
  end

  def test_no_boundary_unknown_framework_and_limits_are_not_empty_success
    assert_equal 'unavailable', Thistle::JobMailObserver.new(**options.merge(app: nil)).call['status']
    assert_equal 'unavailable', Thistle::JobMailObserver.new(**options.merge(framework_version: 'future')).call['status']
    assert_raises(Thistle::LimitExceeded) do
      RawDouble.new(**options.merge(limits: {max_entries: 1,max_facts: 10}), registries: { Child => [['X',:record_failure]] }).call
    end
  end
end
