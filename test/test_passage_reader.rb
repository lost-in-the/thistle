# frozen_string_literal: true

# Standalone primitive forwarding check; no native library, store or framework.
if $PROGRAM_NAME == __FILE__
  require_relative '../lib/thistle/errors'
  $LOADED_FEATURES << File.expand_path('../lib/thistle/native.rb', __dir__)
  module Thistle
    module Native
      class << self
        attr_accessor :calls
        def path(value) = value
        def call(request)
          calls << request
          case request.fetch('op')
          when 'open' then {'handle'=>19,'generation'=>'a'*64,'manifest'=>{}}
          when 'close' then nil
          when 'passage' then request
          else raise 'Unexpected operation'
          end
        end
      end
    end
  end
  require_relative '../lib/thistle/reader'
  Thistle::Native.calls = []
  reader = Thistle::Reader.new('mock-only')
  expected = {'op'=>'passage','handle'=>19,'id'=>'b'*64,'action'=>nil,'family'=>'sequence','limit'=>8,'cursor'=>nil,'max_bytes'=>32768}
  raise 'Reader defaults changed' unless reader.passage('b'*64) == expected
  answer = reader.passage('b'*64, action:'c'*64, family:'export',limit:1,cursor:'opaque',max_bytes:2048)
  raise 'Reader derived semantics or dropped controls' unless answer == expected.merge('action'=>'c'*64,'family'=>'export','limit'=>1,'cursor'=>'opaque','max_bytes'=>2048)
  reader.close
  before = Thistle::Native.calls.length
  begin
    reader.passage('b'*64)
    raise 'Closed reader accepted'
  rescue Thistle::Error
    raise 'Closed reader crossed Native' unless Thistle::Native.calls.length == before
  end
  puts 'PASS primitive passage defaults/controls and closed Reader refusal (Native double)'

  # The orchestration probe supplies inert doubles for all legacy observers and
  # route capture. It verifies append counters, never loads a framework/native.
  $LOADED_FEATURES << File.expand_path('../lib/thistle/rails_capture.rb', __dir__)
  $LOADED_FEATURES << File.expand_path('../lib/thistle/model_observer.rb', __dir__)
  $LOADED_FEATURES << File.expand_path('../lib/thistle/callback_observer.rb', __dir__)
  $LOADED_FEATURES << File.expand_path('../lib/thistle/controller_filters_observer.rb', __dir__)
  module Rails
    module VERSION
      STRING = '8.1.4'
    end
  end
  module Thistle
    class RailsCapture
      def initialize(**); end
      def call
        {'facts'=>[{'links'=>[{}]},{'links'=>[{}]}],'coverage'=>[],'diagnostics'=>[],
          'rails_version'=>'8.1.4','evidence_bytes'=>7}
      end
    end
    class ModelObserver
      def initialize(**); end
      def call = {'inert'=>true}
    end
    class CallbackObserver < ModelObserver; end
    class ControllerFiltersObserver < ModelObserver; end
    module Native
      def self.call(request)
        calls << request
        case request.fetch('op')
        when 'capture'
          {'schema_version'=>3,'producer'=>{'effective_limits'=>{'max_facts'=>10,'max_links'=>10,'max_entries'=>2,'max_diagnostics'=>10}},
            'facts'=>[{'links'=>[{}]}],'coverage'=>[],'diagnostics'=>[],
            'evidence_accounting'=>{'schema_version'=>3,'fact_bytes_upper_bound'=>2}}
        when /_batch\z/
          family = request.fetch('op').delete_suffix('_batch')
          {'facts'=>[{'links'=>[{}]}],'coverage'=>[],'appended'=>{'facts'=>1,'links'=>1,'entries'=>2,'fact_bytes'=>5},"#{family}_observer"=>{}}
        else raise 'Unexpected mocked capture operation'
        end
      end
    end
  end
  require_relative '../lib/thistle/capture'
  Thistle::Native.calls = []
  plain = Thistle::Capture.new(root:'/public').call
  raise 'Default capture changed' unless Thistle::Native.calls.map { |r|r['op'] } == ['capture'] && plain['facts'].length == 1
  Thistle::Native.calls = []
  result = Thistle::Capture.new(root:'/public',rails:Object.new,controller_filters:[Class.new]).call
  batches = Thistle::Native.calls.select { |r|r['op'].end_with?('_batch') }
  raise 'Wrong append order' unless batches.map { |r|r['op'] } == %w[model_batch callback_batch controller_filters_batch]
  raise 'Old evidence was recombined or reserialized' unless batches.map { |r|r.dig('context','facts') } == [3,4,5] && batches.map { |r|r.dig('context','links') } == [3,4,5]
  raise 'Legacy per-batch entries changed' unless batches.all? { |r|r.dig('context','limits',:max_entries) == 2 }
  raise 'Incremental bytes lost' unless result.dig('evidence_accounting','fact_bytes_upper_bound') == 24
  puts 'PASS nil path and explicit-controller incremental facts/links/bytes; legacy max_entries remains per batch (all doubles)'
end
