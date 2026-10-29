# frozen_string_literal: true

require_relative 'model_observer'

module Thistle
  # Version-pinned framework observation only. ModelObserver supplies the bounded
  # primitive copier and streaming byte counter; Rust owns facts and identities.
  class CallbackObserver < ModelObserver
    def initialize(root:, **options)
      super(**options)
      @root = label(root)
    end

    def call
      @entries, @metadata_bytes = 0, 0
      @chains = {}.compare_by_identity
      version = defined?(ActiveRecord::VERSION::STRING) ? ActiveRecord::VERSION::STRING : nil
      result = { 'version' => 1, 'active_record_version' => label(version),
        'root' => @root, 'status' => 'unavailable', 'models' => [] }
      return result unless defined?(ActiveRecord::Base) && !ActiveRecord.autoload?(:Base) && SUPPORTED.include?(version)

      models = ActiveRecord::Base.descendants
      raise LimitExceeded, 'Loaded callback models exceed max_facts' if models.length > @limits.fetch(:max_facts)
      result['status'] = 'observed'
      bytes = 2
      models.each do |model|
        data = observe_callbacks(model)
        bytes += encoded_bytes(data, @budget - bytes - 1) + 1
        raise LimitExceeded, 'Callback observation exceeds evidence budget' if bytes > @budget
        result['models'] << data
      end
      result
    end

    private

    def ivar(object, name) = Object.instance_method(:instance_variable_get).bind_call(object, name)

    # Reading the registered chain does not compile it. Access only the pinned
    # Rails layout, using bound builtins so opaque filters cannot intercept reads.
    def chain(model)
      return @chains[model] if @chains.key?(model)
      @chains[model] = nil
      registry = stored_chains(model)
      return unless exact?(registry, Hash)
      value = Hash.instance_method(:fetch).bind_call(registry, :save, nil)
      return unless exact?(value, ActiveSupport::Callbacks::CallbackChain)
      entries = ivar(value, :@chain)
      return unless exact?(entries, Array)
      raise LimitExceeded, 'Callback chain exceeds max_entries' if entries.length > @limits.fetch(:max_entries)
      @chains[model] = Array.instance_method(:dup).bind_call(entries)
    rescue Thistle::Error
      raise
    rescue StandardError
      nil
    end

    # Rails 8.1.4 class_attribute stores each value in a generated private
    # closure. Read only that known value-reader code, never a model accessor.
    # An override or an unrecognized VM/layout makes this chain unavailable.
    def stored_chains(model)
      return unless defined?(RubyVM::InstructionSequence)
      singleton = Object.instance_method(:singleton_class).bind_call(model)
      getter = Module.instance_method(:instance_method).bind_call(singleton, :__class_attr___callbacks)
      unless @storage_reader_code
        probe = Class.new
        Class.instance_method(:class_attribute).bind_call(probe, :__callbacks, instance_accessor: false)
        probe_singleton = Object.instance_method(:singleton_class).bind_call(probe)
        probe_getter = Module.instance_method(:instance_method).bind_call(probe_singleton, :__class_attr___callbacks)
        @storage_reader_code = RubyVM::InstructionSequence.of(probe_getter)
      end
      code = RubyVM::InstructionSequence.of(getter)
      return unless code && code.equal?(@storage_reader_code)
      getter.bind_call(model)
    end

    def observe_callbacks(model)
      data = { 'name' => label(Module.instance_method(:name).bind_call(model)),
        'superclass' => nil, 'save' => { 'status' => 'unavailable', 'entries' => [] } }
      entries = chain(model)
      return data unless entries
      parent = Class.instance_method(:superclass).bind_call(model)
      data['superclass'] = label(Module.instance_method(:name).bind_call(parent)) if parent
      parent_entries = parent && chain(parent)
      parent_ids = {}.compare_by_identity
      parent_entries&.each { |entry| parent_ids[entry] = true }
      family = data['save']
      family['status'] = 'observed'
      entries.each do |callback|
        count_entry
        unless exact?(callback, ActiveSupport::Callbacks::Callback)
          family['status'] = 'partial'
          family['entries'] << charge_entry({ 'kind' => nil, 'filter' => { 'kind' => 'unavailable' },
            'if' => nil, 'unless' => nil, 'inherited' => nil })
          next
        end
        kind = label(ivar(callback, :@kind))
        kind = nil unless %w[before after around].include?(kind)
        row = { 'kind' => kind, 'filter' => reference(model, ivar(callback, :@filter)),
          'if' => conditions(model, ivar(callback, :@if)),
          'unless' => conditions(model, ivar(callback, :@unless)),
          'inherited' => parent_entries ? parent_ids.key?(callback) : nil }
        family['status'] = 'partial' if kind.nil? || row['if'].nil? || row['unless'].nil?
        family['entries'] << charge_entry(row)
      end
      data
    end

    def conditions(model, values)
      return nil unless exact?(values, Array)
      raise LimitExceeded, 'Callback conditions exceed max_entries' if values.length > @limits.fetch(:max_entries)
      values.map do |value|
        count_entry
        charge_entry(reference(model, value))
      end
    end

    def reference(model, value)
      if exact?(value, Symbol)
        name = label(value)
        return { 'kind' => 'opaque' } unless name
        method = begin
          Module.instance_method(:instance_method).bind_call(model, value)
        rescue NameError
          nil
        end
        { 'kind' => 'method', 'name' => name,
          'owner' => method && label(Module.instance_method(:name).bind_call(UnboundMethod.instance_method(:owner).bind_call(method))),
          'source' => method && source_hint(UnboundMethod.instance_method(:source_location).bind_call(method)) }
      elsif exact?(value, Proc)
        { 'kind' => 'proc', 'source' => source_hint(Proc.instance_method(:source_location).bind_call(value)) }
      else
        { 'kind' => 'opaque' }
      end
    rescue Thistle::Error
      raise
    rescue StandardError
      { 'kind' => 'unavailable' }
    end

    def source_hint(location)
      return nil unless exact?(location, Array) && location.length == 2
      path, line = location
      path = label(path)
      return nil unless path && exact?(line, Integer) && line.positive? && line <= 0xffff_ffff
      { 'path' => path, 'line' => line }
    end
  end
end
