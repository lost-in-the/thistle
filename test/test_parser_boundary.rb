# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "json"
require "rbconfig"
require "timeout"
require_relative "support/process_limits"

# A parser crash must remain in a disposable process rather than take down the
# test controller. These regressions cover concrete failures found while the
# parser ran on Ruby's much smaller worker-thread stacks.
class ThistleParserBoundaryTest < Minitest::Test
  PROGRAM = <<~'RUBY'
    require "thistle/capture"
    run = lambda do
      begin
        captured = Thistle::Capture.new(root: ARGV.fetch(0), limits: JSON.parse(ARGV.fetch(2))).call
        ruby = captured.fetch("coverage").find { |entry| entry["family"] == "ruby_declarations" }
        puts JSON.generate("status" => "captured", "ruby_status" => ruby.fetch("status"))
      rescue Thistle::Error => error
        puts JSON.generate("status" => "refused", "code" => error.code)
      end
    end
    if ARGV.fetch(1) == "thread"
      Thread.new { run.call }.value
    else
      run.call
    end
  RUBY

  def assert_bounded_capture(source, limits: {})
    %w[main thread].each do |mode|
      Dir.mktmpdir("thistle-parser-boundary-") do |directory|
        File.write(File.join(directory, "probe.rb"), source)
        stdout = File.join(directory, "stdout.txt")
        stderr = File.join(directory, "stderr.txt")
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        children_before = Process.times
        pid = Process.spawn(
          RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", PROGRAM, directory, mode, JSON.generate(limits),
          out: stdout, err: stderr, **ThistleTestProcess::LIMITS
        )
        begin
          _pid, status = Timeout.timeout(15) { Process.waitpid2(pid) }
        rescue Timeout::Error
          Process.kill("KILL", pid) rescue nil
          Process.waitpid(pid) rescue nil
          flunk "Native parser did not finish within the external deadline (#{mode})"
        end
        unless status.success?
          children_after = Process.times
          # These deltas cover all children reaped by this controller in the
          # interval; they are not isolated per-process resource measurements.
          failure = JSON.generate(
            "wait_status" => status.to_i, "exitstatus" => status.exitstatus,
            "termsig" => status.termsig, "coredump" => status.coredump?,
            "wall_seconds" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
            "waited_children_user_seconds" => children_after.cutime - children_before.cutime,
            "waited_children_system_seconds" => children_after.cstime - children_before.cstime,
            "stdout_prefix" => (File.binread(stdout, 2_000) || +"").force_encoding(Encoding::UTF_8).scrub,
            "stderr_prefix" => (File.binread(stderr, 2_000) || +"").force_encoding(Encoding::UTF_8).scrub
          )
        end
        assert status.success?, "Native parser process failed (#{mode}): #{failure}"
        result = JSON.parse(File.read(stdout))
        if result["status"] == "refused"
          assert_equal "limit_exceeded", result["code"]
        else
          assert_equal "captured", result["status"]
          assert_includes %w[complete partial], result["ruby_status"]
        end
      end
    end
  end

  def test_deep_parser_and_regexp_nesting_on_main_and_ruby_worker_threads
    assert_bounded_capture("(" * 10_000 + "1" + ")" * 10_000)
    assert_bounded_capture("/" + "(" * 10_000 + "a" + ")" * 10_000 + "/")
  end

  def test_long_ast_destructor_chain_is_bounded_on_both_caller_stacks
    # Keep the complete million-call input for Prism and its result destructor.
    # Stop the separate evidence walk early so link construction does not consume
    # the parser/destructor probe's fixed process allowance. Capture drops the
    # parse result before propagating this traversal refusal.
    assert_bounded_capture("x" + ".a" * 1_000_000, limits: { "max_nodes" => 1 })
  end

  def test_malformed_deep_nesting_refuses_without_crashing
    assert_bounded_capture("(" * 10_000 + "@ ?")
  end
end
