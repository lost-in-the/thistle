# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'thistle'
require 'json'
require 'stringio'
require 'thistle/cli'
require_relative 'fixtures/recorded_domain/capture'

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
        assert_equal outgoing.fetch('relationships'), reader.references(method.fetch('id')).fetch('relationships')
        assert_raises(Thistle::InvalidInput) { reader.references(user.fetch('id'), direction: 'sideways') }
        assert_raises(Thistle::InvalidInput) { reader.references(user.fetch('id'), limit: 0) }
      ensure
        reader.close
      end
      assert_raises(Thistle::Error) { reader.references(user.fetch('id')) }
    end
  end

  def test_public_pages_reach_fact_and_link_past_old_bounds_with_global_ambiguity
    Dir.mktmpdir do |dir|
      capture, model_id = RecordedDomainFixture.capture
      store = Thistle::Store.new(dir)
      generation = store.publish(capture).fetch('generation')
      reader = Thistle::Reader.new(dir, generation: generation)
      begin
        first = reader.references(RecordedDomainFixture::ANCHOR, direction: 'incoming', limit: 10)
        assert_equal 20_000, first.dig('coverage', 'facts_scanned')
        refute first.dig('coverage', 'scan_complete')
        assert_empty first.fetch('relationships')
        capture['facts'][1]['name'] = 'RecordedDomain::CurrentChanged'
        refute_equal generation, store.publish(capture).fetch('generation')
        cursor = first.fetch('next_cursor')
        seen_cursors = [cursor]
        pairs = []
        # Fresh CLI Readers use the original generation after CURRENT changes.
        4.times do
          out, err = StringIO.new, StringIO.new
          status = Thistle::CLI.new(out: out, err: err).run(['references', RecordedDomainFixture::ANCHOR,
            '--store', dir, '--generation', generation, '--direction', 'incoming', '--limit', '10', '--cursor', cursor])
          assert_equal 0, status, err.string
          page = JSON.parse(out.string)
          assert_equal generation, page.fetch('generation')
          assert page.dig('coverage', 'capture_partial')
          page.fetch('relationships').each { |row| pairs << [row.dig('origin', 'id'), row.fetch('link_ordinal')] }
          cursor = page.fetch('next_cursor')
          break unless cursor
          refute_includes seen_cursors, cursor
          seen_cursors << cursor
        end
        assert_nil cursor, 'finite traversal must exhaust the saved domain'
        assert_includes pairs, [RecordedDomainFixture::ORIGIN, 50_000]
        assert_equal pairs.uniq, pairs
        expected = capture.fetch('facts').flat_map do |fact|
          fact.fetch('links').each_with_index.filter_map { |link, index| [fact.fetch('id'), index] if link['target'] == RecordedDomainFixture::NAME }
        end
        assert_equal expected.sort, pairs.sort
        # The far-end static duplicate and two registries all affect the global
        # count, even on the first one-item candidate page.
        ids, token = [], nil
        6.times do
          page = reader.references(RecordedDomainFixture::ORIGIN, candidate_link: 50_000, limit: 1, cursor: token)
          assert_equal 'ambiguous', page.fetch('candidate_status')
          assert_equal 5, page.fetch('candidate_matches')
          ids.concat(page.fetch('candidates').map { |item| item.fetch('id') })
          token = page.fetch('next_cursor')
          break unless token
        end
        assert_nil token
        assert_equal 5, ids.uniq.length
        assert_includes ids, RecordedDomainFixture::LATE
        brief = reader.model_brief(model_id, limit: 1)
        assert_equal 'ambiguous', brief.dig('families', 'registry_candidates', 'status')
        refute_empty brief.dig('families', 'columns', 'items')
        assert_equal 'references', brief.dig('families', 'incoming', 'followup', 'operation')
        registry_ids, token = [], nil
        3.times do
          page = reader.model_brief(model_id, family: 'registry_candidates', limit: 1, cursor: token)
          assert_equal 'ambiguous', page.dig('result', 'status')
          registry_ids.concat(page.dig('result', 'items').map { |item| item.fetch('id') })
          token = page.fetch('next_cursor')
          break unless token
        end
        assert_nil token
        assert_equal 2, registry_ids.uniq.length
        latest = Thistle::Reader.new(dir)
        begin
          assert_raises(Thistle::InvalidInput) do
            latest.references(RecordedDomainFixture::ANCHOR, direction: 'incoming', cursor: first.fetch('next_cursor'))
          end
        ensure
          latest.close
        end
      ensure
        reader.close
      end
    end
  end
end
