# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'json'

# Each probe is an isolated stdlib process with Native/registry adapters stubbed
# BEFORE loading the facade. No native library, Rails, store, parser or DB runs.
# Isolation keeps these doubles out of the real native suite's process.
class SourceComprehensionWiringTest < Minitest::Test
  PROGRAM = <<~'RUBY'
    require 'json'
    project, mode = ARGV
    require File.join(project, 'lib/thistle/errors')
    $LOADED_FEATURES << File.join(project, 'lib/thistle/native.rb')
    module Thistle
      module Native
        class << self
          attr_accessor :calls, :refuse, :static, :family_results
          def path(value) = File.expand_path(value)
          def call(request)
            calls << request
            case request.fetch('op')
            when 'capture_publish' then { 'fast' => true }
            when 'capture' then static
            when 'publish' then { 'capture' => request.fetch('capture') }
            when 'open' then { 'handle' => 17, 'generation' => 'a' * 64, 'manifest' => {} }
            when 'close' then { 'closed' => true }
            when 'source_comprehension' then request
            when 'model_batch', 'callback_batch', 'source_comprehension_batch'
              raise Thistle::LimitExceeded, 'stub refusal' if refuse == request.fetch('op')
              family_results.fetch(request.fetch('op'))
            else raise "Unexpected native operation #{request.fetch('op')}"
            end
          end
        end
      end
    end
    require File.join(project, 'lib/thistle')
    require File.join(project, 'lib/thistle/capture')
    require File.join(project, 'lib/thistle/source_comprehension_observer')
    class Boundary; end
    class Model < Boundary
      def label = 'unchanged'
    end
    class NoSerialization
      def to_json(*) = raise('old fact metadata was serialized')
    end
    class CountedLinks < Array
      attr_reader :length_calls
      def length
        @length_calls = (@length_calls || 0) + 1
        super
      end
    end
    def check(value, message)
      raise message unless value
    end
    def added(family, id, bytes, links = 0)
      { 'facts' => [{ 'id' => id, 'links' => Array.new(links) { {} } }],
        'coverage' => [{ 'family' => family }], "#{family}_observer" => { 'version' => 1 },
        'appended' => { 'facts' => 1, 'links' => links, 'entries' => 4, 'fact_bytes' => bytes } }
    end
    links = CountedLinks.new([{}])
    Thistle::Native.calls = []
    Thistle::Native.static = {
      'schema_version' => 3, 'facts' => [{ 'id' => 'static', 'attributes' => NoSerialization.new, 'links' => links }],
      'coverage' => [], 'diagnostics' => [], 'producer' => { 'effective_limits' => {
        'max_facts' => 20, 'max_links' => 100, 'max_entries' => 100, 'max_diagnostics' => 10 } },
      'evidence_accounting' => { 'schema_version' => 3, 'fact_bytes_upper_bound' => 11 } }
    Thistle::Native.family_results = {
      'model_batch' => added('model', 'model', 13, 2),
      'callback_batch' => added('callback', 'callback', 17, 3),
      'source_comprehension_batch' => added('source_comprehension', 'ownership', 19) }
    config = { models: [Model], stop_before: Boundary }
    case mode
    when 'default'
      check(Thistle.capture(root: '/fixture', output: '/store') == { 'fast' => true }, 'Default fast path changed')
      check(Thistle::Native.calls.map { |r| r['op'] } == ['capture_publish'], 'Default observed metadata')
      check(links.length_calls.nil?, 'Default fast path inspected old facts')
    when 'source_only', 'refusal', 'limit', 'invalid'
      if mode == 'refusal'
        Thistle::Native.refuse = 'source_comprehension_batch'
      elsif mode == 'limit'
        Thistle::Native.static['producer']['effective_limits']['max_entries'] = 1
      elsif mode == 'invalid'
        config = { models: [Object.new], stop_before: Boundary }
      end
      begin
        result = Thistle.capture(root: '/fixture', output: '/store', source_comprehension: config)
        check(mode == 'source_only', 'Refusal unexpectedly published')
        captured = result.fetch('capture')
        check(captured.fetch('evidence_accounting').fetch('fact_bytes_upper_bound') == 30, 'Append charge lost')
        check(captured.fetch('producer').fetch('source_comprehension_observer') == { 'version' => 1 }, 'Producer descriptor lost')
        batch = Thistle::Native.calls.find { |r| r['op'] == 'source_comprehension_batch' }
        check(batch.fetch('root') == '/fixture', 'Batch root lost')
        check(batch.fetch('context').values_at('facts', 'links', 'fact_bytes') == [1, 1, 11], 'Old counters changed')
        check(batch.fetch('observation')['models'][0]['name'] == 'Model', 'Explicit classes were not observed')
        check(links.length_calls == 1, 'Earlier fact links were repeatedly walked')
      rescue Thistle::LimitExceeded, Thistle::InvalidInput
        check(mode != 'source_only', 'Unexpected source-only refusal')
        check(Thistle::Native.calls.none? { |r| r['op'] == 'publish' }, 'Publication followed failed observation/batch')
        check(Thistle::Native.calls.empty?, 'Invalid config reached capture') if mode == 'invalid'
      end
    when 'after_rails'
      $LOADED_FEATURES << File.join(project, 'lib/thistle/rails_capture.rb')
      $LOADED_FEATURES << File.join(project, 'lib/thistle/callback_observer.rb')
      module Thistle
        class RailsCapture
          def initialize(**); end
          def call
            { 'facts' => [{ 'id' => 'route', 'links' => [{}] }], 'coverage' => [], 'diagnostics' => [], 'rails_version' => 'stub', 'evidence_bytes' => 7 }
          end
        end
        class ModelObserver
          def call = { 'stub' => 'model' }
        end
        class CallbackObserver
          def initialize(**); end
          def call = { 'stub' => 'callback' }
        end
      end
      result = Thistle.capture(root: '/fixture', output: '/store', rails: Object.new, source_comprehension: config)
      batch = Thistle::Native.calls.find { |r| r['op'] == 'source_comprehension_batch' }
      check(Thistle::Native.calls.map { |r| r['op'] } == %w[capture model_batch callback_batch source_comprehension_batch publish], 'Source observer did not follow existing Rails families')
      check(batch.fetch('context').values_at('facts', 'links', 'fact_bytes') == [4, 7, 48], 'Incremental Rails-family counters lost')
      check(result['capture']['evidence_accounting']['fact_bytes_upper_bound'] == 67, 'Final byte charge lost')
      check(links.length_calls == 1, 'Static facts walked again after Rails families')
    when 'reader'
      reader = Thistle::Reader.new('/store', generation: 'a' * 64)
      default = reader.source_comprehension('b' * 64)
      check(default.values_at('op', 'handle', 'family', 'limit', 'cursor', 'max_bytes') == ['source_comprehension', 17, nil, 8, nil, 32768], 'Reader default request changed')
      selected = reader.source_comprehension('b' * 64, family: 'methods', limit: 2, cursor: 'cursor', max_bytes: 4096)
      check(selected.values_at('family', 'limit', 'cursor', 'max_bytes') == ['methods', 2, 'cursor', 4096], 'Reader derived or dropped selectors')
      reader.close
      before = Thistle::Native.calls.length
      begin
        reader.source_comprehension('b' * 64)
        raise 'Closed Reader queried'
      rescue Thistle::Error
        check(Thistle::Native.calls.length == before, 'Closed Reader reached Native')
      end
    else raise 'Unknown probe'
    end
    check(!defined?(Rails) && !defined?(ActiveRecord), 'Framework was loaded')
    check($LOADED_FEATURES.none? { |path| path.end_with?('.so', '.bundle') && path.include?('thistle_native') }, 'Native was loaded')
    puts JSON.generate('mode' => mode, 'operations' => Thistle::Native.calls.map { |r| r['op'] }, 'scope' => 'stdlib doubles only')
  RUBY

  %w[default source_only refusal limit invalid after_rails reader].each do |mode|
    define_method("test_#{mode}") do
      out, err, status = Open3.capture3(RbConfig.ruby, '-e', PROGRAM, File.expand_path('..', __dir__), mode)
      assert status.success?, "#{mode}: #{err}"
      assert_equal mode, JSON.parse(out).fetch('mode')
    end
  end
end
