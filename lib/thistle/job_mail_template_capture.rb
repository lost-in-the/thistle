# frozen_string_literal: true

require 'digest'

module Thistle
  # Raw bounded bytes only. The capture aggregator supplies a dedicated, safely
  # opened regular File from its admitted root. Rust owns path admission, ERB
  # syntax, semantic references and source identity. This does not open paths.
  class JobMailTemplateCapture
    MAX_BYTES = 262_144

    def self.call(file:, path:, max_bytes: MAX_BYTES)
      raise ArgumentError, 'Invalid template byte limit' unless max_bytes.instance_of?(Integer) && (1..MAX_BYTES).cover?(max_bytes)
      raise TypeError, 'Dedicated File required' unless Object.instance_method(:instance_of?).bind_call(file, File)
      before = File.instance_method(:stat).bind_call(file)
      raise TypeError, 'Regular File required' unless before.file?
      raise RangeError, 'Template exceeds byte limit' if before.size > max_bytes
      IO.instance_method(:seek).bind_call(file, 0, IO::SEEK_SET)
      content = IO.instance_method(:read).bind_call(file, max_bytes + 1) || ''.b
      after = File.instance_method(:stat).bind_call(file)
      raise RangeError, 'Template exceeds byte limit' if content.bytesize > max_bytes
      unless [before.dev, before.ino, before.size, before.mtime, before.ctime] ==
          [after.dev, after.ino, after.size, after.mtime, after.ctime] && content.bytesize == after.size
        raise IOError, 'Template changed during capture'
      end
      # Encoding admission is Rust-owned; do not transcode captured bytes.
      # JSON cannot transport invalid UTF-8 strings. Numeric bytes preserve the
      # original encoding for Rust admission without a Ruby syntax/encoding policy.
      { 'path' => path, 'content_bytes' => content.bytes, 'bytes' => content.bytesize,
        'sha256' => Digest::SHA256.hexdigest(content), 'provenance' => 'raw_template_bytes' }
    end
  end
end
