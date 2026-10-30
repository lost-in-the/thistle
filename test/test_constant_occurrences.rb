# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'thistle'

# Authored known answers; not executed in the source phase. Rooted matching
# additionally requires the protected Reader recognition described in the contract.
class ThistleConstantOccurrencesTest < Minitest::Test
  FIXTURES = File.join(__dir__, 'fixtures/constant_occurrences')
  # path, line, exact target, immediate syntactic role, lexical owning fact
  SITES = [
    ['sites.rb', 3, 'CoreModel', 'value', 'Workshop::Screen'],
    ['sites.rb', 5, 'CoreModel', 'argument', 'Workshop::Screen#render'],
    ['sites.rb', 6, 'CoreModel', 'argument', 'Workshop::Screen#render'],
    ['sites.rb', 7, 'CoreModel', 'value', 'Workshop::Screen#render'],
    ['sites.rb', 8, 'CoreModel', 'value', 'Workshop::Screen#render'],
    ['sites.rb', 9, 'CoreModel', 'value', 'Workshop::Screen#render'],
    ['sites.rb', 10, 'Kit::Button', 'value', 'Workshop::Screen#render'],
    ['sites.rb', 11, '::Kit::Button', 'value', 'Workshop::Screen#render'],
    ['sites.rb', 12, 'Other::CoreModel', 'value', 'Workshop::Screen#render'],
    ['sites.rb', 13, '::CoreModel', 'value', 'Workshop::Screen#render'],
    ['sites.rb', 14, 'CoreModel', 'predicate', 'Workshop::Screen#render'],
    ['sites.rb', 19, 'ErrorType', 'rescue_class', 'Workshop::Screen#render'],
    ['sites.rb', 20, 'CoreModel', 'value', 'Workshop::Screen#render'],
    ['file.rb', 1, 'CoreModel', 'value', 'file.rb'],
    ['file.rb', 3, 'CoreModel', 'value', 'file.rb'],
    ['negative.rb', 3, 'Other::CoreModel', 'value', 'negative.rb']
  ].freeze

  def with_capture
    Dir.mktmpdir do |dir|
      root = File.realpath(dir)
      input = File.join(root, 'input')
      FileUtils.cp_r(FIXTURES, input)
      bytes = Dir.children(input).to_h { |name| [name, File.binread(File.join(input, name))] }
      store = File.join(root, 'store')
      generation = Thistle.capture(root: input, output: store).fetch('generation')
      reader = Thistle::Reader.new(store, generation: generation)
      begin
        yield reader, input, store, generation, bytes
      ensure
        reader.close
      end
    end
  end

  def pages(reader, id, **options)
    rows = []
    cursor = nil
    100.times do
      page = reader.references(id, **options, limit: 1, cursor: cursor)
      rows.concat(page.fetch(options.key?(:candidate_link) ? 'candidates' : 'relationships'))
      cursor = page.fetch('next_cursor')
      return [rows, page] unless cursor
    end
    flunk 'reference continuation did not terminate within the tiny fixture domain'
  end

  def test_exact_saved_occurrences_and_existing_receiver_group_remain_distinct
    with_capture do |reader, _input, _store, generation, bytes|
      occurrences = reader.facts.flat_map do |fact|
        rows, = pages(reader, fact.fetch('id'))
        rows.select { |row| row.dig('link', 'relation') == 'references_constant' }
      end
      actual = occurrences.map do |row|
        meta = row.dig('link', 'attributes', 'thistle_constant')
        path = row.dig('origin', 'path')
        location = meta.fetch('location')
        syntax = meta.fetch('syntax')
        assert_equal syntax, bytes.fetch(path).byteslice(location[0]...location[1])
        assert_equal syntax.start_with?('::'), meta.fetch('rooted')
        assert_equal(path == 'sites.rb' ? 'Workshop::Screen' : nil, meta.fetch('lexical_scope'))
        assert_equal generation, reader.source(row.dig('origin', 'id')).fetch('generation')
        [path, location[2], row.dig('link', 'target'), meta.fetch('role'), row.dig('origin', 'name')]
      end
      assert_equal SITES.sort, actual.sort
      assert_equal occurrences.length, occurrences.map { |r| [r.dig('origin', 'id'), r.dig('link', 'attributes', 'thistle_constant', 'location')] }.uniq.length
      button = reader.find('Kit::Button').find { |f| f['kind'] == 'class' }
      incoming, = pages(reader, button.fetch('id'), direction: 'incoming')
      assert_equal 2, incoming.count { |r| r.dig('link', 'relation') == 'references_constant' }
      calls = incoming.select { |r| r.dig('link', 'relation') == 'calls' }
      assert_equal 1, calls.length
      call = calls.first.dig('link', 'attributes', 'thistle_call', 'data')
      assert_equal 'Kit::Button.new(:receiver_regression)', bytes.fetch('sites.rb').byteslice(call[4][0]...call[4][1])
      kit = reader.find('Kit').find { |f| f['name'] == 'Kit' && f['kind'] == 'module' }
      assert_empty pages(reader, kit.fetch('id'), direction: 'incoming').first
    end
  end

  def test_rooted_pages_late_ambiguity_and_saved_source_stay_generation_pinned
    with_capture do |reader, input, store, generation, bytes|
      model = reader.find('CoreModel').find { |f| f['name'] == 'CoreModel' && f['kind'] == 'class' }
      incoming, last = pages(reader, model.fetch('id'), direction: 'incoming')
      assert last.dig('coverage', 'scan_complete')
      assert_equal 11, incoming.count { |r| r.dig('link', 'relation') == 'references_constant' }
      refute incoming.any? { |r| r.dig('link', 'target') == 'Other::CoreModel' }
      row = incoming.find { |r| r.dig('link', 'target') == '::CoreModel' }
      origin = row.fetch('origin')
      # Outgoing candidate lookup must see all six distinct declarations, even
      # though the inline candidate prefix is capped at four.
      outgoing, = pages(reader, origin.fetch('id'))
      rooted = outgoing.find { |r| r.dig('link', 'target') == '::CoreModel' }
      assert_equal 6, rooted.fetch('candidate_matches')
      File.binwrite(File.join(input, 'sites.rb'), "# changed live source\n")
      refute_equal generation, Thistle.capture(root: input, output: store).fetch('generation')
      pinned = Thistle::Reader.new(store, generation: generation)
      begin
        candidates, page = pages(pinned, origin.fetch('id'), candidate_link: rooted.fetch('link_ordinal'))
        assert_equal 'ambiguous', page.fetch('candidate_status')
        assert_equal 6, candidates.map { |c| c.fetch('id') }.uniq.length
        source = pinned.source(origin.fetch('id'))
        assert_equal generation, source.fetch('generation')
        assert_equal bytes.fetch('sites.rb'), source.fetch('content')
        assert_equal Digest::SHA256.hexdigest(bytes.fetch('sites.rb')), source.fetch('sha256')
        assert_equal incoming, pages(pinned, model.fetch('id'), direction: 'incoming').first
      ensure
        pinned.close
      end
    end
  end

  def test_extra_sites_refuse_without_changing_current
    Dir.mktmpdir do |dir|
      root = File.realpath(dir)
      input = File.join(root, 'input')
      FileUtils.mkdir_p(input)
      path = File.join(input, 'body.rb')
      File.binwrite(path, "CoreModel\n")
      store = File.join(root, 'store')
      generation = Thistle.capture(root: input, output: store).fetch('generation')
      File.binwrite(path, "CoreModel; CoreModel\n")
      assert_raises(Thistle::LimitExceeded) { Thistle.capture(root: input, output: store, limits: { max_links: 1 }) }
      reader = Thistle::Reader.new(store)
      begin
        fact = reader.find('body.rb').first
        assert_equal generation, reader.source(fact.fetch('id')).fetch('generation')
        assert_equal "CoreModel\n", reader.source(fact.fetch('id')).fetch('content')
      ensure
        reader.close
      end
    end
  end
end
