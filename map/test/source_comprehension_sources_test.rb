# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/source_comprehension_sources'

class SourceComprehensionSourcesTest < Minitest::Test
  Admission = Thistle::Map::SourceComprehensionSources
  G = 'a' * 64

  class Reader
    attr_reader :generation, :manifest, :calls
    def initialize(files, responses)
      @generation, @manifest, @responses, @calls = G, { 'files' => files }, responses, []
    end
    def source(id)
      @calls << id
      value = @responses.fetch(id)
      raise value if value.is_a?(Exception)
      value
    end
  end

  def evidence(id = 'b' * 64, path: 'order.rb', content: "class Order\nend\n")
    fact = { 'id' => id, 'path' => path, 'location' => { 'start_line' => 1, 'end_line' => 2 } }
    sha = Digest::SHA256.hexdigest(content)
    [{ 'fact' => fact }, { 'path' => path, 'bytes' => content.bytesize, 'sha256' => sha },
      { 'generation' => G, 'fact' => fact, 'content' => content, 'sha256' => sha }]
  end

  def test_admits_declared_bounds_before_one_deduplicated_reader_read
    row, file, response = evidence
    other = Marshal.load(Marshal.dump(row)); other['fact']['id'] = 'c' * 64
    reader = Reader.new([file], { row['fact']['id'] => response })
    result = Admission.new(reader: reader, generation: G).call([row, other])
    assert_equal ['b' * 64], reader.calls
    assert_equal 'admitted', result.states['b' * 64]['status']
    assert_equal 'shared_file', result.states['c' * 64]['status']
    assert_same response, result.sources['b' * 64]
  end

  def test_aggregate_byte_reservations_refuse_before_source
    first, first_file, response = evidence(content: 'x' * 65_000)
    second, second_file, = evidence('c' * 64, path: 'parent.rb', content: 'y' * 537)
    reader = Reader.new([first_file, second_file], { 'b' * 64 => response })
    result = Admission.new(reader: reader, generation: G).call([first, second])
    assert_equal ['b' * 64], reader.calls
    assert_equal 'not_admitted', result.states['c' * 64]['status']
    row, file, = evidence(content: 'x' * 65_537)
    reader = Reader.new([file], {})
    result = Admission.new(reader: reader, generation: G).call([row])
    assert_empty reader.calls
    assert_equal 'not_admitted', result.states['b' * 64]['status']
  end

  def test_modest_files_over_two_kib_are_read_and_over_line_files_are_wholly_omitted
    row, file, response = evidence(content: "# #{'x' * 4096}\nclass Order\nend\n")
    reader = Reader.new([file], { 'b' * 64 => response })
    result = Admission.new(reader: reader, generation: G).call([row])
    assert_equal ['b' * 64], reader.calls
    assert_equal 'admitted', result.states['b' * 64]['status']
    row, file, response = evidence(content: "x\n" * 2001)
    other = Marshal.load(Marshal.dump(row)); other['fact']['id'] = 'c' * 64
    reader = Reader.new([file], { 'b' * 64 => response })
    result = Admission.new(reader: reader, generation: G).call([row, other])
    assert_equal ['b' * 64], reader.calls
    assert_empty result.sources
    assert_equal 'not_admitted', result.states['b' * 64]['status']
    assert_equal 'not_admitted', result.states['c' * 64]['status']
  end

  def test_remaining_display_lines_are_checked_after_each_bounded_read
    row, file, response = evidence(content: "x\n" * 1500)
    other, other_file, other_response = evidence('c' * 64, path: 'parent.rb', content: "y\n" * 501)
    reader = Reader.new([file, other_file], { 'b' * 64 => response, 'c' * 64 => other_response })
    result = Admission.new(reader: reader, generation: G).call([row, other])
    assert_equal ['b' * 64, 'c' * 64], reader.calls
    assert_equal ['b' * 64], result.sources.keys
    assert_equal 'not_admitted', result.states['c' * 64]['status']
  end

  def test_over_line_rejection_keeps_byte_reservation_and_spent_lines_stop_reads
    row, file, response = evidence(content: "x\n" * 2001)
    other, other_file, = evidence('c' * 64, path: 'parent.rb', content: 'y' * 61_535)
    reader = Reader.new([file, other_file], { 'b' * 64 => response })
    result = Admission.new(reader: reader, generation: G).call([row, other])
    assert_equal ['b' * 64], reader.calls
    assert_empty result.sources
    assert_equal 'not_admitted', result.states['c' * 64]['status']
    row, file, response = evidence(content: "x\n" * 2000)
    other, other_file, = evidence('c' * 64, path: 'parent.rb', content: 'short')
    reader = Reader.new([file, other_file], { 'b' * 64 => response })
    result = Admission.new(reader: reader, generation: G).call([row, other])
    assert_equal ['b' * 64], reader.calls
    assert_equal 'admitted', result.states['b' * 64]['status']
    assert_equal 'not_admitted', result.states['c' * 64]['status']
  end

  def test_unavailable_is_distinct_from_not_admitted_and_absent_manifest_is_invalid
    row, file, = evidence
    missing = { 'fact' => { 'id' => 'c' * 64, 'path' => nil, 'location' => nil } }
    reader = Reader.new([], {})
    result = Admission.new(reader: reader, generation: G).call([missing])
    assert_equal 'unavailable', result.states['c' * 64]['status']
    assert_empty reader.calls
    assert_raises(Thistle::InvalidSnapshot) { Admission.new(reader: reader, generation: G).call([row]) }
    assert_empty reader.calls
  end

  def test_digest_generation_and_declared_size_mismatch_fail_without_retry
    %w[generation sha256 content].each do |field|
      row, file, response = evidence
      response[field] = 'mismatch'
      reader = Reader.new([file], { 'b' * 64 => response })
      assert_raises(Thistle::InvalidSnapshot) { Admission.new(reader: reader, generation: G).call([row]) }
      assert_equal ['b' * 64], reader.calls
    end
  end

  def test_reader_budget_refusal_retains_reservation_and_deduplication
    row, file, = evidence
    other = Marshal.load(Marshal.dump(row)); other['fact']['id'] = 'c' * 64
    reader = Reader.new([file], { 'b' * 64 => Thistle::LimitExceeded.new('refused') })
    result = Admission.new(reader: reader, generation: G).call([row, other])
    assert_equal ['b' * 64], reader.calls
    assert_equal 'not_admitted', result.states['b' * 64]['status']
    assert_equal 'not_admitted', result.states['c' * 64]['status']
  end
end
