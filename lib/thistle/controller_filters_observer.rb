# frozen_string_literal: true

require_relative 'callback_observer'

module Thistle
  # Explicit inventory only. Reuses the guarded framework storage reader and
  # builtin descriptors; never calls _process_action_callbacks or a condition.
  class ControllerFiltersObserver < CallbackObserver
    def initialize(app:, controllers:, framework_version:, **options)
      super(**options)
      @app, @controllers, @framework_version = app, controllers, label(framework_version)
    end

    def call
      @entries = @metadata_bytes = 0
      @chains = {}.compare_by_identity
      result = { 'version' => 1, 'framework_version' => @framework_version,
        'root' => @root, 'status' => 'unavailable', 'controllers' => [] }
      return result unless @app && @framework_version == '8.1.4'
      raise InvalidInput, 'Explicit loaded controller array required' unless exact?(@controllers, Array)
      raise LimitExceeded, 'Controller count exceeds max_facts' if @controllers.length > @limits.fetch(:max_facts)
      result['status'] = 'observed'
      @controllers.each do |controller|
        raise InvalidInput, 'Loaded controller Class required' unless exact?(controller, Class)
        count_entry
        rows = process_chain(controller)
        parent = Class.instance_method(:superclass).bind_call(controller)
        inherited = parent && process_chain(parent)
        shared = {}.compare_by_identity
        inherited&.each { |row| shared[row] = true }
        entries = (rows || []).map do |callback|
          count_entry
          if defined?(ActiveSupport::Callbacks::Callback) && exact?(callback, ActiveSupport::Callbacks::Callback)
            kind = label(ivar(callback, :@kind))
            kind = nil unless %w[before after around].include?(kind)
            charge_entry({ 'kind' => kind, 'filter' => reference(controller, ivar(callback, :@filter)),
              'if' => action_conditions(ivar(callback, :@if)), 'unless' => action_conditions(ivar(callback, :@unless)),
              'inherited' => inherited ? shared.key?(callback) : nil })
          else
            charge_entry({ 'kind' => nil, 'filter' => { 'kind' => 'unavailable' },
              'if' => nil, 'unless' => nil, 'inherited' => nil })
          end
        end
        result['controllers'] << charge_entry({ 'name' => label(Module.instance_method(:name).bind_call(controller)),
          'superclass' => parent && label(Module.instance_method(:name).bind_call(parent)),
          'status' => rows ? 'observed' : 'unavailable', 'entries' => entries })
      end
      encoded_bytes(result, @budget)
      result
    end

    private

    # The inherited storage guard is pinned to the 8.1 private class-attribute leaf.
    def rails71? = false

    def process_chain(controller)
      return @chains[controller] if @chains.key?(controller)
      @chains[controller] = nil
      registry = stored_chains(controller)
      return unless exact?(registry, Hash)
      chain = Hash.instance_method(:fetch).bind_call(registry, :process_action, nil)
      return unless defined?(ActiveSupport::Callbacks::CallbackChain) && exact?(chain, ActiveSupport::Callbacks::CallbackChain)
      rows = ivar(chain, :@chain)
      return unless exact?(rows, Array)
      raise LimitExceeded, 'Controller registry exceeds max_entries' if rows.length > @limits.fetch(:max_entries)
      @chains[controller] = Array.instance_method(:dup).bind_call(rows)
    rescue NameError, TypeError
      nil
    end

    def action_conditions(values)
      return nil unless exact?(values, Array)
      raise LimitExceeded, 'Filter conditions exceed max_entries' if values.length > @limits.fetch(:max_entries)
      values.map do |value|
        count_entry
        row = { 'kind' => 'opaque' }
        if defined?(AbstractController::Callbacks::ActionFilter) &&
            !AbstractController::Callbacks.autoload?(:ActionFilter) && exact?(value, AbstractController::Callbacks::ActionFilter)
          mode = ivar(value, :@conditional_key)
          actions = ivar(value, :@actions)
          if %i[only except].include?(mode) && defined?(Set) && exact?(actions, Set)
            table = ivar(actions, :@hash)
            names = if exact?(table, Hash)
              raise LimitExceeded, 'Filter action labels exceed max_entries' if Hash.instance_method(:size).bind_call(table) > @limits.fetch(:max_entries)
              Hash.instance_method(:keys).bind_call(table)
            else
              # Ruby 4's builtin Set has no @hash. Bind only native size/to_a
              # leaves; a Ruby override remains opaque and is never dispatched.
              size = Set.instance_method(:size)
              array = Set.instance_method(:to_a)
              if UnboundMethod.instance_method(:source_location).bind_call(size).nil? &&
                  UnboundMethod.instance_method(:source_location).bind_call(array).nil?
                raise LimitExceeded, 'Filter action labels exceed max_entries' if size.bind_call(actions) > @limits.fetch(:max_entries)
                array.bind_call(actions)
              end
            end
            if exact?(names, Array)
              names.each { count_entry }
              names = names.map { |name| label(name) }
              row = { 'kind' => 'actions', 'mode' => mode.to_s, 'actions' => names } if names.none?(&:nil?)
            end
          end
        end
        charge_entry(row)
      end
    end
  end
end
