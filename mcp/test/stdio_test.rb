# frozen_string_literal: true

require 'stringio'
require_relative 'session_test'
require_relative '../lib/thistle/mcp/stdio'

# A seam double, NOT the SDK transport or a protocol implementation. It only
# exposes the parent methods the bounded subclass calls. Real protocol cases
# are authored separately and remain UNRUN until execution is admitted.
module MCP
  class Server
    class RequestHandlerError < StandardError; end
    module Transports
      class StdioTransport
        attr_reader :sent, :closed
        def initialize(_server, max_line_bytes:)
          @max_line_bytes = max_line_bytes
          @sent = []
        end
        def send_response(message) = @sent << message
        def close = @closed = true
        def read_line(io)
          line = io.gets("\n", @max_line_bytes)
          raise MCP::Server::RequestHandlerError if line && line.bytesize >= @max_line_bytes && !line.end_with?("\n")
          line
        end
      end
    end
  end
end

class StdioTest < Minitest::Test
  def teardown = SavedGenerationReaderPure.assert_isolation!

  def test_cleanup_on_eof_interrupt_sdk_exit_and_connection_end
    [nil, Interrupt.new, SystemExit.new(130), Thistle::MCP::ConnectionEnd.new].each do |failure|
      reader = SavedGenerationReaderPure::Reader.new
      klass = Class.new
      klass.define_singleton_method(:new) { |*args, **kwargs| reader }
      transport = Object.new
      transport.define_singleton_method(:open) { raise failure if failure }
      closed = false
      transport.define_singleton_method(:close) { closed = true }
      run = -> { Thistle::MCP::Stdio.run(['--store', 'fixture-store', '--generation', SavedGenerationReaderPure::GENERATION],
        reader_class: klass, server_builder: ->(*args, **kwargs) { Object.new },
        transport_factory: ->(_) { transport }, diagnostics: StringIO.new) }
      if failure.is_a?(SystemExit)
        assert_raises(SystemExit, &run)
      else
        assert_equal(failure.nil? ? 0 : failure.is_a?(Interrupt) ? 130 : 1, run.call)
      end
      assert closed
      assert reader.closed
    end
  end

  def test_startup_requires_explicit_generation_before_reader_construction
    klass = Class.new
    klass.define_singleton_method(:new) { |*| raise 'Reader must not open' }
    assert_equal 2, Thistle::MCP::Stdio.run(['--store', 'x'], reader_class: klass, diagnostics: StringIO.new)
    assert_equal 2, Thistle::MCP::Stdio.run(['--store', 'x', '--generation', 'CURRENT'], reader_class: klass, diagnostics: StringIO.new)
  end

  def test_failed_transport_cleanup_still_closes_reader_and_reports_controlled_failure
    reader = SavedGenerationReaderPure::Reader.new
    klass = Class.new
    klass.define_singleton_method(:new) { |*args, **kwargs| reader }
    transport = Object.new
    transport.define_singleton_method(:open) { nil }
    transport.define_singleton_method(:close) { raise 'private exception detail' }
    diagnostics = StringIO.new
    result = Thistle::MCP::Stdio.run(['--store', 'fixture-store', '--generation', SavedGenerationReaderPure::GENERATION],
      reader_class: klass, server_builder: ->(*args, **kwargs) { Object.new },
      transport_factory: ->(_) { transport }, diagnostics: diagnostics)
    assert_equal 1, result
    assert reader.closed
    refute_includes diagnostics.string, 'private exception detail'
  end

  def test_bounded_sdk_seams_end_on_oversize_input_parse_error_and_output_limit
    transport = Thistle::MCP::Stdio.transport_class.new(Object.new)
    assert_raises(Thistle::MCP::ConnectionEnd) { transport.send(:read_line, StringIO.new('x' * Thistle::MCP::Limits::FRAME_BYTES)) }
    transport.send_response({ error: { code: -32700, message: 'Parse error' } })
    assert transport.closed
    assert_raises(Thistle::MCP::ConnectionEnd) { transport.send_response('x' * Thistle::MCP::Limits::WIRE_BYTES) }
    assert_equal 1, transport.sent.length
  end

  def test_cumulative_input_frames_and_wire_output_are_finite
    transport = Thistle::MCP::Stdio.transport_class.new(Object.new)
    input = StringIO.new("\n" * (Thistle::MCP::Limits::FRAMES + 1))
    Thistle::MCP::Limits::FRAMES.times { transport.send(:read_line, input) }
    assert_raises(Thistle::MCP::ConnectionEnd) { transport.send(:read_line, input) }
    transport = Thistle::MCP::Stdio.transport_class.new(Object.new)
    line = 'x' * 8191 + "\n"
    input = StringIO.new(line * 129)
    128.times { transport.send(:read_line, input) }
    assert_raises(Thistle::MCP::ConnectionEnd) { transport.send(:read_line, input) }
    transport = Thistle::MCP::Stdio.transport_class.new(Object.new)
    payload = 'x' * (4 * 1024 * 1024 - 1)
    8.times { transport.send_response(payload) }
    assert_raises(Thistle::MCP::ConnectionEnd) { transport.send_response(payload) }
    assert_equal 8, transport.sent.length
  end

  def test_encoded_batch_error_is_sent_once_without_post_write_type_error
    transport = Thistle::MCP::Stdio.transport_class.new(Object.new)
    batch = JSON.generate([{ 'jsonrpc' => '2.0', 'id' => 1,
      'error' => { 'code' => -32601, 'message' => 'Method not found' } }])
    transport.send_response(batch)
    assert_equal [batch], transport.sent
    refute transport.closed
    # The SDK also passes the real parse-error envelope as an encoded string.
    transport.send_response(JSON.generate('error' => { 'code' => -32700, 'message' => 'Parse error' }))
    assert transport.closed
    assert_equal 2, transport.sent.length
  end
end
