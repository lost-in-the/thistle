# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'rbconfig'

# Stub the extension load and raw JSON boundary, never load native code.
class JobMailBusyTest < Minitest::Test
  def test_native_busy_is_typed_and_other_codes_keep_their_mapping
    script = <<~'RUBY'
      require 'json'
      $LOADED_FEATURES << 'thistle/thistle_native.rb'
      require File.join(ARGV.fetch(0), 'lib/thistle/native')
      module Thistle::Native
        def self.request_raw(payload)
          JSON.generate('ok' => false, 'error' => { 'code' => JSON.parse(payload).fetch('fixture_code'), 'message' => 'fixture refusal' })
        end
      end
      { 'busy' => Thistle::Busy, 'not_found' => Thistle::NotFound, 'future_error' => Thistle::Error }.each do |code, klass|
        begin
          Thistle::Native.call('fixture_code' => code)
          raise 'Refusal disappeared'
        rescue Thistle::Error => error
          raise 'Wrong mapped class/code/message' unless error.instance_of?(klass) && error.code == code && error.message == 'fixture refusal'
        end
      end
      raise 'Native loaded' if $LOADED_FEATURES.any? { |p| p.end_with?('.so', '.bundle') && p.include?('thistle_native') }
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, '-e', script, File.expand_path('..', __dir__))
    assert status.success?, out + err
  end
end
