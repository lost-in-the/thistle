# frozen_string_literal: true

require 'json'

module Thistle
  # Observes already loaded Active Record classes. Never resolves target constants,
  # creates records, builds relations, or reads effective Ruby attribute defaults.
  class ModelObserver
    VERSION = 1
    SUPPORTED = ['8.1.4'].freeze
    OPTIONS = %i[class_name foreign_key primary_key foreign_type as through source source_type inverse_of dependent optional required autosave counter_cache touch].freeze

    def initialize(limits:, evidence_budget:)
      @limits = limits
      @budget = evidence_budget
      @entries = 0
      @metadata_bytes = 0
      @failed_pools = {}.compare_by_identity
    end

    def call
      @failed_pools.clear
      version = defined?(ActiveRecord::VERSION::STRING) ? ActiveRecord::VERSION::STRING : nil
      result = { 'version' => VERSION, 'active_record_version' => version, 'status' => 'unavailable', 'models' => [] }
      # Do not trigger an autoload of Base in a Rails app that has not used it.
      return result unless defined?(ActiveRecord::Base) && !ActiveRecord.autoload?(:Base) && SUPPORTED.include?(version)

      models = ActiveRecord::Base.descendants
      raise LimitExceeded, 'Loaded models exceed max_facts' if models.length > @limits.fetch(:max_facts)
      result['status'] = 'observed'
      bytes = 2
      models.each do |model|
        observed = observe(model)
        bytes += JSON.generate(observed).bytesize + 1
        raise LimitExceeded, 'Model observation exceeds evidence budget' if bytes > @budget
        result['models'] << observed
      end
      result
    end

    private

    def observe(model)
      pool = nil
      data = { 'name' => label(Module.instance_method(:name).bind_call(model)),
        'base_class' => nil, 'superclass' => nil, 'abstract' => nil, 'table' => nil,
        'primary_key' => nil, 'inheritance_column' => nil,
        'columns' => unavailable, 'associations' => unavailable }
      begin
        data['base_class'] = label(Module.instance_method(:name).bind_call(model.base_class))
        data['superclass'] = label(Module.instance_method(:name).bind_call(Class.instance_method(:superclass).bind_call(model)))
        data['abstract'] = boolean(model.abstract_class?)
        data['inheritance_column'] = label(model.inheritance_column)
        unless data['abstract']
          pool = model.connection_pool
          # A checkout failure applies to this pool during this capture, including
          # lazy primary-key lookup. Do not retry it for every loaded model.
          unless @failed_pools.key?(pool)
            data['table'] = label(model.table_name)
            key = model.primary_key
            data['primary_key'] = if exact?(key, Array)
              raise LimitExceeded, 'Model primary key exceeds max_entries' if key.length > @limits.fetch(:max_entries)
              key.map { |entry| label(entry) }
            elsif exact?(key, String)
              [label(key)]
            end
            # Raw adapter schema avoids model.columns / column_defaults, whose schema
            # setup can materialize custom attribute types or Ruby default values.
            columns = pool.schema_cache.columns_hash(data['table'])
            data['columns'] = { 'status' => 'observed', 'entries' => columns.values.map { |column| observe_column(column) } }
          end
        end
      rescue Thistle::Error
        raise
      rescue StandardError => error
        if pool && defined?(ActiveRecord::ConnectionNotEstablished) && error.is_a?(ActiveRecord::ConnectionNotEstablished)
          @failed_pools[pool] = true
        end
        # Keep safely obtained identity fields; no exception message or object is serialized.
      end
      begin
        entries = model.reflect_on_all_associations.map { |reflection| observe_association(reflection) }
        data['associations'] = { 'status' => 'observed', 'entries' => entries }
      rescue Thistle::Error
        raise
      rescue StandardError
        # Unavailable is not an empty successful family.
      end
      data
    end

    def unavailable = { 'status' => 'unavailable', 'entries' => [] }

    def count_entry
      @entries += 1
      raise LimitExceeded, 'Model metadata exceeds max_entries' if @entries > @limits.fetch(:max_entries)
    end

    def charge_entry(entry)
      @metadata_bytes += JSON.generate(entry).bytesize + 1
      raise LimitExceeded, 'Model metadata exceeds evidence budget' if @metadata_bytes > @budget
      entry
    end

    def observe_column(column)
      count_entry
      charge_entry({ 'name' => label(column.name), 'type' => label(column.type), 'sql_type' => label(column.sql_type),
        'null' => boolean(column.null),
        'default' => exact?(column.default_function, NilClass) ? scalar(column.default) : { 'kind' => 'expression' } })
    end

    def observe_association(reflection)
      count_entry
      options = reflection.options
      raise TypeError unless exact?(options, Hash)
      represented = {}
      OPTIONS.each do |key|
        next unless Hash.instance_method(:key?).bind_call(options, key)
        represented[key.to_s] = scalar(Hash.instance_method(:[]).bind_call(options, key))
      end
      polymorphic_value = Hash.instance_method(:[]).bind_call(options, :polymorphic)
      polymorphic = exact?(polymorphic_value, NilClass) ? false : boolean(polymorphic_value)
      separately_represented = Hash.instance_method(:key?).bind_call(options, :polymorphic) ? 1 : 0
      through = label(Hash.instance_method(:[]).bind_call(options, :through))
      explicit_target = Hash.instance_method(:[]).bind_call(options, :class_name)
      # ThroughReflection.class_name can resolve through_reflection.klass. Read
      # only a declared label there; never make metadata observation autoload code.
      target = if polymorphic == false
        if Hash.instance_method(:key?).bind_call(options, :through) || !exact?(explicit_target, NilClass)
          label(explicit_target)
        else
          label(reflection.class_name)
        end
      end
      charge_entry({ 'name' => label(reflection.name), 'macro' => label(reflection.macro),
        'target' => target,
        'polymorphic' => polymorphic, 'through' => through,
        'scope' => exact?(reflection.scope, NilClass) ? 'none' : 'opaque', 'options' => represented,
        'omitted_options' => Hash.instance_method(:size).bind_call(options) - represented.length - separately_represented })
    end

    def exact?(value, klass) = Object.instance_method(:instance_of?).bind_call(value, klass)

    def boolean(value)
      return true if exact?(value, TrueClass)
      return false if exact?(value, FalseClass)
      nil
    end

    def label(value)
      value = Symbol.instance_method(:to_s).bind_call(value) if exact?(value, Symbol)
      return nil unless exact?(value, String)
      raise LimitExceeded, 'Model label exceeds 4096 bytes' if String.instance_method(:bytesize).bind_call(value) > 4096
      copy = String.instance_method(:encode).bind_call(value, Encoding::UTF_8)
      copy unless copy.empty? || !copy.valid_encoding? || copy.bytesize > 4096
    rescue EncodingError
      nil
    end

    # Use bound builtin methods and fresh strings, including for objects with
    # singleton overrides. Never call inspect, to_s, to_json, or a proc on opaque data.
    def scalar(value)
      if exact?(value, Symbol)
        text = label(value)
        return text ? { 'kind' => 'symbol', 'value' => text } : { 'kind' => 'opaque' }
      elsif exact?(value, String)
        text = label(value)
        return { 'kind' => 'literal', 'value' => text } if text
        return { 'kind' => 'literal', 'value' => '' } if exact?(value, String) && String.instance_method(:empty?).bind_call(value)
      elsif exact?(value, NilClass) || exact?(value, TrueClass) || exact?(value, FalseClass)
        return { 'kind' => 'literal', 'value' => value }
      elsif exact?(value, Integer) && Integer.instance_method(:bit_length).bind_call(value) <= 63
        return { 'kind' => 'literal', 'value' => value }
      elsif exact?(value, Float) && Float.instance_method(:finite?).bind_call(value)
        return { 'kind' => 'literal', 'value' => value }
      end
      { 'kind' => 'opaque' }
    end
  end
end
