# frozen_string_literal: true

require_relative 'model_observer'

module Thistle
  # Raw registries from an explicit loaded-app inventory. No descendant lookup,
  # constant resolution, application-controlled getter, handler or action dispatch.
  class JobMailObserver < ModelObserver
    def initialize(app:, root:, jobs:, mailers:, framework_version:, **options)
      super(**options)
      @app, @jobs, @mailers = app, jobs, mailers
      @version = label(framework_version)
      @root = label(root)
    end

    def call
      @entries = @metadata_bytes = 0
      result = { 'version' => 1, 'framework_version' => @version, 'root' => @root,
        'boundary' => 'explicit_loaded_app', 'status' => 'unavailable', 'classes' => [] }
      return result unless @app && SUPPORTED.include?(@version)
      raise TypeError, 'Explicit class arrays required' unless exact?(@jobs, Array) && exact?(@mailers, Array)
      jobs = Array.instance_method(:dup).bind_call(@jobs)
      mailers = Array.instance_method(:dup).bind_call(@mailers)
      raise LimitExceeded, 'Job/mail class limit' if jobs.length + mailers.length > @limits.fetch(:max_facts)
      result['status'] = 'observed'
      [[jobs, 'job'], [mailers, 'mailer']].each do |classes, kind|
        classes.each do |klass|
          raise TypeError, 'Loaded Class required' unless exact?(klass, Class)
          count_entry
          result['classes'] << charge_entry(observe(klass, kind))
        end
      end
      encoded_bytes(result, @budget)
      result
    end

    private

    # The private 8.1 class_attribute leaf shares its ISeq across all attributes.
    # Compare it to a framework-created probe before binding. 7.1 has per-reader
    # code; accept only its framework-file, pure captured-value leaf. Unknown VM
    # or overridden storage stays unavailable. No application-controlled getter runs;
    # 7.1 binds only the verified public pure-storage leaf, 8.1 the private leaf.
    def registry(klass, attribute)
      return unless defined?(RubyVM::InstructionSequence)
      reader = @version == '7.1.6' ? attribute : "__class_attr_#{attribute}".to_sym
      singleton = Object.instance_method(:singleton_class).bind_call(klass)
      getter = Module.instance_method(:instance_method).bind_call(singleton, reader)
      code = RubyVM::InstructionSequence.of(getter)
      factory = Class.instance_method(:class_attribute)
      factory_location = UnboundMethod.instance_method(:source_location).bind_call(factory)
      return unless factory_location && factory_location[0].end_with?('/active_support/core_ext/class/attribute.rb')
      probe = Class.new
      factory.bind_call(probe, attribute, instance_accessor: false)
      probe_singleton = Object.instance_method(:singleton_class).bind_call(probe)
      trusted = Module.instance_method(:instance_method).bind_call(probe_singleton, reader)
      trusted_code = RubyVM::InstructionSequence.of(trusted)
      if @version == '7.1.6'
        return unless code && trusted_code
        location = UnboundMethod.instance_method(:source_location).bind_call(getter)
        origin = UnboundMethod.instance_method(:source_location).bind_call(trusted)
        return unless location == origin
        data = RubyVM::InstructionSequence.instance_method(:to_a).bind_call(code)
        return unless data[9] == :block && data[11] == {} && data[12] == [] &&
          data[13].instance_of?(Array) && data[13].grep(Array) == [[:getlocal_WC_1, 3], [:leave]]
      else
        return unless code && code.equal?(trusted_code)
      end
      value = getter.bind_call(klass)
      return unless exact?(value, Array)
      raise LimitExceeded, 'Job/mail registry limit' if Array.instance_method(:length).bind_call(value) > @limits.fetch(:max_entries)
      Array.instance_method(:dup).bind_call(value)
    rescue NameError, TypeError
      nil
    end

    def observe(klass, kind)
      parent = Class.instance_method(:superclass).bind_call(klass)
      values = registry(klass, :rescue_handlers)
      inherited = parent && registry(parent, :rescue_handlers)
      parent_rows = {}.compare_by_identity
      inherited&.each { |row| parent_rows[row] = true }
      rows = values&.map do |row|
        count_entry
        if exact?(row, Array) && Array.instance_method(:length).bind_call(row) == 2
          charge_entry({ 'exception' => label(Array.instance_method(:[]).bind_call(row, 0)), 'handler' => reference(klass, Array.instance_method(:[]).bind_call(row, 1)),
            'shared_with_superclass' => inherited ? parent_rows.key?(row) : nil })
        else
          charge_entry({ 'exception' => nil, 'handler' => { 'kind' => 'opaque' }, 'shared_with_superclass' => nil })
        end
      end
      { 'kind' => kind, 'name' => label(Module.instance_method(:name).bind_call(klass)),
        'superclass' => parent && label(Module.instance_method(:name).bind_call(parent)),
        'rescue_handlers' => { 'status' => values ? 'observed' : 'unavailable', 'entries' => rows || [] } }
    end

    def reference(klass, value)
      if exact?(value, Symbol)
        method = Module.instance_method(:instance_method).bind_call(klass, value) rescue nil
        { 'kind' => 'method', 'name' => label(value),
          'owner' => method && label(Module.instance_method(:name).bind_call(UnboundMethod.instance_method(:owner).bind_call(method))),
          'source' => method && source(UnboundMethod.instance_method(:source_location).bind_call(method)) }
      elsif exact?(value, Proc)
        { 'kind' => 'proc', 'source' => source(Proc.instance_method(:source_location).bind_call(value)) }
      else
        { 'kind' => 'opaque' }
      end
    end

    def source(location)
      return unless exact?(location, Array) && location.length == 2
      path, line = location
      return unless exact?(line, Integer) && line.positive? && line <= 0xffff_ffff
      path = label(path)
      path && { 'path' => path, 'line' => line }
    end
  end
end
