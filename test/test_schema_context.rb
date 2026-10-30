# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/thistle"

class ThistleSchemaContextTest < Minitest::Test
  def test_split_and_combined_capture_preserve_compact_reader_contract
    Dir.mktmpdir do |dir|
      root = File.join(dir, "input")
      FileUtils.mkdir_p(root)
      File.write(File.join(root, "calls.rb"), "class Box; def run(x); x&.call; end; end\n")
      capture = Thistle::Capture.new(root: root).call
      assert_equal 3, capture.fetch("schema_version")
      assert_equal 2, capture.fetch("producer").fetch("call_target_schema")
      split = Thistle::Store.new(File.join(dir, "split")).publish(capture)
      combined = Thistle.capture(root: root, output: File.join(dir, "combined"))
      assert_equal split, combined
      reader = Thistle::Reader.new(File.join(dir, "combined"))
      begin
        assert_equal 3, reader.manifest.fetch("schema_version")
        fact = reader.find("Box#run").first
        extension = reader.links(fact.fetch("id")).first.fetch("attributes").fetch("thistle_call")
        assert_equal 2, extension.fetch("version")
        assert_equal ["local", "x", false, true], extension.fetch("data").first(4)
        assert_equal capture.fetch("files").first.fetch("content"), reader.source(fact.fetch("id")).fetch("content")
      ensure
        reader.close
      end
    end
  end
end
