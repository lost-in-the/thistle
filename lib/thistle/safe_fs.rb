# frozen_string_literal: true

module Thistle
  # Descriptor-anchored access avoids following attacker-replaced ancestors.
  # The first milestone is Linux-only; unsupported platforms refuse explicitly.
  module SafeFS
    class Directory
      def self.open(path, create: false)
        unless File.directory?("/proc/self/fd") && File.const_defined?(:NOFOLLOW)
          raise UnsupportedPlatform, "Snapshot access currently requires Linux descriptor paths"
        end
        absolute = File.expand_path(path.to_s)
        raise UnsafePath, "NUL in directory path" if absolute.include?("\0")

        current = new(File.open("/", File::RDONLY | File::NOFOLLOW))
        begin
          absolute.split("/").reject(&:empty?).each do |part|
            child = current.child(part, create: create)
            current.close
            current = child
          end
          current
        rescue Exception
          current.close
          raise
        end
      rescue Errno::ELOOP, Errno::ENOTDIR
        raise UnsafePath, "Directory path contains a symlink or non-directory"
      end

      def initialize(io)
        @io = io
        raise UnsafePath, "Expected a directory" unless io.stat.directory?
      end

      def child(name, create: false)
        destination = entry(name)
        if create
          begin
            Dir.mkdir(destination, 0o700)
          rescue Errno::EEXIST
            # The descriptor open below still refuses symlinks and files.
          end
        end
        io = File.open(destination, File::RDONLY | File::NOFOLLOW | File::NONBLOCK)
        self.class.new(io)
      rescue Errno::ELOOP, Errno::ENOTDIR
        io.close if io && !io.closed?
        raise UnsafePath, "Unsafe snapshot directory"
      rescue Exception
        io.close if io && !io.closed?
        raise
      end

      def read(name, max_bytes:)
        io = open_file(name, File::RDONLY)
        begin
          raise LimitExceeded, "Snapshot file exceeds byte limit" if io.stat.size > max_bytes
          bytes = io.read(max_bytes + 1)
          raise LimitExceeded, "Snapshot file exceeds byte limit" if bytes.bytesize > max_bytes
          bytes
        ensure
          io.close
        end
      end

      def open_file(name, flags, mode = 0o600)
        io = File.open(entry(name), flags | File::NOFOLLOW | File::NONBLOCK, mode)
        unless io.stat.file?
          io.close
          raise UnsafePath, "Snapshot entry is not a regular file"
        end
        io.binmode
        io
      rescue Errno::ELOOP
        raise UnsafePath, "Snapshot entry is a symlink"
      end

      def write_new(name, bytes)
        io = open_file(name, File::WRONLY | File::CREAT | File::EXCL)
        begin
          io.write(bytes)
          io.flush
          io.fsync
        ensure
          io.close
        end
      end

      def rename(from, destination, to)
        File.rename(entry(from), destination.entry(to))
      end

      def unlink(name)
        File.unlink(entry(name))
      rescue Errno::ENOENT
        nil
      end

      def sync
        @io.fsync
      end

      def entry(name)
        unless name.is_a?(String) && !name.empty? && ![".", ".."].include?(name) && !name.match?(/[\x00\/]/)
          raise UnsafePath, "Invalid snapshot entry name"
        end
        "/proc/self/fd/#{@io.fileno}/#{name}"
      end

      def close
        @io.close unless @io.closed?
      end
    end
  end
end
