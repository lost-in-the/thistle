# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../lib/thistle'

class ThistleTaggedEncodingTest < Minitest::Test
  def test_native_accounting_hint_is_strict_context_without_a_sizing_fallback
    facade = Thistle::Capture.new(root: '.')
    valid = { 'schema_version' => 3, 'evidence_accounting' => { 'schema_version' => 3, 'fact_bytes_upper_bound' => 2 } }
    assert_equal 2, facade.send(:native_evidence_bytes, valid)
    bad = [nil, {}, { 'schema_version' => 2, 'fact_bytes_upper_bound' => 2 },
      { 'schema_version' => 3.0, 'fact_bytes_upper_bound' => 2 },
      { 'schema_version' => 3, 'fact_bytes_upper_bound' => 1 },
      { 'schema_version' => 3, 'fact_bytes_upper_bound' => 2.0 },
      { 'schema_version' => 3, 'fact_bytes_upper_bound' => true },
      { 'schema_version' => 3, 'fact_bytes_upper_bound' => 2, 'extra' => 0 }]
    bad.each do |hint|
      assert_raises(Thistle::InvalidInput) { facade.send(:native_evidence_bytes, valid.merge('evidence_accounting' => hint)) }
    end
    assert_raises(Thistle::InvalidInput) { facade.send(:native_evidence_bytes, valid.merge('schema_version' => 3.0)) }
    oversized = { 'schema_version' => 3, 'fact_bytes_upper_bound' => Thistle::Capture::MAX_EVIDENCE_BYTES + 1 }
    assert_raises(Thistle::LimitExceeded) { facade.send(:native_evidence_bytes, valid.merge('evidence_accounting' => oversized)) }
  end

  def test_public_reader_methods_return_semantic_objects_and_old_generation_remains_opaque
    Dir.mktmpdir('thistle-tagged-') do |directory|
      root = File.join(directory, 'input')
      FileUtils.mkdir_p(root)
      content = "class Box; def run(x); x&.call; end; end\n"
      File.write(File.join(root, 'calls.rb'), content)
      data = Thistle::Capture.new(root: root).call
      expected = data.fetch('facts').find { |fact| fact['name'] == 'Box#run' }
      target = expected.fetch('links').first.fetch('target')
      compact = expected.fetch('links').first.fetch('attributes').fetch('thistle_call').fetch('data')
      store_path = File.join(directory, 'store')
      store = Thistle::Store.new(store_path)
      legacy = Marshal.load(Marshal.dump(data))
      legacy['schema_version'] = 1
      opaque_fact = legacy.fetch('facts').find { |fact| fact['id'] == expected['id'] }
      opaque_fact.fetch('links').first['relation'] = 'references'
      opaque_fact.fetch('links').first['resolution'] = 'resolved'
      old = store.publish(legacy)
      assert_equal 1, old.fetch('schema_version')
      legacy['schema_version'] = 2
      assert_raises(Thistle::InvalidInput) { store.publish(legacy) }
      saved = store.publish(data)
      assert_equal 3, saved.fetch('schema_version')
      raw = JSON.parse(File.read(File.join(store_path, 'generations', saved.fetch('generation'), 'facts.json')))
      assert_equal [0, target, compact], raw.find { |fact| fact['id'] == expected['id'] }.fetch('links').first
      reader = old_reader = nil
      begin
        reader = Thistle::Reader.new(store_path)
        assert_equal expected, reader.fact(expected.fetch('id'))
        assert_equal expected, reader.facts.find { |fact| fact['id'] == expected['id'] }
        assert_equal expected, reader.find('Box#run').first
        assert_equal expected, reader.source(expected.fetch('id')).fetch('fact')
        assert_equal expected.fetch('links'), reader.links(expected.fetch('id'))
        assert_equal content, reader.source(expected.fetch('id')).fetch('content')
        assert_equal saved.fetch('generation'), reader.check.fetch('generation')
        old_reader = Thistle::Reader.new(store_path, generation: old.fetch('generation'))
        assert_equal opaque_fact, old_reader.fact(expected.fetch('id'))
        assert_equal content, old_reader.source(expected.fetch('id')).fetch('content')
      ensure
        old_reader&.close
        reader&.close
      end
      # A row is storage input only. Semantic publication may not guess it came
      # from a Reader or trust the otherwise plausible advisory accounting hint.
      invalid = Marshal.load(Marshal.dump(data))
      invalid.fetch('facts').find { |fact| fact['id'] == expected['id'] }['links'] = [[0, target, compact]]
      refused_path = File.join(directory, 'must-not-exist')
      assert_raises(Thistle::InvalidInput) { Thistle::Store.new(refused_path).publish(invalid) }
      refute File.exist?(refused_path)
    end
  end
end
