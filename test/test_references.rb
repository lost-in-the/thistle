# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'thistle'

class ThistleReferencesTest < Minitest::Test
  def test_pinned_native_selection_to_reader_and_source_then_close
    Dir.mktmpdir do |dir|
      root = File.join(dir, 'input')
      FileUtils.mkdir_p(root)
      bytes = File.binread(File.join(__dir__, 'fixtures/model_references.rb'))
      File.binwrite(File.join(root, 'models.rb'), bytes)
      store = File.join(dir, 'store')
      generation = Thistle.capture(root: root, output: store).fetch('generation')
      reader = Thistle::Reader.new(store)
      begin
        user = reader.find('User').find { |fact| fact['kind'] == 'class' && fact['name'] == 'User' }
        method = reader.find('Order#owner').first
        result = reader.references(user.fetch('id'), direction: 'incoming')
        assert_equal generation, result.fetch('generation')
        assert_includes result.fetch('relationships').map { |row| row.fetch('origin').fetch('id') }, method.fetch('id')
        outgoing = reader.references(method.fetch('id'))
        row = outgoing.fetch('relationships').find { |relationship| relationship['candidate_label'] == 'User' }
        assert_equal 2, row.fetch('candidate_matches')
        refute_includes row.fetch('candidates').map { |fact| fact.fetch('name') }, 'Admin::User'
        File.write(File.join(root, 'models.rb'), "class Changed; end\n")
        refute_equal generation, Thistle.capture(root: root, output: store).fetch('generation')
        row.fetch('candidates').each do |candidate|
          source = reader.source(candidate.fetch('id'))
          assert_equal bytes, source.fetch('content')
          assert_equal generation, source.fetch('generation')
          assert_equal Digest::SHA256.hexdigest(bytes), source.fetch('sha256')
        end
        assert_equal outgoing, reader.references(method.fetch('id'))
        assert_raises(Thistle::InvalidInput) { reader.references(user.fetch('id'), direction: 'sideways') }
        assert_raises(Thistle::InvalidInput) { reader.references(user.fetch('id'), limit: 0) }
      ensure
        reader.close
      end
      assert_raises(Thistle::Error) { reader.references(user.fetch('id')) }
    end
  end
end
