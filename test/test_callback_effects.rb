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
  SOURCE = <<~'RUBY'
    module Example
      class Record
        def deliver
          DeliveryJob.perform_later('<script>') if allowed?
          raise 'body must not execute'
          DeliveryJob.perform_later('second representative omitted')
        end
        def quiet = raise('not executed')
        def self.deliver = DeliveryJob.perform_later
        def heredoc; puts <<~TEXT; end
          #{DeliveryJob.perform_later}
        TEXT
        def other_call = Dangerous.delete_all
        def similarly_named = DeliveryJob.perform_later!
        def safe = DeliveryJob&.perform_later
        def setter; Dangerous.perform_later = 1; end
      end
    end
  RUBY

  def with_saved(padding: 0)
    Dir.mktmpdir('thistle-effects-') do |dir|
      root, store = File.join(dir, 'source'), File.join(dir, 'store')
      FileUtils.mkdir_p(root)
      File.write(File.join(root, 'records.rb'), SOURCE)
      capture = Thistle::Capture.new(root: root).call
      observation = { 'version' => 1, 'active_record_version' => '8.1.4', 'root' => root, 'status' => 'observed', 'models' => [
        { 'name' => 'Example::Child', 'superclass' => 'Example::Record', 'save' => { 'status' => 'observed', 'entries' => [
          { 'kind' => 'before', 'filter' => { 'kind' => 'method', 'owner' => 'Example::Record', 'name' => 'deliver',
            'source' => { 'path' => File.join(root, 'records.rb'), 'line' => 3 } },
            'if' => [{ 'kind' => 'method', 'owner' => 'Example::Record', 'name' => 'allowed?', 'source' => nil }], 'unless' => [], 'inherited' => true },
          { 'kind' => 'after', 'filter' => { 'kind' => 'opaque' }, 'if' => [], 'unless' => [], 'inherited' => false }
        ] } }
      ] }
      batch = Thistle::Native.call('op' => 'callback_batch', 'observation' => observation,
        'context' => { 'limits' => { 'max_facts' => 1000, 'max_links' => 1000, 'max_entries' => 100000, 'max_diagnostics' => 100 }, 'facts' => 0, 'links' => 0, 'diagnostics' => 0, 'fact_bytes' => 2 })
      capture.fetch('facts').concat(batch.fetch('facts'))
      padding.times do |i|
        capture.fetch('facts') << { 'id' => format('%064x', i), 'kind' => 'class', 'name' => "Neutral#{i}",
          'path' => nil, 'location' => nil, 'evidence' => 'static', 'attributes' => {}, 'links' => [] }
      end
      manifest = Thistle::Store.new(store).publish(capture)
      yield root, store, manifest.fetch('generation'), batch.fetch('facts').first.fetch('id'), capture
    end
  end

  def with_reader(store, generation)
    reader = Thistle::Reader.new(store, generation: generation)
    begin
      yield reader
    ensure
      reader.close
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
      assert_equal 'Example::Child', result.fetch('model')
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
        assert_raises(Thistle::InvalidInput) { reader.callback_effects('Example::Child') }
        assert_raises(Thistle::NotFound) { reader.callback_effects('f' * 64) }
        static = reader.find('Example::Record#deliver').first
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
  def test_beyond_boundary_public_store_fresh_consumer_reuse_reopen_and_opposite_end_duplicate
    with_saved(padding: 20_050) do |root, store, generation, id, capture|
      expected_id = '0ff347492e45986cc1bd8cc868b5614bd7edc3df71166bc9667de2f134cce519'
      assert_equal '38d4416d4b1c273ebd0335e22f422f8290c4045c637f82990ef05ebf7d426080', Digest::SHA256.hexdigest(SOURCE)
      target = capture.fetch('facts').find { |f| f['id'] == expected_id }
      assert_equal 34, target.dig('location', 'start_byte')
      File.write(File.join(root, 'records.rb'), 'class Changed; end')
      refute_equal generation, Thistle.capture(root: root, output: store).fetch('generation')
      code = <<~'RUBY'
        require 'json'; require 'thistle'
        raise 'Rails loaded' if defined?(Rails) || defined?(ActiveRecord)
        readers = 2.times.map { Thistle::Reader.new(ARGV[0], generation: ARGV[1]) }
        begin
          first = readers[0].callback_effects(ARGV[2])
          again = readers[0].callback_effects(ARGV[2])
          fresh = readers[1].callback_effects(ARGV[2])
          ordinal = readers[0].facts.index { |f| f['id'] == ARGV[3] }
          puts JSON.generate(ordinal: ordinal, first: first, again: again, fresh: fresh,
            source: readers[0].source(ARGV[3]))
        ensure
          readers.each(&:close)
        end
      RUBY
      out, err, status = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../lib', __dir__), '-e', code, store, generation, id, expected_id)
      assert status.success?, err
      saved = JSON.parse(out)
      assert_operator saved.fetch('ordinal'), :>=, 20_050
      first, again, fresh = saved.values_at('first', 'again', 'fresh')
      assert_equal generation, first.fetch('generation')
      assert_equal expected_id, first.dig('callbacks', 0, 'explanation', 'method', 'id')
      assert_equal 'Example::Child', first.fetch('model')
      effect = first.dig('callbacks', 0, 'explanation', 'effects', 0)
      assert_equal 'DeliveryJob.perform_later', effect.fetch('operation')
      assert_equal({ 'start_byte' => 52, 'end_byte' => 89, 'start_line' => 4, 'end_line' => 4 }, effect.fetch('call_span'))
      assert_equal({ 'start_byte' => 52, 'end_byte' => 63, 'start_line' => 4, 'end_line' => 4 }, effect.fetch('receiver_span'))
      assert_equal SOURCE, saved.dig('source', 'content')
      assert_equal true, first.dig('coverage', 'method_directory', 'built_this_request')
      assert_equal false, again.dig('coverage', 'method_directory', 'built_this_request')
      assert_equal true, fresh.dig('coverage', 'method_directory', 'built_this_request')
      assert_equal first.fetch('callbacks'), fresh.fetch('callbacks')
      assert_equal first.fetch('callbacks'), again.fetch('callbacks')
      assert_equal true, first.dig('coverage', 'declaration_scan_complete')
      assert_equal true, first.dig('coverage', 'capture_partial_or_unknown')
      assert_equal capture.fetch('facts').size, first.dig('coverage', 'method_directory', 'facts_visited')
      assert_operator first.dig('coverage', 'facts_visited'), :<, 20_000
      warn 'CALLBACK_EFFECTS_PUBLIC_WHOLE ' + JSON.generate(ordinal: saved.fetch('ordinal'), reader_opens: 2, queries: 3,
        first: first.fetch('coverage'), reuse: again.fetch('coverage'), reopen: fresh.fetch('coverage'))
      duplicate = Marshal.load(Marshal.dump(target))
      duplicate['id'] = 'f' * 64
      duplicate['location'] = nil
      duplicate['attributes']['name_resolution'] = 'unresolved_receiver'
      capture.fetch('facts') << duplicate
      duplicate_generation = Thistle::Store.new(store).publish(capture).fetch('generation')
      with_reader(store, duplicate_generation) do |reader|
        result = reader.callback_effects(id)
        assert_equal 'ambiguous_duplicate_instance_declarations', result.dig('callbacks', 0, 'explanation', 'reason')
        assert_empty result.dig('callbacks', 0, 'explanation', 'effects')
        assert_equal false, result.dig('coverage', 'candidate_ranges_complete')
      end
    end
  end

  def test_absent_partial_empty_opaque_and_integrity_stay_distinct_after_complete_lookup
    with_saved do |_root, store, _generation, id, capture|
      registry = capture.fetch('facts').find { |f| f['id'] == id }
      save = registry.dig('attributes', 'callbacks', 'save')
      save['status'] = 'partial'
      save.fetch('entries')[0].fetch('filter')['name'] = 'missing_method'
      generation = Thistle::Store.new(store).publish(capture).fetch('generation')
      with_reader(store, generation) do |reader|
        result = reader.callback_effects(id)
        assert_equal 'partial', result.fetch('registry_status')
        assert_equal 'captured_declaration_unavailable', result.dig('callbacks', 0, 'explanation', 'reason')
        assert_equal 'opaque_or_incomplete_observed_method_descriptor', result.dig('callbacks', 1, 'explanation', 'reason')
        assert_equal true, result.dig('coverage', 'declaration_scan_complete')
        assert_equal 2, result.dig('coverage', 'source_rows_not_searched')
      end
      save['entries'] = []
      generation = Thistle::Store.new(store).publish(capture).fetch('generation')
      with_reader(store, generation) do |reader|
        result = reader.callback_effects(id)
        assert_empty result.fetch('callbacks')
        assert_equal 'not_requested', result.dig('coverage', 'method_directory', 'status')
        assert_match(/does not establish/, result.dig('coverage', 'absence'))
      end
    end
    with_saved do |_root, store, generation, id, capture|
      blob = File.join(store, 'blobs', capture.fetch('files').first.fetch('sha256'))
      with_reader(store, generation) do |reader|
        original = File.binread(blob)
        File.unlink(blob)
        assert_equal 'saved_source_blob_missing', reader.callback_effects(id).dig('callbacks', 0, 'explanation', 'reason')
        File.binwrite(blob, original)
        assert_equal 'supported_potential', reader.callback_effects(id).dig('callbacks', 0, 'explanation', 'status')
        File.binwrite(blob, 'corrupt')
        assert_raises(Thistle::InvalidSnapshot) { reader.callback_effects(id) }
      end
    end
  end

end
