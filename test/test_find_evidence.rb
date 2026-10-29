# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'stringio'
require 'thistle'
require 'thistle/cli'

class FindEvidenceTest < Minitest::Test
  def test_file_source_requires_generation_before_opening_a_reader
    out, err = StringIO.new, StringIO.new
    original = Thistle::Reader.method(:new)
    opened = false
    Thistle::Reader.define_singleton_method(:new) { |*| opened = true; raise 'Reader must not open' }
    assert_equal 2, Thistle::CLI.new(out: out, err: err).run(['source-file', 'spec/demo.rb', '--store', '/unused'])
    refute opened
    assert_empty out.string
    assert_equal 'invalid_input', JSON.parse(err.string).dig('error', 'code')
    assert_includes JSON.parse(err.string).dig('error', 'message'), '--generation'
  ensure
    Thistle::Reader.define_singleton_method(:new, original) if original
  end

  def test_reader_cli_file_source_and_old_generation
    Dir.mktmpdir('find-evidence') do |dir|
      root, store = File.join(dir, 'project'), File.join(dir, 'store')
      FileUtils.mkdir_p(File.join(root, 'spec'))
      content = "# é\n# unique_literal <script>\nclass Demo\n def one; end\n def two; end\nend\n"
      File.write(File.join(root, 'spec/demo.rb'), content)
      first = Thistle.capture(root: root, output: store)
      reader = Thistle::Reader.new(store)
      begin
        hit = reader.search_evidence('UNIQUE_LITERAL', domain: 'source').fetch('results').fetch(0)
        assert_equal 'file', hit['kind']
        assert_nil hit['fact_id']
        assert_equal 7, hit.dig('span', 'start_byte')
        assert_equal content, reader.source_file(hit['path'])['content']
        assert_equal 1, reader.search_evidence('unique_literal')['total_matches']
        File.write(File.join(root, 'spec/demo.rb'), "class Changed; end\n")
        Thistle.capture(root: root, output: store)
        out, err = StringIO.new, StringIO.new
        args = ['find', 'unique_literal', '--store', store, '--generation', first['generation'], '--domain', 'source', '--kind', 'file', '--path', 'spec/']
        assert_equal 0, Thistle::CLI.new(out: out, err: err).run(args), err.string
        assert_equal first['generation'], JSON.parse(out.string)['generation']
        out = StringIO.new
        assert_equal 0, Thistle::CLI.new(out: out, err: err).run(['source-file', hit['path'], '--store', store, '--generation', first['generation']]), err.string
        assert_equal content, JSON.parse(out.string)['content']
      ensure
        reader.close
      end
      assert_raises(Thistle::Error) { reader.search_evidence('literal') }
    end
  end
end
