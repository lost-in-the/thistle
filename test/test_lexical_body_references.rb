# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'thistle'

class ThistleLexicalBodyReferencesTest < Minitest::Test
  FIXTURES = File.join(__dir__, 'fixtures/lexical_body_origins')
  # Exact lexical origins and earliest representatives, not executed DSL results.
  BUTTON_ORIGINS = [
    ['file', 'top_level.rb', 'top_level.rb', 'Kit::Button.new(:top)'],
    ['method', 'Object#top_render', 'top_level.rb', 'Kit::Button.new(:top_method_hash)'],
    ['file', 'render.rake', 'render.rake', 'Kit::Button.new(:task_hash)'],
    ['file', 'button_spec.rb', 'button_spec.rb', 'Kit::Button.new(:spec_hash)'],
    ['module', 'LexicalDemo', 'namespaces.rb', 'Kit::Button.new(:module_body)'],
    ['class', 'LexicalDemo::Screen', 'namespaces.rb', 'Kit::Button.new(:class_body)'],
    ['method', 'LexicalDemo::Screen#render', 'namespaces.rb', 'Kit::Button.new(:method_hash)']
  ].freeze

  def test_saved_references_keep_exact_origins_and_source_after_current_advances
    Dir.mktmpdir do |dir|
      root = File.join(dir, 'input')
      FileUtils.cp_r(FIXTURES, root)
      bytes = Dir.children(root).to_h { |name| [name, File.binread(File.join(root, name))] }
      store = File.join(dir, 'store')
      generation = Thistle.capture(root: root, output: store).fetch('generation')
      reader = Thistle::Reader.new(store, generation: generation)
      begin
        button = reader.find('Kit::Button').find { |f| f['kind'] == 'class' && f['name'] == 'Kit::Button' }
        incoming = reader.references(button.fetch('id'), direction: 'incoming', limit: 50)
        assert_equal generation, incoming.fetch('generation')
        assert incoming.dig('coverage', 'scan_complete')
        assert_nil incoming.fetch('next_cursor')
        rows = incoming.fetch('relationships')
        expected = BUTTON_ORIGINS.map { |kind, name, path, _| [kind, name, path] }.sort
        assert_equal expected, rows.map { |r| r.fetch('origin').values_at('kind', 'name', 'path') }.sort
        assert_equal rows.length, rows.map { |r| [r.dig('origin', 'id'), r['link_ordinal']] }.uniq.length

        # Advance CURRENT and change all live bytes before following saved IDs.
        bytes.each_key { |name| File.binwrite(File.join(root, name), "# changed live source\n") }
        refute_equal generation, Thistle.capture(root: root, output: store).fetch('generation')
        fresh_pinned = Thistle::Reader.new(store, generation: generation)
        begin
          BUTTON_ORIGINS.each do |kind, name, path, expression|
            row = rows.find { |r| r.fetch('origin').values_at('kind', 'name', 'path') == [kind, name, path] }
            origin = row.fetch('origin')
            source = fresh_pinned.source(origin.fetch('id'))
            assert_equal generation, source.fetch('generation')
            assert_equal bytes.fetch(path), source.fetch('content')
            assert_equal Digest::SHA256.hexdigest(bytes.fetch(path)), source.fetch('sha256')
            call = row.dig('link', 'attributes', 'thistle_call', 'data')
            assert_equal ['constant', 'Kit::Button', false, false], call.first(4)
            start_byte = bytes.fetch(path).index(expression)
            end_byte = start_byte + expression.bytesize
            line = bytes.fetch(path).byteslice(0, start_byte).count("\n") + 1
            assert_equal [start_byte, end_byte, line, line], call.fetch(4)
            assert_equal 'Kit::Button', source.fetch('content').byteslice(call.fetch(5)[0]...call.fetch(5)[1])
            location = origin.fetch('location')
            assert_operator location.fetch('start_byte'), :<=, start_byte
            assert_operator location.fetch('end_byte'), :>=, end_byte
            outgoing = fresh_pinned.references(origin.fetch('id'))
            assert_includes outgoing.fetch('relationships').map { |r| r.fetch('link') }, row.fetch('link')
          end
          assert_equal incoming.fetch('relationships'), fresh_pinned.references(button.fetch('id'), direction: 'incoming').fetch('relationships')
        ensure
          fresh_pinned.close
        end
      ensure
        reader.close
      end
    end
  end

  def test_added_file_links_and_dynamic_diagnostics_refuse_without_advancing_current
    Dir.mktmpdir do |dir|
      root = File.join(dir, 'input')
      FileUtils.mkdir_p(root)
      path = File.join(root, 'body.rb')
      File.binwrite(path, "Kit::Button.new\n")
      store = File.join(dir, 'store')
      generation = Thistle.capture(root: root, output: store).fetch('generation')
      File.binwrite(path, "Kit::Button.new; Other.call\n")
      assert_raises(Thistle::LimitExceeded) { Thistle.capture(root: root, output: store, limits: { max_links: 1 }) }
      File.binwrite(path, File.binread(File.join(FIXTURES, 'dynamic.rb')))
      assert_raises(Thistle::LimitExceeded) { Thistle.capture(root: root, output: store, limits: { max_diagnostics: 1 }) }
      reader = Thistle::Reader.new(store)
      begin
        file = reader.find('body.rb').find { |f| f['kind'] == 'file' }
        assert_equal generation, reader.source(file.fetch('id')).fetch('generation')
        assert_equal "Kit::Button.new\n", reader.source(file.fetch('id')).fetch('content')
        reader.check
      ensure
        reader.close
      end
    end
  end
end
