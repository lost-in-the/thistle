# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "json"
require "rbconfig"
require "timeout"
require_relative "support/process_limits"

# Run each ownership probe in a fresh process so native handle identities start
# at one, and a leaked handle cannot contaminate another test's registry budget.
class ThistleReaderOwnershipTest < Minitest::Test
  PROGRAM = <<~'RUBY'
    require "thistle"
    require "fileutils"
    require "digest"

    def canonical(value)
      case value
      when Hash
        value.keys.sort.to_h { |key| [key, canonical(value.fetch(key))] }
      when Array
        value.map { |item| canonical(item) }
      else
        value
      end
    end

    def retained_handles(before)
      (1...before).select do |handle|
        begin
          Thistle::Native.call("op" => "facts", "handle" => handle)
          true
        rescue Thistle::Error => error
          raise unless error.code == "closed_reader"
          false
        end
      end
    end

    root = File.join(ARGV.fetch(0), "root")
    store = File.join(ARGV.fetch(0), "store")
    Dir.mkdir(root)
    File.write(File.join(root, "basket.rb"), "class Basket; def count; 1; end; end\n")
    original = Thistle.capture(root: root, output: store).fetch("generation")

    case ARGV.fetch(1)
    when "deep_manifest"
      generation_dir = File.join(store, "generations", original)
      manifest = JSON.parse(File.read(File.join(generation_dir, "manifest.json")))
      nested = { "leaf" => 1 }
      110.times { nested = { "child" => nested } }
      manifest["producer"] = nested
      manifest.delete("generation")
      replacement = Digest::SHA256.hexdigest(JSON.generate(canonical(manifest), max_nesting: false))
      manifest["generation"] = replacement
      replacement_dir = File.join(store, "generations", replacement)
      Dir.mkdir(replacement_dir)
      File.write(File.join(replacement_dir, "manifest.json"), JSON.generate(canonical(manifest), max_nesting: false))
      FileUtils.cp(File.join(generation_dir, "facts.json"), File.join(replacement_dir, "facts.json"))
      File.write(File.join(store, "CURRENT"), "#{replacement}\n")
      failure = begin
        unexpected = Thistle::Reader.new(store)
        unexpected.close
        { "class" => "accepted" }
      rescue StandardError => error
        { "class" => error.class.name, "code" => error.respond_to?(:code) ? error.code : nil }
      end
      marker = Thistle::Native.call("op" => "open", "path" => store, "generation" => original)
      retained = retained_handles(marker.fetch("handle"))
      Thistle::Native.call("op" => "close", "handle" => marker.fetch("handle"))
      puts JSON.generate("failure" => failure, "next_handle" => marker.fetch("handle"), "retained" => retained)
    when "initialization_failure"
      GC.disable
      failing_reader = Class.new(Thistle::Reader) do
        private

        def deep_freeze(_value)
          raise "consumer initialization failure"
        end
      end
      failure = begin
        failing_reader.new(store)
        "accepted"
      rescue RuntimeError => error
        error.message
      end
      marker = Thistle::Native.call("op" => "open", "path" => store)
      before_gc = retained_handles(marker.fetch("handle"))
      GC.enable
      GC.start
      after_gc = retained_handles(marker.fetch("handle"))
      Thistle::Native.call("op" => "close", "handle" => marker.fetch("handle"))
      puts JSON.generate("failure" => failure, "next_handle" => marker.fetch("handle"),
                         "retained_before_gc" => before_gc, "retained_after_gc" => after_gc)
    when "thread_kill"
      GC.disable
      acquired = Queue.new
      release = Queue.new
      # This observes the real native call. The barrier makes Thread#kill land
      # after registration and before Ruby has transferred the handle to Reader.
      # No native response, exception, or resource operation is mocked.
      trace = TracePoint.new(:c_return) do |event|
        next unless event.method_id == :request_raw && event.defined_class == Thistle::Native.singleton_class
        trace.disable
        acquired << true
        release.pop
      end
      worker = Thread.new do
        trace.enable(target_thread: Thread.current) { Thistle::Reader.new(store) }
      end
      acquired.pop
      worker.kill
      release << true
      worker.join
      result = worker.value
      result.close if result
      marker = Thistle::Native.call("op" => "open", "path" => store)
      before_gc = retained_handles(marker.fetch("handle"))
      GC.enable
      GC.start
      after_gc = retained_handles(marker.fetch("handle"))
      Thistle::Native.call("op" => "close", "handle" => marker.fetch("handle"))
      puts JSON.generate("interrupted" => result.nil?, "next_handle" => marker.fetch("handle"),
                         "retained_before_gc" => before_gc, "retained_after_gc" => after_gc)
    else
      abort "Unknown ownership probe"
    end
  RUBY

  def probe(mode)
    Dir.mktmpdir("thistle-reader-ownership-") do |directory|
      stdout = File.join(directory, "stdout.txt")
      stderr = File.join(directory, "stderr.txt")
      pid = Process.spawn(
        RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", PROGRAM, directory, mode,
        out: stdout, err: stderr, **ThistleTestProcess::LIMITS
      )
      begin
        _pid, status = Timeout.timeout(15) { Process.waitpid2(pid) }
      rescue Timeout::Error
        Process.kill("KILL", pid) rescue nil
        Process.waitpid(pid) rescue nil
        flunk "Reader ownership probe exceeded its external deadline (#{mode})"
      end
      assert status.success?, "Reader ownership probe failed (#{mode}): #{File.read(stderr, 2_000)}"
      JSON.parse(File.read(stdout))
    end
  end

  def test_excessive_manifest_depth_is_refused_before_native_handle_registration
    result = probe("deep_manifest")
    assert_equal "Thistle::LimitExceeded", result.dig("failure", "class")
    assert_equal "limit_exceeded", result.dig("failure", "code")
    assert_equal 1, result.fetch("next_handle")
    assert_empty result.fetch("retained")
  end

  def test_failed_reader_initialization_closes_the_acquired_native_handle
    result = probe("initialization_failure")
    assert_equal "consumer initialization failure", result.fetch("failure")
    assert_equal 2, result.fetch("next_handle"), "The failing constructor must actually acquire a native reader"
    assert_empty result.fetch("retained_before_gc")
    assert_empty result.fetch("retained_after_gc")
  end

  def test_thread_kill_at_native_resource_handoff_does_not_leak_a_reader
    result = probe("thread_kill")
    assert result.fetch("interrupted"), "Thread#kill must really interrupt Reader.new"
    assert_equal 2, result.fetch("next_handle"), "The interrupted constructor must actually acquire a native reader"
    assert_empty result.fetch("retained_before_gc")
    assert_empty result.fetch("retained_after_gc")
  end
end
