# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "stringio"
require "digest"
require "thistle"
require "thistle/cli"

class ThistleCoreTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("thistle-core-")
    @root = File.join(@directory, "project")
    @store = File.join(@directory, "index")
    FileUtils.mkdir_p(@root)
    @source = "# 🍎\nclass Basket < Container\n  def count\n    items.length\n  end\nend\n"
    File.write(File.join(@root, "basket.rb"), @source)
    @readers = []
  end

  def teardown
    @readers.each(&:close)
    FileUtils.remove_entry(@directory)
  end

  def publish
    Thistle.capture(root: @root, output: @store)
  end

  def reader(generation: nil)
    value = Thistle::Reader.new(@store, generation: generation)
    @readers << value
    value
  end

  def test_native_engine_and_full_generation_lifecycle
    assert_equal "rust", Thistle::Native.call("op" => "version")["engine"]
    first = publish
    old = reader
    fact = old.find("Basket#count").first
    source = old.source(fact.fetch("id"))
    assert_equal @source, source["content"]
    assert_equal Digest::SHA256.hexdigest(@source), source["sha256"]
    assert_equal first["generation"], source["generation"]
    assert_equal "unresolved", old.links(fact["id"]).first["resolution"]
    assert_equal "not_checked", old.check["freshness"]

    File.write(File.join(@root, "basket.rb"), "class Box; end\n")
    second = publish
    refute_equal first["generation"], second["generation"]
    assert_equal @source, old.source(fact["id"])["content"]
    assert_equal ["Box"], reader.find("Box").select { |item| item["kind"] == "class" }.map { |item| item["name"] }
    assert_equal @source, reader(generation: first["generation"]).source(fact["id"])["content"]
    assert_raises(Thistle::NotFound) { reader(generation: "f" * 64) }
  end

  def test_missing_paths_do_not_default_to_the_working_directory
    assert_raises(Thistle::InvalidInput) { Thistle.capture(root: @root, output: "") }
    assert_raises(Thistle::InvalidInput) { Thistle.capture(root: nil, output: @store) }
    assert_raises(Thistle::InvalidInput) { Thistle::Store.new(nil) }
    assert_raises(Thistle::InvalidInput) { Thistle::Reader.new("") }
    assert_raises(Thistle::InvalidInput) { Thistle::Native.call("op" => "publish", "path" => "", "capture" => {}) }
    refute File.exist?(@store)
  end

  def test_failed_capture_does_not_publish_and_stale_is_not_claimed_current
    first = publish
    assert_raises(Thistle::LimitExceeded) { Thistle.capture(root: @root, output: @store, limits: { max_file_bytes: 1 }) }
    assert_equal first["generation"], reader.generation
    assert_equal "not_checked", reader.check["freshness"]
    assert reader.manifest["coverage"].any? { |entry| entry["family"] == "source_tree_coherence" && entry["status"] == "unavailable" }
  end

  def test_node_limits_apply_across_api_split_and_cli
    limits = { max_nodes: 2_000_000 }
    split = Thistle::Capture.new(root: @root, limits: limits).call
    assert_equal 2_000_000, split.dig("producer", "effective_limits", "max_nodes")
    assert_operator split.dig("producer", "visited_nodes"), :>, 0
    manifest = Thistle.capture(root: @root, output: @store, limits: limits)
    assert_equal manifest, Thistle::Store.new(@store).publish(split)
    out, err = StringIO.new, StringIO.new
    assert_equal 0, Thistle::CLI.new(out: out, err: err).run(["capture", @root, "--output", @store, "--max-nodes", "2000000"])
    assert_equal manifest, JSON.parse(out.string)
    ["0", "5000001", "1.5", "x"].each do |value|
      assert_equal 2, Thistle::CLI.new(out: StringIO.new, err: StringIO.new).run(["capture", @root, "--output", @store, "--max-nodes", value])
    end
    assert_equal 2, Thistle::CLI.new(out: StringIO.new, err: StringIO.new).run(["check", "--store", @store, "--max-nodes", "1"])
    [0, -1, 1.5, "3", 5_000_001, 2**100].each do |value|
      assert_raises(Thistle::InvalidInput) { Thistle.capture(root: @root, output: @store, limits: { max_nodes: value }) }
    end
    assert_raises(Thistle::InvalidInput) { Thistle.capture(root: @root, output: @store, limits: { unknown: 1 }) }
    assert_equal 5_000_000, Thistle::Capture.new(root: @root, limits: { max_nodes: 5_000_000 }).call.dig("producer", "effective_limits", "max_nodes")
    assert_raises(Thistle::LimitExceeded) { Thistle.capture(root: @root, output: @store, limits: { max_nodes: 1 }) }
    assert_equal manifest["generation"], reader.generation
  end

  def test_publisher_rejects_fabricated_positions_and_source_digest
    publish
    data = Thistle::Capture.new(root: @root).call
    fact = data["facts"].find { |item| item["kind"] == "method" }
    fact["location"]["start_line"] = 99_999
    fact["location"]["end_line"] = 99_999
    assert_raises(Thistle::InvalidInput) { Thistle::Store.new(@store).publish(data) }
    data = Thistle::Capture.new(root: @root).call
    data["files"].first["sha256"] = "f" * 64
    assert_raises(Thistle::InvalidInput) { Thistle::Store.new(@store).publish(data) }
  end

  def test_corrupt_sources_and_symlink_stores_fail_closed
    publish
    current = reader
    fact = current.find("Basket#count").first
    digest = current.source(fact["id"])["sha256"]
    blob = File.join(@store, "blobs", digest)
    File.write(blob, "corrupt")
    assert_raises(Thistle::InvalidSnapshot) { current.source(fact["id"]) }
    assert_raises(Thistle::InvalidSnapshot) { current.check }
    File.unlink(blob)
    File.symlink(File.join(@root, "basket.rb"), blob)
    assert_raises(Thistle::UnsafePath) { current.source(fact["id"]) }
    link = File.join(@directory, "link-index")
    File.symlink(@store, link)
    assert_raises(Thistle::UnsafePath) { Thistle::Reader.new(link) }
  end

  def test_cli_contract_and_clear_errors
    out, err = StringIO.new, StringIO.new
    status = Thistle::CLI.new(out: out, err: err).run(["capture", @root, "--output", @store])
    assert_equal 0, status
    assert_empty err.string
    generation = JSON.parse(out.string).fetch("generation")
    out, err = StringIO.new, StringIO.new
    status = Thistle::CLI.new(out: out, err: err).run(["find", "Basket", "--store", @store, "--generation", generation, "--limit", "1"])
    assert_equal 0, status
    result = JSON.parse(out.string)
    assert_equal generation, result["generation"]
    assert_equal 1, result["results"].length
    assert result["truncated"]
    out, err = StringIO.new, StringIO.new
    assert_equal 2, Thistle::CLI.new(out: out, err: err).run(["find", "Basket"])
    assert_empty out.string
    assert_equal "invalid_input", JSON.parse(err.string)["error"]["code"]
  end

  def test_parallel_queries_and_gc_do_not_expose_borrowed_ruby_memory
    publish
    current = reader
    expected = current.search("Basket")
    threads = 4.times.map do
      Thread.new { 20.times { assert_equal expected, current.search("Basket") } }
    end
    3.times { GC.start; GC.compact if GC.respond_to?(:compact) }
    threads.each(&:value)
    current.close
    assert_raises(Thistle::Error) { current.find("Basket") }
  end

  def test_forked_native_state_refuses_without_deadlocking
    publish
    read_pipe, write_pipe = IO.pipe
    pid = fork do
      read_pipe.close
      begin
        Thistle::Native.call("op" => "version")
        write_pipe.write("unexpected_success")
      rescue Thistle::Error => error
        write_pipe.write(error.code)
      end
      write_pipe.close
      exit! 0
    end
    write_pipe.close
    assert IO.select([read_pipe], nil, nil, 5), "forked operation should refuse promptly"
    assert_equal "forked_process", read_pipe.read
  ensure
    read_pipe.close if read_pipe && !read_pipe.closed?
    Process.wait(pid) if pid
  end
end
