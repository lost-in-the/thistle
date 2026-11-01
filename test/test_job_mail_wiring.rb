# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'json'

# Isolated stdlib doubles installed BEFORE loading facade/Reader hooks. No native
# library, framework, capture IO, store IO, application or template runs here.
class JobMailWiringTest < Minitest::Test
  PROGRAM = <<~'RUBY'
    require 'json'
    project, mode = ARGV
    require File.join(project, 'lib/thistle/errors')
    %w[native rails_capture model_observer callback_observer job_mail_observer source_comprehension_observer].each do |name|
      $LOADED_FEATURES << File.join(project, "lib/thistle/#{name}.rb")
    end
    module Thistle
      module Native
        class << self
          attr_accessor :calls, :refuse, :static, :family_results
          def path(value) = File.expand_path(value)
          def call(request)
            calls << request
            raise Thistle::LimitExceeded, 'stub refusal' if refuse == request.fetch('op')
            case request.fetch('op')
            when 'capture_publish' then { 'fast' => true }
            when 'capture' then static
            when 'publish' then { 'capture' => request.fetch('capture') }
            when 'open' then { 'handle' => 17, 'generation' => 'a' * 64, 'manifest' => {} }
            when 'close' then { 'closed' => true }
            when 'job_mail' then request
            else family_results.fetch(request.fetch('op'))
            end
          end
        end
      end
      class RailsCapture
        def initialize(**); end
        def call
          { 'facts' => [{ 'id' => 'route', 'links' => [{}] }], 'coverage' => [], 'diagnostics' => [], 'rails_version' => 'stub', 'evidence_bytes' => 7 }
        end
      end
      class ModelObserver
        class << self; attr_accessor :options; end
        def initialize(**options) = self.class.options = options
        def call = { 'stub' => 'model' }
      end
      class CallbackObserver < ModelObserver; end
      class SourceComprehensionObserver < ModelObserver
        def call(**) = { 'stub' => 'source_comprehension' }
      end
      class JobMailObserver < ModelObserver
        class << self; attr_accessor :options; end
        def initialize(**options) = self.class.options = options
        def call = { 'stub' => 'job_mail' }
      end
    end
    require File.join(project, 'lib/thistle')
    class LoadedBoundary; end
    class LoadedJob < LoadedBoundary
      def self.rescue_handlers = raise('application getter dispatched')
      def perform(*) = raise('application job dispatched')
    end
    class LoadedMailer
      def self.action_methods = raise('application mailer getter dispatched')
    end
    class NoSerialization
      def to_json(*) = raise('old fact metadata serialized')
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
    def added(family, bytes, links = 0)
      { 'facts' => [{ 'id' => family, 'links' => Array.new(links) { {} } }],
        'coverage' => [{ 'family' => family }], "#{family}_observer" => { 'version' => 1 },
        'appended' => { 'facts' => 1, 'links' => links, 'entries' => 4, 'fact_bytes' => bytes } }
    end
    old_links = CountedLinks.new([{}])
    Thistle::Native.calls = []
    Thistle::Native.static = {
      'schema_version' => 3, 'facts' => [{ 'id' => 'static', 'attributes' => NoSerialization.new, 'links' => old_links }],
      'coverage' => [], 'diagnostics' => [], 'producer' => { 'inventory_entries' => 70_000, 'explicit_template_entries' => 2, 'effective_limits' => {
        'max_facts' => 20, 'max_links' => 100, 'max_entries' => 100, 'max_diagnostics' => 10 } },
      'evidence_accounting' => { 'schema_version' => 3, 'fact_bytes_upper_bound' => 11 } }
    Thistle::Native.family_results = {
      'model_batch' => added('model',13,2), 'callback_batch' => added('callback',17,3),
      'source_comprehension_batch' => added('source_comprehension',19,5), 'job_mail_batch' => added('job_mail',23) }
    jobs = [LoadedJob]
    def jobs.each(*) = raise('application array override')
    config = { jobs: jobs, mailers: [LoadedMailer], templates: ['app/views/receipt_mailer/receipt.html.erb'] }
    if mode == 'default'
      check(Thistle.capture(root: '/fixture', output: '/store') == { 'fast' => true }, 'Default fast path changed')
      check(Thistle::Native.calls.map { |r| r['op'] } == ['capture_publish'], 'Default observed jobs')
    elsif mode == 'reader'
      reader = Thistle::Reader.new('/store', generation: 'a' * 64)
      value = reader.job_mail('b' * 64)
      check(value.values_at('op','handle','id','family','limit','cursor','max_bytes') == ['job_mail',17,'b' * 64,nil,8,nil,32768], 'Reader defaults changed')
      value = reader.job_mail('c' * 64, family: 'handoff', limit: 2, cursor: 'opaque', max_bytes: 4096)
      check(value.values_at('family','limit','cursor','max_bytes') == ['handoff',2,'opaque',4096], 'Reader inferred or dropped selectors')
      reader.close
      before = Thistle::Native.calls.length
      begin
        reader.job_mail('b' * 64)
        raise 'Closed Reader queried'
      rescue Thistle::Error
        check(Thistle::Native.calls.length == before, 'Closed Reader reached native')
      end
    else
      app = mode == 'missing_app' ? nil : Object.new
      config[:jobs] = [Object.new] if mode == 'invalid_class'
      config[:unknown] = true if mode == 'invalid_keys'
      if mode == 'hostile_config'
        def config.fetch(*) = raise('application config fetch')
        def config.size = raise('application config size')
        def config.key?(*) = raise('application config key')
        def config.nil? = raise('application config nil')
      end
      Thistle::Native.refuse = 'capture' if mode == 'template_refusal'
      Thistle::Native.refuse = 'job_mail_batch' if mode == 'batch_refusal'
      Thistle::Native.static['producer']['effective_limits']['max_entries'] = 5 if mode == 'entry_limit'
      Thistle::Native.static['producer'].delete('explicit_template_entries') if mode == 'missing_inventory_charge'
      if mode == 'large_families'
        Thistle::Native.static['producer']['effective_limits']['max_entries'] = 100_000
        Thistle::Native.family_results['model_batch']['appended']['entries'] = 40_000
        Thistle::Native.family_results['callback_batch']['appended']['entries'] = 50_000
        Thistle::Native.family_results['source_comprehension_batch']['appended']['entries'] = 60_000
      end
      charge_mode = { 'negative_template_charge' => -1, 'float_template_charge' => 2.0, 'string_template_charge' => '2',
        'overflow_template_charge' => 101 }
      Thistle::Native.static['producer']['explicit_template_entries'] = charge_mode[mode] if charge_mode.key?(mode)
      Thistle::Native.family_results['job_mail_batch']['appended']['entries'] = '4' if mode == 'invalid_job_charge'
      begin
        result = Thistle.capture(root: '/fixture', output: '/store', rails: app, job_mail: config,
          source_comprehension: { models: [LoadedJob], stop_before: LoadedBoundary })
        check(%w[composed hostile_config large_families].include?(mode), 'Refused input published')
        check(Thistle::Native.calls.map { |r| r['op'] } == %w[capture model_batch callback_batch source_comprehension_batch job_mail_batch publish], 'Wrong hook order')
        initial = Thistle::Native.calls.first
        check(initial.fetch('templates') == ['app/views/receipt_mailer/receipt.html.erb'], 'Paths were not forwarded to Rust IO')
        batch = Thistle::Native.calls.find { |r| r['op'] == 'job_mail_batch' }
        check(batch.fetch('context').values_at('facts','links','fact_bytes') == [5,12,67], '147 incremental charges lost')
        check(result.fetch('capture').fetch('evidence_accounting').fetch('fact_bytes_upper_bound') == 90, 'Final charge lost')
        check(old_links.length_calls == 1, 'Earlier facts walked again')
        [Thistle::ModelObserver, Thistle::CallbackObserver, Thistle::SourceComprehensionObserver].each do |observer|
          check(observer.options.fetch(:limits).fetch(:max_entries) == (mode == 'large_families' ? 100_000 : 100), 'Legacy per-batch entry allowance changed')
        end
        check(Thistle::JobMailObserver.options.values_at(:app,:root,:jobs,:mailers) == [app,'/fixture',[LoadedJob],[LoadedMailer]], 'Explicit observer boundary lost')
        check(Thistle::JobMailObserver.options.fetch(:limits).fetch(:max_entries) == (mode == 'large_families' ? 99_998 : 98), 'Job allowance includes unrelated entries')
      rescue Thistle::InvalidInput, Thistle::LimitExceeded, KeyError
        check(!%w[composed hostile_config large_families].include?(mode), 'Unexpected refusal')
        check(Thistle::Native.calls.none? { |r| r['op'] == 'publish' }, 'Publication followed refusal')
        check(Thistle::Native.calls.empty?, 'Invalid config reached capture') if %w[missing_app invalid_class invalid_keys].include?(mode)
      end
    end
    check(!defined?(Rails) && !defined?(ActiveRecord), 'Framework loaded')
    check($LOADED_FEATURES.none? { |p| p.include?('thistle_native') && p.end_with?('.so','.bundle') }, 'Native loaded')
    puts JSON.generate('mode' => mode, 'operations' => Thistle::Native.calls.map { |r| r['op'] }, 'scope' => 'stdlib doubles only')
  RUBY

  %w[default reader composed hostile_config missing_app invalid_class invalid_keys template_refusal batch_refusal entry_limit missing_inventory_charge large_families negative_template_charge float_template_charge string_template_charge overflow_template_charge invalid_job_charge].each do |mode|
    define_method("test_#{mode}") do
      out, err, status = Open3.capture3(RbConfig.ruby, '-e', PROGRAM, File.expand_path('..', __dir__), mode)
      assert status.success?, "#{mode}: #{err}"
      assert_equal mode, JSON.parse(out).fetch('mode')
    end
  end
end
