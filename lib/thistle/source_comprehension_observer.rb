# frozen_string_literal: true

require_relative 'errors'
require_relative 'model_observer'

module Thistle
  # Raw builtin reflection over explicitly supplied classes. No framework getter,
  # constant lookup, method body, autoload or application override is dispatched.
  # Rust interprets these labels/hints; this adapter never chooses source facts.
  class SourceComprehensionObserver < ModelObserver
    MAX_ANCESTORS = 64
    MAX_METHODS = 2048

    def call(models:, stop_before:)
      raise InvalidInput, 'Expected an explicit model Array' unless exact?(models, Array)
      raise LimitExceeded, 'Ownership models exceed max_facts' if models.length > @limits.fetch(:max_facts)
      @entries = @metadata_bytes = 0
      result = { 'version' => 1, 'models' => [] }
      models.each do |model|
        raise InvalidInput, 'Expected loaded model Class' unless exact?(model, Class)
        ancestors = Module.instance_method(:ancestors).bind_call(model)
        boundary = ancestors.index { |owner| same?(owner, stop_before) }
        # An unknown boundary cannot masquerade as a complete application chain.
        raise InvalidInput, 'Ownership stop boundary is absent' unless boundary
        owners = ancestors.take(boundary)
        raise LimitExceeded, 'Ownership ancestors exceed 64' if owners.length > MAX_ANCESTORS
        observed = observe_ownership(model, owners, stop_before)
        result['models'] << charge_entry(observed)
      end
      # Includes envelope/commas, unlike the per-entry conservative accounting.
      encoded_bytes(result, @budget)
      result
    end

    private

    def observe_ownership(model, owners, stop_before)
      names = {} # symbols returned by builtin reflection only
      direct_names = []
      rows = owners.each_with_index.map do |owner, index|
        count_entry
        methods = []
        direct_names[index] = {}
        %i[public protected private].each do |visibility|
          Module.instance_method(:"#{visibility}_instance_methods").bind_call(owner, false).each do |name|
            count_entry
            raise LimitExceeded, 'Ownership method names exceed 2048' if names.length >= MAX_METHODS && !names.key?(name)
            names[name] = true
            direct_names[index][name] = true
            method = Module.instance_method(:instance_method).bind_call(owner, name)
            # With prepends instance_method may select a different owner's body.
            # Follow super_method through builtin descriptors to the actual row.
            steps = 0
            until method.nil? || same?(UnboundMethod.instance_method(:owner).bind_call(method), owner)
              raise LimitExceeded, 'Ownership descriptor chain exceeds 64' if (steps += 1) > MAX_ANCESTORS
              method = UnboundMethod.instance_method(:super_method).bind_call(method)
            end
            methods << { 'name' => label(name), 'visibility' => visibility.to_s,
              'source' => method && source_hint(UnboundMethod.instance_method(:source_location).bind_call(method)) }
          end
        end
        { 'index' => index, 'name' => label(Module.instance_method(:name).bind_call(owner)),
          'kind' => exact?(owner, Class) ? 'class' : 'module', 'methods' => methods }
      end
      effective = names.keys.map do |name|
        count_entry
        effective_descriptor(model, name, owners, direct_names)
      end
      { 'name' => label(Module.instance_method(:name).bind_call(model)),
        'status' => 'observed', 'superclass' => label(Module.instance_method(:name).bind_call(ancillary_parent(model))),
        'stop_before' => label(Module.instance_method(:name).bind_call(stop_before)),
        'ancestors' => rows, 'effective_methods' => effective }
    end

    def ancillary_parent(model) = Class.instance_method(:superclass).bind_call(model)
    def same?(a, b) = BasicObject.instance_method(:equal?).bind_call(a, b)

    def effective_descriptor(model, name, owners, direct_names)
      method = Module.instance_method(:instance_method).bind_call(model, name)
      owner = UnboundMethod.instance_method(:owner).bind_call(method)
      index = owners.index { |entry| same?(entry, owner) }
      # Visibility-only entries can resolve to a body beyond the boundary.
      # A body with no inventoried direct row cannot establish an owner here.
      index = nil unless index && direct_names[index].key?(name)
      { 'name' => label(name), 'owner_index' => index,
        'source' => index ? source_hint(UnboundMethod.instance_method(:source_location).bind_call(method)) : nil }
    rescue NameError
      # Undef/removal/concurrent mutation remains explicit, not a guessed owner.
      { 'name' => label(name), 'owner_index' => nil, 'source' => nil }
    end

    def source_hint(location)
      return nil unless exact?(location, Array) && location.length == 2
      path, line = location
      return nil unless exact?(line, Integer) && line.positive? && line <= 0xffff_ffff
      path = label(path)
      path ? { 'path' => path, 'line' => line } : nil
    end
  end
end
