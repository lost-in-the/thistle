# frozen_string_literal: true

# Standalone forwarding evidence only; Native is an inert double.
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
          when 'open' then { 'handle' => 149, 'generation' => 'a' * 64, 'manifest' => {} }
          when 'close' then nil
          when 'model_neighborhood' then request
          else raise 'Unexpected native operation'
          end
        end
      end
    end
  end
  require_relative '../lib/thistle/reader'
  Thistle::Native.calls = []
  reader = Thistle::Reader.new('mock-only')
  expected = { 'op' => 'model_neighborhood', 'handle' => 149, 'id' => 'b' * 64,
    'family' => 'edges', 'direction' => 'outgoing', 'type' => 'all', 'candidate' => nil,
    'limit' => 8, 'cursor' => nil, 'max_bytes' => 32768 }
  raise 'Defaults changed' unless reader.model_neighborhood('b' * 64) == expected
  controls = { family: 'candidates', direction: 'outgoing', type: 'association', candidate: 'a:12', limit: 1, cursor: 'opaque', max_bytes: 4096 }
  raise 'Ruby interpreted or dropped controls' unless reader.model_neighborhood('b' * 64, **controls) == expected.merge(controls.transform_keys(&:to_s))
  reader.close
  before = Thistle::Native.calls.length
  begin
    reader.model_neighborhood('b' * 64)
    raise 'Closed reader accepted'
  rescue Thistle::Error
    raise 'Closed reader crossed Native' unless Thistle::Native.calls.length == before
  end
  puts 'PASS model_neighborhood forwarding/defaults/closed-reader (Native double only)'
end
