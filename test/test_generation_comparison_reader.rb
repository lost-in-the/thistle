# frozen_string_literal: true

# AUTHORED UNRUN until Root owns/adopts the proposed facade and native wiring.
# This doubles Native transport only; it loads the real Reader implementation
# and never supplies a substitute Reader or comparison implementation.
ENV['MT_NO_PLUGINS'] = '1' if $PROGRAM_NAME == __FILE__
require 'minitest/autorun'

if $PROGRAM_NAME != __FILE__
  require 'open3'
  require 'rbconfig'
  class GenerationComparisonIsolatedDoubleTest < Minitest::Test
    def test_real_reader_forwarding_in_its_own_process
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, File.expand_path(__FILE__))
      assert status.success?, stdout + stderr
    end
  end
else
  raise 'Use a fresh native-free process' if defined?(Thistle::Native) || defined?(Rails) || defined?(ActiveRecord)
  module Thistle
    class Error < StandardError; end
    module Native
      class << self
        attr_accessor :calls, :next_handle, :fail_next
        def path(value) = value
        def call(request)
          self.calls ||= []
          calls << request
          if fail_next
            self.fail_next = false
            raise Thistle::Error, 'native pair refused'
          end
          case request.fetch('op')
          when 'open'
            self.next_handle = (next_handle || 0) + 1
            { 'handle' => next_handle, 'generation' => next_handle.to_s * 64, 'manifest' => {} }
          when 'close' then { 'closed' => true }
          else { 'double' => request }
          end
        end
      end
    end
  end
  $LOADED_FEATURES << File.expand_path('../lib/thistle/native.rb', __dir__)
  require_relative '../lib/thistle/reader'

  class GenerationComparisonReaderDoubleTest < Minitest::Test
    def setup
      Thistle::Native.calls = []
      Thistle::Native.next_handle = 0
      @left = Thistle::Reader.new('public-left', generation: 'a' * 64)
      @right = Thistle::Reader.new('public-right', generation: 'b' * 64)
      @selection = { 'kind' => 'class', 'name' => 'Shop::Order' }
    end

    def teardown
      @left.close
      @right.close
      refute defined?(Rails)
      refute defined?(ActiveRecord)
      refute $LOADED_FEATURES.any? { |p| p.match?(%r{thistle_native\.(?:so|bundle)|/(?:rails|active_record)(?:/|\.rb)}) }
    end

    def test_two_handles_cross_once_without_ruby_selection_or_store_reopen
      before = Thistle::Native.calls.length
      out = @left.generation_comparison(@right, selection: @selection)
      assert_equal before + 1, Thistle::Native.calls.length
      assert_equal({ 'op' => 'generation_comparison', 'handle' => 1, 'other_handle' => 2,
        'selection' => @selection, 'family' => 'entity', 'direction' => 'incoming',
        'limit' => 8, 'max_bytes' => 32768, 'cursor' => nil }, out.fetch('double'))
      @left.generation_comparison(@right, selection: @selection, family: 'references', direction: 'outgoing',
        limit: 1, max_bytes: 4096, cursor: 'opaque-paired-cursor')
      assert_equal 'opaque-paired-cursor', Thistle::Native.calls.last.fetch('cursor')
    end

    def test_either_closed_handle_and_wrong_type_refuse_before_transport
      @right.close
      before = Thistle::Native.calls.length
      assert_raises(Thistle::Error) { @left.generation_comparison(@right, selection: @selection) }
      assert_equal before, Thistle::Native.calls.length
      assert_raises(Thistle::Error) { @left.generation_comparison('store path is not a Reader', selection: @selection) }
      assert_equal before, Thistle::Native.calls.length
      @left.close
      before = Thistle::Native.calls.length
      assert_raises(Thistle::Error) { @left.generation_comparison(@right, selection: @selection) }
      assert_equal before, Thistle::Native.calls.length
    end

    def test_native_error_never_closes_or_reopens_either_borrowed_reader
      Thistle::Native.fail_next = true
      assert_raises(Thistle::Error) { @left.generation_comparison(@right, selection: @selection) }
      assert_equal 'generation_comparison', Thistle::Native.calls.last.fetch('op')
      assert_equal 'fact_identity', @left.fact_identity('c' * 64).dig('double', 'op')
      assert_equal 'fact_identity', @right.fact_identity('d' * 64).dig('double', 'op')
    end
  end
end
