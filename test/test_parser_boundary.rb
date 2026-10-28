# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "json"
require "rbconfig"
require "timeout"

# A parser crash must remain in a disposable process rather than take down the
# test controller. These regressions cover concrete failures found while the
# parser ran on Ruby's much smaller worker-thread stacks.
class ThistleParserBoundaryTest < Minitest::Test
  PROGRAM = <<~'RUBY'
    require "thistle/capture"
    run = lambda do
      begin
        captured = Thistle::Capture.new(root: ARGV.fetch(0)).call
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

  def assert_bounded_capture(source)
    %w[main thread].each do |mode|
      Dir.mktmpdir("thistle-parser-boundary-") do |directory|
        File.write(File.join(directory, "probe.rb"), source)
        stdout = File.join(directory, "stdout.txt")
        stderr = File.join(directory, "stderr.txt")
        pid = Process.spawn(
          RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", PROGRAM, directory, mode,
          out: stdout, err: stderr, rlimit_core: 0, rlimit_cpu: [10, 10],
          rlimit_as: [2 * 1024 * 1024 * 1024, 2 * 1024 * 1024 * 1024]
        )
        begin
          _pid, status = Timeout.timeout(15) { Process.waitpid2(pid) }
        rescue Timeout::Error
          Process.kill("KILL", pid) rescue nil
          Process.waitpid(pid) rescue nil
          flunk "Native parser did not finish within the external deadline (#{mode})"
        end
        assert status.success?, "Native parser process failed (#{mode}): #{File.read(stderr, 2_000)}"
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
    assert_bounded_capture("x" + ".a" * 1_000_000)
  end

  def test_malformed_deep_nesting_refuses_without_crashing
    assert_bounded_capture("(" * 10_000 + "@ ?")
  end
end
