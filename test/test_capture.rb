# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require "digest"
require_relative "../lib/thistle/capture"

class ThistleCaptureTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("thistle-capture-")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write(path, content)
    destination = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(destination))
    File.binwrite(destination, content)
  end

  def capture(**options)
    Thistle::Capture.new(root: @root, **options).call
  end

  def declaration(result, name)
    result.fetch("facts").find { |fact| fact["name"] == name }
  end

  def test_records_lexical_declarations_with_exact_multibyte_source_and_no_execution
    code = <<~RUBY
      # 確認
      File.write(#{File.join(@root, "executed").inspect}, "unsafe")
      module Orchard
        class Basket < Container
          include Countable
          def count_items(prefix = "🍎")
            items.length
          end
          def self.build
            new
          end
        end
      end
    RUBY
    write("app/basket.rb", code)
    result = capture

    refute File.exist?(File.join(@root, "executed"))
    assert declaration(result, "Orchard")
    assert declaration(result, "Orchard::Basket")
    method = declaration(result, "Orchard::Basket#count_items")
    assert method
    assert declaration(result, "Orchard::Basket.build")
    position = method.fetch("location")
    snippet = code.b.byteslice(position["start_byte"]...position["end_byte"]).force_encoding("UTF-8")
    assert_equal "def count_items(prefix = \"🍎\")\n      items.length\n    end", snippet
    assert_equal Digest::SHA256.hexdigest(code), result["files"][0]["sha256"]
    assert_equal code, result["files"][0]["content"]
    links = declaration(result, "Orchard::Basket")["links"]
    assert_includes links, { "relation" => "inherits", "target" => "Container", "resolution" => "unresolved" }
    assert_includes links, { "relation" => "includes", "target" => "Countable", "resolution" => "unresolved" }
    assert method["links"].all? { |link| link["resolution"] == "unresolved" }
    assert_equal "unavailable", result["coverage"].find { |c| c["family"] == "execution_trace" }["status"]
    assert_equal result, JSON.parse(JSON.generate(result))
  end

  def test_capture_is_deterministic_and_changed_source_changes_the_digest
    write("b.rb", "class Crate; def label; :crate; end; end\n")
    write("a.rb", "module Orchard; end\n")
    first = capture
    assert_equal first, capture
    assert_equal %w[a.rb b.rb], first["files"].map { |file| file["path"] }
    write("b.rb", "class Crate; def label; :new_label; end; end\n")
    second = capture
    refute_equal first["files"][1]["sha256"], second["files"][1]["sha256"]
    assert_equal declaration(first, "Crate#label")["id"], declaration(second, "Crate#label")["id"]
  end

  def test_syntax_errors_are_not_silently_empty_success
    write("broken.rb", "class Broken\n def missing(\n")
    result = capture
    assert_equal ["file"], result["facts"].map { |fact| fact["kind"] }
    assert_equal "invalid", result["facts"][0]["attributes"]["parse_status"]
    assert_equal "partial", result["coverage"].find { |c| c["family"] == "ruby_declarations" }["status"]
    assert result["diagnostics"].any? { |d| d["code"] == "syntax_error" }
  end

  def test_symlinks_cannot_expose_outside_source
    Dir.mktmpdir("thistle-outside-") do |outside|
      File.write(File.join(outside, "secret.rb"), "class SecretOutside; end")
      File.symlink(outside, File.join(@root, "external"))
      File.symlink(File.join(outside, "secret.rb"), File.join(@root, "secret.rb"))
      write("safe.rb", "class Safe; end")
      result = capture
      assert_equal ["safe.rb"], result["files"].map { |file| file["path"] }
      refute declaration(result, "SecretOutside")
      assert_equal 2, result["diagnostics"].count { |d| d["code"] == "symlink_skipped" }
      assert_equal "partial", result["coverage"].find { |c| c["family"] == "source_inventory" }["status"]
    end
  end

  def test_excludes_declared_directories_and_does_not_read_non_ruby_files
    write("vendor/dependency.rb", "class Dependency; end")
    write(".thistle/store.rb", "class Snapshot; end")
    write("node_modules/loader.rb", "class Npm; end")
    write("config/secrets.yml", "password: example")
    write("Rakefile", "task :check do; end")
    assert_equal ["Rakefile"], capture["files"].map { |file| file["path"] }
  end

  def test_native_engine_can_inspect_its_rust_source_without_claiming_rust_semantics
    code = "pub fn example() -> usize { 42 }\n"
    write("engine/src/example.rs", code)
    result = capture
    assert_equal "rust", result["producer"]["engine"]
    assert_equal "1.9.0", result["producer"]["prism_version"]
    assert_equal code, result["files"][0]["content"]
    assert_equal Digest::SHA256.hexdigest(code), result["files"][0]["sha256"]
    assert_equal ["file"], result["facts"].map { |fact| fact["kind"] }
    assert_equal "not_parsed", result["facts"][0]["attributes"]["parse_status"]
    assert_equal "unavailable", result["coverage"].find { |c| c["family"] == "rust_declarations" }["status"]
  end

  def test_encoding_is_explicit_and_not_silently_transcoded
    write("legacy.rb", "# encoding: ISO-8859-1\nclass Legacy; end\n")
    write("invalid.rb", "# invalid\n\xff\n".b)
    result = capture
    assert_empty result["files"]
    assert_equal 2, result["diagnostics"].count { |d| d["code"] == "unsupported_encoding" }
    assert_equal "partial", result["coverage"].find { |c| c["family"] == "ruby_declarations" }["status"]
  end

  def test_dynamic_owners_are_not_invented
    write("dynamic.rb", <<~RUBY)
      Factory.class_eval do
        def hidden_owner; end
      end
      class Known
        Factory.class_eval do
          include DoNotAssignToKnown
        end
        class << self
          def build; end
        end
      end
      class << arbitrary_object
        def other_hidden_owner; end
      end
      def self.main_method; end
    RUBY
    result = capture
    assert declaration(result, "Known.build")
    assert declaration(result, "<main>.main_method")
    refute declaration(result, "Known")["links"].any? { |link| link["relation"] == "includes" && link["target"] == "DoNotAssignToKnown" }
    refute result["facts"].any? { |fact| fact["name"].include?("hidden_owner") }
    assert result["diagnostics"].any? { |d| d["code"] == "dynamic_scope" }
  end

  def test_limits_refuse_capture_instead_of_returning_successfully_truncated_facts
    write("a.rb", "class TooBig; end\n")
    assert_raises(Thistle::Capture::LimitError) { capture(limits: { max_file_bytes: 4 }) }
    write("b.rb", "class Second; end\n")
    assert_raises(Thistle::Capture::LimitError) { capture(limits: { max_files: 1 }) }
    assert_raises(Thistle::Capture::LimitError) { capture(limits: { max_facts: 1 }) }
    assert_raises(Thistle::InvalidInput) { capture(limits: { max_files: -1 }) }
    assert_raises(Thistle::InvalidInput) { capture(limits: { invented_limit: 1 }) }
  end

  def test_fifo_with_source_extension_never_blocks_or_reads
    fifo = File.join(@root, "not_a_file.rb")
    system("mkfifo", fifo, exception: true)
    result = capture
    assert_empty result["files"]
    assert result["diagnostics"].any? { |d| d["code"] == "non_regular_file" }
  end
end
