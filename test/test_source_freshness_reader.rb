# frozen_string_literal: true

# Direct, native-free adapter contract. Run directly with ruby;
# this file deliberately does not use test_helper or require thistle.
ENV['MT_NO_PLUGINS'] = '1' if $PROGRAM_NAME == __FILE__
require 'minitest/autorun'

if $PROGRAM_NAME != __FILE__
  require 'open3'
  require 'rbconfig'
  class SourceFreshnessIsolatedDoubleTest < Minitest::Test
    def test_native_free_adapter_in_its_own_process
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, File.expand_path(__FILE__))
      assert status.success?, stdout + stderr
    end
  end
else
raise 'Run this double test in a fresh native-free process' if defined?(Thistle::Native) || defined?(Rails) || defined?(ActiveRecord)
module Thistle
  class Error < StandardError; end
  module Native
    class << self
      attr_accessor :calls
      def path(value) = value
      def call(request)
        self.calls ||= []
        calls << request
        case request.fetch('op')
        when 'open' then { 'handle' => 7, 'generation' => 'a' * 64, 'manifest' => { 'files' => [] } }
        when 'close' then { 'closed' => true }
        else { 'double' => request }
        end
      end
    end
  end
end
# Satisfy only reader.rb's require_relative native, without loading extension.
$LOADED_FEATURES << File.expand_path('../lib/thistle/native.rb', __dir__)
require_relative '../lib/thistle/reader'

class SourceFreshnessReaderDoubleTest < Minitest::Test
  def setup
    Thistle::Native.calls = []
    @reader = Thistle::Reader.new('double-store')
  end

  def teardown
    @reader.close
    refute defined?(Rails)
    refute defined?(ActiveRecord)
    refute $LOADED_FEATURES.any? { |path| path.match?(%r{(?:thistle_native\.(?:so|bundle)|/(?:rails|active_record)(?:/|\.rb))}) }
  end

  def test_nil_root_default_and_unmodified_relative_root_cross_once
    result = @reader.source_freshness('sub/source.rb')
    assert_equal({ 'op' => 'source_freshness', 'handle' => 7, 'file_path' => 'sub/source.rb',
      'workspace_root' => nil, 'max_bytes' => 2_097_152 }, result.fetch('double'))
    before = Thistle::Native.calls.length
    @reader.source_freshness('sub/source.rb', workspace_root: '../must-not-expand', max_bytes: 0)
    assert_equal before + 1, Thistle::Native.calls.length
    assert_equal '../must-not-expand', Thistle::Native.calls.last.fetch('workspace_root')
    assert_equal 0, Thistle::Native.calls.last.fetch('max_bytes')
  end

  def test_existing_source_check_and_lifetime_contract_stay_unchanged
    assert_equal 'source_file', @reader.source_file('sub/source.rb').dig('double', 'op')
    assert_equal({ 'op' => 'check', 'handle' => 7 }, @reader.check.fetch('double'))
    @reader.close
    before = Thistle::Native.calls.length
    assert_raises(Thistle::Error) { @reader.source_freshness('sub/source.rb', workspace_root: '/explicit') }
    assert_equal before, Thistle::Native.calls.length
  end
end

end
