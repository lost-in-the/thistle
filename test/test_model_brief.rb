# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'json'
require 'open3'
require 'rbconfig'
require 'rubygems'
require 'stringio'
require 'thistle'
require 'thistle/cli'

class ThistleModelBriefTest < Minitest::Test
  FIXTURE = File.expand_path('fixtures/model_brief', __dir__)
  SOURCE = File.binread(File.join(FIXTURE, 'records.rb')).freeze
  LIB = File.expand_path('../lib', __dir__)
  source_cli = File.expand_path('../exe/thistle', __dir__)
  BIN = File.file?(source_cli) ? source_cli : Gem.bin_path('thistle', 'thistle')
  NAME = 'BriefFixture::Order'

  # One real Rails producer in another process. The parent and every consumer
  # stay Rails-free; CURRENT advances before either Reader or CLI consumption.
  def self.saved
    return @saved if @saved
    @directory = Dir.mktmpdir('thistle-model-brief-')
    root, store = %w[source store].map { |n| File.join(@directory, n) }
    FileUtils.mkdir_p(root)
    FileUtils.cp(File.join(FIXTURE, 'records.rb'), root)
    producer = <<~'RUBY'
      require 'json'; require 'thistle'
      require ARGV[0]
      app = BriefFixture.boot(ARGV[1])
      first = Thistle.capture(root: ARGV[1], output: ARGV[2], rails: app)
      File.write(File.join(ARGV[1], 'records.rb'), 'class CurrentReplacement; end')
      second = Thistle.capture(root: ARGV[1], output: ARGV[2])
      puts JSON.generate(generation: first.fetch('generation'), newer: second.fetch('generation'))
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, '-I', LIB, '-e', producer, File.join(FIXTURE, 'booted_app.rb'), root, store)
    raise "Producer failed: #{err}" unless status.success?
    receipt = JSON.parse(out.lines.last)
    @saved = [store, receipt.fetch('generation'), receipt.fetch('newer')]
  end

  Minitest.after_run { FileUtils.remove_entry(@directory) if @directory && File.directory?(@directory) }

  def with_reader
    store, generation, = self.class.saved
    reader = Thistle::Reader.new(store, generation: generation)
    begin
      root = reader.find(NAME).find { |f| f['kind'] == 'rails_model' && f['name'] == NAME }
      refute_nil root
      # Independently recompute the documented identity from the saved ordinal.
      expected = Digest::SHA256.hexdigest(JSON.generate(['rails_model', 1, root.dig('attributes', 'model', 'ordinal'), NAME]))
      assert_equal expected, root.fetch('id')
      yield reader, expected
    ensure
      reader.close
    end
  end

  def cli(*arguments)
    Open3.capture3(RbConfig.ruby, '-I', LIB, BIN, *arguments)
  end

  def test_real_producer_find_brief_then_source_links_in_fresh_consumer_after_current_changes
    store, generation, newer = self.class.saved
    refute_equal generation, newer
    consumer = <<~'RUBY'
      require 'json'; require 'thistle'
      raise 'Rails loaded' if defined?(Rails) || defined?(ActiveRecord)
      r = Thistle::Reader.new(ARGV[0], generation: ARGV[1])
      begin
        root = r.find('BriefFixture::Order').find { |f| f['kind'] == 'rails_model' && f['name'] == 'BriefFixture::Order' }
        brief = r.model_brief(root.fetch('id'))
        callback = brief.dig('families', 'callbacks', 'items').find { |c| c.dig('filter', 'name') == 'deliver' }
        method_id = callback.dig('explanation', 'method', 'id')
        puts JSON.generate(brief: brief, root: root, source: r.source(method_id), links: r.links(method_id))
      ensure
        r.close
      end
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, '-I', LIB, '-e', consumer, store, generation)
    assert status.success?, err
    saved = JSON.parse(out)
    brief = saved.fetch('brief')
    id = Digest::SHA256.hexdigest(JSON.generate(['rails_model', 1, saved.dig('root', 'attributes', 'model', 'ordinal'), NAME]))
    assert_equal id, brief.dig('root', 'id')
    assert_equal generation, brief.fetch('generation')
    assert_equal generation, saved.dig('source', 'generation')
    assert_equal SOURCE, saved.dig('source', 'content').b
    assert_equal Digest::SHA256.hexdigest(SOURCE), saved.dig('source', 'sha256')
    fields = brief.dig('families', 'columns', 'items')
    assert_includes fields, { 'name' => 'state', 'type' => 'string', 'null' => false }
    assert_includes fields, { 'name' => 'note_雪', 'type' => 'string', 'null' => true }
    assert_equal({ 'name' => 'items', 'macro' => 'has_many', 'target' => 'BriefFixture::Item', 'polymorphic' => false, 'status' => 'recorded_label_binding_unknown' }, brief.dig('families', 'associations', 'items', 0))
    brief.fetch('families').each_value { |f| assert_equal generation, f.fetch('generation') }
    registry = brief.dig('families', 'registry_candidates')
    assert_equal 'unique_label_candidate', registry.fetch('status')
    assert_equal 'unknown', registry.fetch('model_registry_binding')
    callbacks = brief.dig('families', 'callbacks')
    assert_equal NAME, callbacks.fetch('observed_model_label')
    callback = callbacks.fetch('items').find { |c| c.dig('filter', 'name') == 'deliver' }
    assert_equal 'BriefFixture::Parent', callback.dig('filter', 'owner')
    assert_equal true, callback.fetch('inherited')
    assert_equal 'registered_metadata', callback.fetch('registry_provenance')
    explanation = callback.fetch('explanation')
    assert_equal 'BriefFixture::Parent', explanation.dig('method', 'owner')
    expected_method = Digest::SHA256.hexdigest(JSON.generate(['ruby', 'method', 'BriefFixture::Parent#deliver', 'records.rb', SOURCE.index('def deliver'.b)]))
    assert_equal expected_method, explanation.dig('method', 'id')
    assert_equal expected_method, saved.dig('source', 'fact', 'id')
    assert_equal Digest::SHA256.hexdigest(SOURCE), explanation.dig('source', 'sha256')
    effect = explanation.fetch('effects').first
    assert_equal 'captured_source_potential', effect.fetch('provenance')
    assert_equal 'BriefFixture::DeliveryJob', effect.fetch('receiver')
    assert_equal 'perform_later', effect.fetch('selector')
    span = effect.fetch('call_span')
    expected_call = 'BriefFixture::DeliveryJob.perform_later("雪\n\"quoted\"")'
    expected_start = SOURCE.index(expected_call.b)
    assert_equal expected_start, span.fetch('start_byte')
    assert_equal expected_start + expected_call.bytesize, span.fetch('end_byte')
    assert_equal 10, span.fetch('start_line')
    assert_equal expected_call.b, SOURCE.byteslice(span.fetch('start_byte')...span.fetch('end_byte'))
    assert callbacks.fetch('items').any? { |c| c.dig('explanation', 'reason') == 'opaque_or_incomplete_observed_method_descriptor' }
    assert saved.fetch('links').any? { |l| l['relation'] == 'calls' && l['target'] == 'perform_later' }
    incoming = brief.dig('families', 'incoming', 'items')
    assert incoming.any? { |row| row.dig('origin', 'name') == 'BriefFixture::Item' && row.dig('link', 'relation') == 'association_target_label' }
    incoming.each { |row| assert_equal false, row.fetch('candidate_search_complete'); refute row.fetch('origin').key?('attributes') }
    assert brief.dig('families', 'outgoing', 'items').any? { |row| row.dig('link', 'target') == 'BriefFixture::Item' }
    assert_equal true, brief.dig('coverage', 'capture_partial_or_unknown')
    assert_equal true, brief.dig('cost', 'method_directory', 'built_this_request')
  end

  def test_actual_cli_wire_budget_escaping_omissions_and_strict_generation
    with_reader do |reader, id|
      store, generation, = self.class.saved
      out, err, status = cli('model-brief', id, '--store', store, '--generation', generation)
      assert status.success?, err
      result = JSON.parse(out)
      assert_equal out.bytesize, result.dig('usage', 'wire_bytes_including_newline')
      assert_operator out.bytesize, :<=, 32768
      assert_includes out, '雪'
      assert_includes out, '\\n'
      tight_limit = out.bytesize - 1
      tight, err, status = cli('model-brief', id, '--store', store, '--generation', generation, '--max-bytes', tight_limit.to_s)
      assert status.success?, err
      tight_brief = JSON.parse(tight)
      assert_equal tight.bytesize, tight_brief.dig('usage', 'wire_bytes_including_newline')
      assert_operator tight.bytesize, :<=, tight_limit
      assert_operator tight_brief.dig('usage', 'returned_items'), :<, result.dig('usage', 'returned_items')
      removed = result.dig('usage', 'returned_items') - tight_brief.dig('usage', 'returned_items')
      assert_equal removed, tight_brief.fetch('families').sum { |name, f| f.fetch('known_omitted') - result.dig('families', name, 'known_omitted') }

      small, err, status = cli('model-brief', id, '--store', store, '--generation', generation, '--limit', '1', '--max-bytes', '16000')
      assert status.success?, err
      brief = JSON.parse(small)
      assert_equal small.bytesize, brief.dig('usage', 'wire_bytes_including_newline')
      assert_operator small.bytesize, :<=, 16000
      assert_equal 2, brief.dig('families', 'columns', 'known_omitted')
      brief.fetch('families').each_value { |f| assert_operator f.fetch('items').size, :<=, 1 }
      refute_equal brief.dig('families', 'callbacks', 'status'), 'unavailable'
      out, err, status = cli('model-brief', id, '--store', '/does/not/exist')
      assert_equal 2, status.exitstatus
      assert_empty out
      assert_match(/requires --generation/, JSON.parse(err).dig('error', 'message'))
      out, err, status = cli('model-brief', id, '--store', store, '--generation', generation, '--max-bytes', '1')
      refute status.success?
      assert_empty out
      assert_equal 'limit_exceeded', JSON.parse(err).dig('error', 'code')
      out, err, status = cli('model-brief', id, '--store', store, '--generation', 'f' * 64)
      refute status.success?
      assert_empty out
      assert_equal 'not_found', JSON.parse(err).dig('error', 'code')
      assert_raises(Thistle::InvalidInput) { reader.model_brief(id, limit: 17) }
      assert_raises(Thistle::InvalidInput) { reader.model_brief(id, max_bytes: 65537) }
    end
  end

  def test_errors_missing_registry_ambiguity_reuse_and_corrupt_source
    with_reader do |reader, id|
      assert_raises(Thistle::InvalidInput) { reader.model_brief(NAME) }
      assert_raises(Thistle::NotFound) { reader.model_brief('f' * 64) }
      method = reader.find('BriefFixture::Parent#deliver').find { |f| f['kind'] == 'method' }
      assert_raises(Thistle::InvalidInput) { reader.model_brief(method.fetch('id')) }
      first, second = reader.model_brief(id), reader.model_brief(id)
      evidence = ->(brief) { brief.fetch('families').transform_values { |family| family.reject { |key, _| key == 'work' } } }
      assert_equal evidence.call(first), evidence.call(second)
      assert_equal false, second.dig('cost', 'method_directory', 'built_this_request')
      store, = self.class.saved
      file = reader.manifest.fetch('files').find { |f| f['path'] == 'records.rb' }
      blob = File.join(store, 'blobs', file.fetch('sha256'))
      original = File.binread(blob)
      begin
        File.binwrite(blob, 'corrupt')
        assert_raises(Thistle::InvalidSnapshot) { reader.model_brief(id) }
      ensure
        File.binwrite(blob, original)
      end
      reader.close
      assert_raises(Thistle::Error) { reader.model_brief(id) }
    end
  end
end
