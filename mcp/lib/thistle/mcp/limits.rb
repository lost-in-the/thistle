# frozen_string_literal: true

module Thistle
  module MCP
    module Limits
      FRAME_BYTES = 16 * 1024
      INPUT_BYTES = 1024 * 1024
      FRAMES = 256
      CALLS = 64
      CHECKS = 1
      RESULT_BYTES = 2 * 1024 * 1024 + 64 * 1024
      TOTAL_RESULT_BYTES = 16 * 1024 * 1024
      WIRE_BYTES = 8 * 1024 * 1024
      TOTAL_WIRE_BYTES = 32 * 1024 * 1024
      SOURCE_BYTES = 64 * 1024
      TOTAL_SOURCE_BYTES = 256 * 1024
      MANIFEST_FILES = 10_000
      CURSOR_BYTES = 512
      ID = /\A[0-9a-f]{64}\z/
    end

    class Refusal < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    # Not StandardError: the SDK's per-frame rescue must not continue after a
    # connection budget, malformed frame or failed output. Stdio owns cleanup.
    class ConnectionEnd < Exception; end
  end
end
