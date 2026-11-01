# frozen_string_literal: true

require 'optparse'
require_relative '../mcp'
require_relative 'server'

module Thistle
  module MCP
    module Stdio
      # SDK owns parsing, protocol negotiation, dispatch and framing. These two
      # documented-version seams add admission/accounting, not a JSON-RPC loop.
      def self.transport_class
        Class.new(::MCP::Server::Transports::StdioTransport) do
          def initialize(server)
            super(server, max_line_bytes: Limits::FRAME_BYTES)
            @frames = @input_bytes = @wire_bytes = 0
          end

          def send_response(message)
            # Serialize an object once; SDK accepts the preencoded String.
            json = message.is_a?(String) ? message : JSON.generate(message)
            bytes = json.bytesize + 1
            raise ConnectionEnd, 'output byte allowance exhausted' if bytes > Limits::WIRE_BYTES || @wire_bytes + bytes > Limits::TOTAL_WIRE_BYTES
            @wire_bytes += bytes # Charge before the first write, including failures.
            super(json)
            # handle_json returns encoded JSON for malformed input; inspecting
            # its small error envelope does not parse successful large results.
            parsed = message.is_a?(Hash) ? message : (json.include?('"error"') && json.bytesize < 4096 ? JSON.parse(json) : nil)
            error = parsed.is_a?(Hash) ? (parsed[:error] || parsed['error']) : nil
            close if error.is_a?(Hash) && (error[:code] || error['code']) == -32700
          rescue IOError, SystemCallError
            raise ConnectionEnd, 'protocol output disconnected'
          end

          private

          def read_line(io)
            raise ConnectionEnd, 'input frame allowance exhausted' if @frames >= Limits::FRAMES
            line = super
            if line
              @frames += 1
              @input_bytes += line.bytesize
              raise ConnectionEnd, 'input byte allowance exhausted' if @input_bytes > Limits::INPUT_BYTES
            end
            line
          rescue ::MCP::Server::RequestHandlerError
            # Convert oversized framing refusal before the SDK's outer reporter
            # can retain the raw exception. No second framing/parser implementation.
            raise ConnectionEnd, 'input frame exceeds allowance'
          end
        end
      end

      def self.run(argv, diagnostics: $stderr, **dependencies)
        run_session(argv, diagnostics: diagnostics, **dependencies)
      rescue OptionParser::ParseError, Refusal
        diagnostics.puts('thistle-mcp: use --store STORE --generation SAVED_SHA256; no CURRENT fallback')
        2
      rescue ConnectionEnd
        diagnostics.puts('thistle-mcp: connection ended at an admission limit or disconnect')
        1
      rescue Interrupt
        diagnostics.puts('thistle-mcp: interrupted')
        130
      rescue LoadError, StandardError
        diagnostics.puts('thistle-mcp: startup or saved Reader operation failed')
        1
      end

      def self.run_session(argv, reader_class: nil, server_builder: Server.method(:build), transport_factory: nil, diagnostics: $stderr)
        options = {}
        parser = OptionParser.new do |p|
          p.on('--store STORE') { |value| raise OptionParser::InvalidArgument, 'duplicate store' if options.key?(:store); options[:store] = value }
          p.on('--generation ID') { |value| raise OptionParser::InvalidArgument, 'duplicate generation' if options.key?(:generation); options[:generation] = value }
        end
        remaining = parser.parse(argv.dup)
        unless remaining.empty? && options.keys.sort == %i[generation store] && Limits::ID.match?(options[:generation]) && !options[:store].empty?
          raise Refusal.new('invalid_startup', 'Explicit store and generation required.')
        end
        unless reader_class
          require 'thistle'
          reader_class = Thistle::Reader
        end
        session = transport = nil
        # Mask acquisition windows; the ensure owns both resources before a
        # pending Interrupt can be delivered. Native cannot be preempted safely.
        Thread.handle_interrupt(Object => :never) do
          session = Session.open(**options, reader_class: reader_class)
          server = server_builder.call(session, diagnostics: diagnostics)
          factory = transport_factory || transport_class.method(:new)
          transport = factory.call(server)
        end
        transport.open
        0
      ensure
        # SDK may raise SystemExit on INT; ensure still runs. Cleanup exceptions
        # cannot prevent the other resource from closing.
        begin
          transport&.close
        ensure
          session&.close
        end
      end
    end
  end
end
