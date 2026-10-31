# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'stringio'
require_relative 'test_model_brief_markdown'

# Permit a standalone pure/mocked CLI check without loading the native facade.
# Other test files can still require the real facade afterwards in a full suite.
facade = File.expand_path('../lib/thistle.rb', __dir__)
suppress = !$LOADED_FEATURES.include?(facade)
$LOADED_FEATURES << facade if suppress
begin
  require_relative '../lib/thistle/cli'
ensure
  $LOADED_FEATURES.delete(facade) if suppress
end

class ThistleMarkdownExportCLITest < Minitest::Test
  include MarkdownBriefFixture

  def invoke(*options, reader: nil, opening_error: nil, arguments: nil, out: nil)
    @out, @err, @opens = out || StringIO.new, StringIO.new, []
    @reader = reader || FakeReader.new(brief, manifest)
    fake_class = Object.new
    fake_class.define_singleton_method(:new) do |*args, **kwargs|
      @callback.call(args, kwargs)
    end
    callback = lambda do |args, kwargs|
      @opens << [args, kwargs]
      raise opening_error if opening_error
      @reader
    end
    fake_class.instance_variable_set(:@callback, callback)
    original = Thistle.const_get(:Reader) if Thistle.const_defined?(:Reader, false)
    Thistle.send(:remove_const, :Reader) if original
    Thistle.const_set(:Reader, fake_class)
    begin
      Thistle::CLI.new(out: @out, err: @err).run(arguments || ['export-model-brief', MODEL, '--store', '/private/store', '--generation', GENERATION, *options])
    ensure
      Thistle.send(:remove_const, :Reader)
      Thistle.const_set(:Reader, original) if original
    end
  end

  class FakeReader
    attr_reader :manifest, :calls, :closes
    attr_accessor :query_error, :close_error
    def initialize(result, manifest)
      @result, @manifest, @calls, @closes = result, manifest, [], 0
    end
    def model_brief(id, **options)
      @calls << [id, options]
      raise query_error if query_error
      @result
    end
    def close
      @closes += 1
      raise close_error if close_error
    end
  end

  def test_export_uses_one_existing_selection_then_closes_and_writes_markdown
    assert_equal 0, invoke('--limit', '1', '--max-bytes', '65536')
    assert_empty @err.string
    assert @out.string.start_with?("# Saved model investigation\n")
    assert_equal [[['/private/store'], { generation: GENERATION }]], @opens
    assert_equal [[MODEL, { limit: 1, max_bytes: 65536 }]], @reader.calls
    assert_equal 1, @reader.closes
    refute_includes @out.string, '/private/store'
  end

  def test_missing_generation_model_and_unsupported_pagination_never_open_reader
    [ ['export-model-brief', MODEL, '--store', 'STORE'],
      ['export-model-brief', '--store', 'STORE', '--generation', GENERATION],
      ['export-model-brief', MODEL, '--store', 'STORE', '--generation', GENERATION, '--family', 'columns'] ].each do |args|
      assert_equal 2, invoke(arguments: args)
      assert_empty @opens
      assert_empty @out.string
      assert_equal 'invalid_input', JSON.parse(@err.string).dig('error', 'code')
    end
  end

  def test_refusals_query_errors_and_malformed_result_close_with_no_report
    assert_equal 4, invoke('--max-bytes', '1')
    assert_empty @out.string
    assert_equal 'limit_exceeded', JSON.parse(@err.string).dig('error', 'code')
    assert_equal 1, @reader.closes
    [Thistle::NotFound.new('Model unavailable'), Thistle::LimitExceeded.new('Brief refused'), RuntimeError.new('private error')].each do |error|
      reader = FakeReader.new(brief, manifest)
      reader.query_error = error
      refute_equal 0, invoke(reader: reader)
      assert_empty @out.string
      assert_equal 1, reader.closes
      refute_includes @err.string, 'private error'
    end
    reader = FakeReader.new(brief.merge('generation' => 'f' * 64), manifest)
    assert_equal 4, invoke(reader: reader)
    assert_empty @out.string
    assert_equal 1, reader.closes
  end

  def test_missing_saved_generation_refuses_instead_of_retrying_current
    assert_equal 3, invoke(opening_error: Thistle::NotFound.new('Saved generation unavailable'))
    assert_equal 1, @opens.length
    assert_empty @out.string
    assert_equal 'not_found', JSON.parse(@err.string).dig('error', 'code')
  end

  def test_close_failure_emits_no_success_report_and_output_failure_still_closed
    reader = FakeReader.new(brief, manifest)
    reader.close_error = RuntimeError.new('private close error')
    assert_equal 1, invoke(reader: reader)
    assert_empty @out.string
    assert_equal 1, reader.closes
    failing_output = Object.new
    def failing_output.write(*) = raise(IOError, 'output failed')
    assert_equal 1, invoke(out: failing_output)
    assert_equal 'internal_error', JSON.parse(@err.string).dig('error', 'code')
    assert_equal 1, @reader.closes
  end

  def test_buffered_output_failure_is_handled_after_write_and_reader_close
    output = Object.new
    writes = []
    output.define_singleton_method(:write) { |text| writes << text; text.bytesize }
    output.define_singleton_method(:flush) do
      raise IOError, 'private buffered output failure'
    end
    assert_equal 1, invoke(out: output)
    assert_equal 1, writes.length
    assert writes.first.start_with?("# Saved model investigation\n")
    assert_equal 1, @reader.closes
    assert_equal 'internal_error', JSON.parse(@err.string).dig('error', 'code')
    refute_includes @err.string, 'private buffered output failure'
  end
