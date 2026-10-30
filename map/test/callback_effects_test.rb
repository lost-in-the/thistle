# frozen_string_literal: true
require_relative 'test_helper'
require 'open3'
require 'rbconfig'
require_relative '../../test/fixtures/callbacks/booted_app'

class ThistleCallbackEffectsMapTest < Minitest::Test
  def test_real_observer_native_capture_fresh_consumer_and_view_after_current_advances
    app = CallbackFixture.boot
    root = File.expand_path('../../test/fixtures/callbacks', __dir__)
    Dir.mktmpdir('thistle-effects-map-') do |store|
      saved = Thistle.capture(root: root, output: store, rails: app)
      current = Thistle.capture(root: root, output: store)
      refute_equal saved.fetch('generation'), current.fetch('generation')
      code = <<~'RUBY'
        require 'thistle/map'; require 'json'
        raise 'fresh consumer loaded Rails' if defined?(Rails) || defined?(ActiveRecord)
        reader = Thistle::Reader.new(ARGV[0], generation: ARGV[1])
        begin
          child = reader.facts.find { |f| f['kind'] == 'rails_save_callbacks' && f['name'] == 'CallbackFixture::Child' }
          explanation = reader.callback_effects(child.fetch('id'))
          html = Thistle::Map::View.new(reader: reader, mount: '/map', params: { 'id' => child.fetch('id') }).source
          puts JSON.generate('explanation' => explanation, 'html' => html, 'source' => reader.source_file('records.rb'))
        ensure
          reader.close
        end
      RUBY
      output, error, status = Open3.capture3(RbConfig.ruby, '-e', code, store, saved.fetch('generation'))
      assert status.success?, error
      result = JSON.parse(output)
      explanation = result.fetch('explanation')
      stamp = explanation.fetch('callbacks').find { |row| row.dig('filter', 'name') == 'parent_stamp' }
      assert_equal true, stamp.fetch('inherited')
      assert_equal 'CallbackFixture::Child', stamp.dig('explanation', 'method', 'owner')
      assert_equal 'CallbackFixture::DeliveryJob.perform_later', stamp.dig('explanation', 'effects', 0, 'operation')
      assert_equal 'unknown', stamp.dig('explanation', 'coherence')
      assert explanation.fetch('callbacks').any? { |row| row.dig('explanation', 'status') == 'unknown' }
      assert_equal saved.fetch('generation'), result.dig('source', 'generation')
      assert_equal Digest::SHA256.hexdigest(result.dig('source', 'content')), stamp.dig('explanation', 'source', 'sha256')
      html = result.fetch('html')
      assert_includes html, 'Potential save callback effects'
      assert_includes html, 'CallbackFixture::DeliveryJob.perform_later'
      assert_includes html, 'No observed enqueue'
      assert_includes html, "generation=#{saved.fetch('generation')}"
      assert_includes html, "file=#{Digest::SHA256.hexdigest('records.rb')}"
    end
  end
end
