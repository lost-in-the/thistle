# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'open3'
require 'rbconfig'
require 'thistle'

# Saved primitive contract: no Rails dependency or unrelated database preflight.
class ThistleCallbackEffectsTest < Minitest::Test
  SOURCE = <<~RUBY
    module Saved
      class Record
        def deliver
          raise 'callback body executed'
          DeliveryJob.perform_later('<script>') if allowed?
        end
        def allowed? = raise('condition executed')
      end
    end
  RUBY

  def with_saved
    Dir.mktmpdir('thistle-effects-') do |dir|
      root, store = File.join(dir, 'source'), File.join(dir, 'store')
      FileUtils.mkdir_p(root)
      File.write(File.join(root, 'records.rb'), SOURCE)
      capture = Thistle::Capture.new(root: root).call
      observation = { 'version' => 1, 'active_record_version' => '8.1.4', 'root' => root, 'status' => 'observed', 'models' => [
        { 'name' => 'Saved::Child', 'superclass' => 'Saved::Record', 'save' => { 'status' => 'observed', 'entries' => [
          { 'kind' => 'before', 'filter' => { 'kind' => 'method', 'owner' => 'Saved::Record', 'name' => 'deliver',
            'source' => { 'path' => File.join(root, 'records.rb'), 'line' => 3 } },
            'if' => [{ 'kind' => 'method', 'owner' => 'Saved::Record', 'name' => 'allowed?', 'source' => nil }], 'unless' => [], 'inherited' => true },
          { 'kind' => 'after', 'filter' => { 'kind' => 'opaque' }, 'if' => [], 'unless' => [], 'inherited' => false }
        ] } }
      ] }
      batch = Thistle::Native.call('op' => 'callback_batch', 'observation' => observation,
        'context' => { 'limits' => { 'max_facts' => 1000, 'max_links' => 1000, 'max_entries' => 100000, 'max_diagnostics' => 100 }, 'facts' => 0, 'links' => 0, 'diagnostics' => 0, 'fact_bytes' => 2 })
      capture.fetch('facts').concat(batch.fetch('facts'))
      manifest = Thistle::Store.new(store).publish(capture)
      yield root, store, manifest.fetch('generation'), batch.fetch('facts').first.fetch('id')
    end
  end

  def test_exact_saved_primitive_spans_fresh_no_rails_consumer_and_pinned_source
    with_saved do |root, store, generation, id|
      File.write(File.join(root, 'records.rb'), 'class Changed; end')
      refute_equal generation, Thistle.capture(root: root, output: store).fetch('generation')
      code = <<~'RUBY'
        require 'json'; require 'thistle'
        raise 'Rails loaded in fresh consumer' if defined?(Rails) || defined?(ActiveRecord)
        reader = Thistle::Reader.new(ARGV[0], generation: ARGV[1])
        begin
          result = reader.callback_effects(ARGV[2])
          effect = result.fetch('callbacks').first.fetch('explanation').fetch('effects').first
          source = reader.source_file('records.rb')
          puts JSON.generate(result: result, source: source, effect: effect)
        ensure
          reader.close
        end
      RUBY
      output, error, status = Open3.capture3(RbConfig.ruby, '-e', code, store, generation, id)
      assert status.success?, error
      saved = JSON.parse(output)
      result, effect = saved.fetch('result'), saved.fetch('effect')
      assert_equal generation, result.fetch('generation')
      assert_equal 'Saved::Child', result.fetch('model')
      assert_equal 'DeliveryJob.perform_later', effect.fetch('operation')
      assert_equal SOURCE, saved.fetch('source').fetch('content')
      span = effect.fetch('call_span')
      assert_equal "DeliveryJob.perform_later('<script>')", SOURCE.byteslice(span.fetch('start_byte')...span.fetch('end_byte'))
      receiver = effect.fetch('receiver_span')
      assert_equal 'DeliveryJob', SOURCE.byteslice(receiver.fetch('start_byte')...receiver.fetch('end_byte'))
      assert_equal Digest::SHA256.hexdigest(SOURCE), result.dig('callbacks', 0, 'explanation', 'source', 'sha256')
      assert_equal 'opaque_or_incomplete_observed_method_descriptor', result.dig('callbacks', 1, 'explanation', 'reason')
      refute result.dig('callbacks', 0, 'if').empty?
    end
  end

  def test_reader_refusals_limits_fork_and_close_keep_native_lifetimes
    with_saved do |_root, store, generation, id|
      reader = Thistle::Reader.new(store, generation: generation)
      begin
        assert_equal 1, reader.callback_effects(id, limit: 1).dig('coverage', 'rows_not_searched')
        assert_raises(Thistle::InvalidInput) { reader.callback_effects(id, limit: 201) }
        assert_raises(Thistle::InvalidInput) { reader.callback_effects('Saved::Child') }
        assert_raises(Thistle::NotFound) { reader.callback_effects('f' * 64) }
        static = reader.find('Saved::Record#deliver').first
        assert_raises(Thistle::InvalidInput) { reader.callback_effects(static.fetch('id')) }
        if Process.respond_to?(:fork)
          pid = fork do
            begin
              reader.callback_effects(id)
              exit! 2
            rescue Thistle::Error => e
              exit!(e.instance_variable_get(:@native_code) == 'forked_process' ? 0 : 3)
            end
          end
          Process.wait(pid)
          assert_predicate $?, :success?
        end
      ensure
        reader.close
      end
      assert_raises(Thistle::Error) { reader.callback_effects(id) }
    end
  end
end
