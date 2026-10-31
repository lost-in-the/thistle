# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'thistle'

class ThistleFactIdentityTest < Minitest::Test
  def test_identity_is_pinned_compact_and_obeys_reader_lifetime
    Dir.mktmpdir('thistle-identity-') do |directory|
      root, store = %w[root store].map { |name| File.join(directory, name) }
      FileUtils.mkdir_p(root)
      File.write(File.join(root, 'identity.rb'), 'class SavedIdentity; def call; Other.run; end; end')
      generation = Thistle.capture(root: root, output: store).fetch('generation')
      reader = Thistle::Reader.new(store, generation: generation)
      begin
        fact = reader.find('SavedIdentity').find { |row| row['kind'] == 'class' }
        refute_nil fact
        File.write(File.join(root, 'identity.rb'), 'class NewCurrent; end')
        refute_equal generation, Thistle.capture(root: root, output: store).fetch('generation')
        result = reader.fact_identity(fact.fetch('id'))
        assert_equal generation, result.fetch('generation')
        assert_equal fact.slice('id', 'kind', 'name', 'path', 'location', 'evidence'), result.fetch('fact')
        assert_equal %w[evidence id kind location name path], result.fetch('fact').keys.sort
        refute result.fetch('fact').key?('links')
        refute result.fetch('fact').key?('attributes')
        assert_operator JSON.generate(result).bytesize, :<=, 32 * 1024
        error = assert_raises(Thistle::Error) { reader.fact_identity('0' * 64) }
        assert_equal 'not_found', error.code
        error = assert_raises(Thistle::Error) { reader.fact_identity('invalid') }
        assert_equal 'invalid_input', error.code
      ensure
        reader.close
      end
      assert_raises(Thistle::Error) { reader.fact_identity('0' * 64) }
    end
  end
end