end

# Root must admit this separately: it boots the real producer and executes native
# Reader/capture code. Source-only checks exclude /native_saved_generation/.
class ThistleMarkdownExportSavedGenerationTest < Minitest::Test
  def test_native_saved_generation_report_is_identical_after_current_advances
    require 'tmpdir'
    require 'fileutils'
    require 'open3'
    require 'rbconfig'
    Dir.mktmpdir('thistle-markdown-journey-') do |directory|
      root, store = %w[source store].map { |name| File.join(directory, name) }
      FileUtils.mkdir_p(root)
      fixture = File.expand_path('fixtures/model_brief', __dir__)
      FileUtils.cp(File.join(fixture, 'records.rb'), root)
      producer = <<~'PROGRAM'
        require 'json'; require 'stringio'; require 'thistle'; require 'thistle/cli'
        require ARGV[0]
        app = BriefFixture.boot(ARGV[1])
        saved = Thistle.capture(root: ARGV[1], output: ARGV[2], rails: app).fetch('generation')
        reader = Thistle::Reader.new(ARGV[2], generation: saved)
        begin
          model = reader.find('BriefFixture::Order').find { |fact| fact['kind'] == 'rails_model' && fact['name'] == 'BriefFixture::Order' }.fetch('id')
        ensure
          reader.close
        end
        report = lambda do
          out, err = StringIO.new, StringIO.new
          status = Thistle::CLI.new(out: out, err: err).run(['export-model-brief', model, '--store', ARGV[2], '--generation', saved, '--max-bytes', '65536'])
          raise "Export failed: #{err.string}" unless status.zero?
          out.string
        end
        first = report.call
        File.write(File.join(ARGV[1], 'records.rb'), 'class CurrentReplacement; end')
        newer = Thistle.capture(root: ARGV[1], output: ARGV[2]).fetch('generation')
        raise 'Report changed after CURRENT advanced' unless first == report.call && saved != newer
        expected = [
          'BriefFixture::Order', '--generation ' + saved,
          'Potential request (not execution):',
          '- provenance: ` captured_source_potential `',
          '- receiver: ` BriefFixture::DeliveryJob `',
          '- macro: ` has_many `', '- target: ` BriefFixture::Item `'
        ]
        raise 'Missing fixture evidence rows' unless expected.all? { |line| first.include?(line) }
        raise 'Embedded source excerpt' if first.include?('perform_later("雪')
        puts JSON.generate(saved: saved, newer: newer, bytes: first.bytesize, identical: true)
      PROGRAM
      lib = File.expand_path('../lib', __dir__)
      out, err, status = Open3.capture3(RbConfig.ruby, '-I', lib, '-e', producer, File.join(fixture, 'booted_app.rb'), root, store)
      assert status.success?, err
      receipt = JSON.parse(out.lines.last)
      refute_equal receipt.fetch('saved'), receipt.fetch('newer')
      assert_equal true, receipt.fetch('identical')
      assert_operator receipt.fetch('bytes'), :<=, 65536
    end
  end
end
