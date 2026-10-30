# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'json'
require 'stringio'
require 'thistle'
require 'thistle/cli'

# Runnable against installed Core by copying this file and its fixture outside
# the checkout; no source load path.
class ThistleRootQualifiedReferencesTest < Minitest::Test
  FIXTURE = File.expand_path('fixtures/root_qualified_references', __dir__)
  CALLERS = %w[PlainCaller#perform RootCaller#perform Other::NestedCaller#perform].freeze

  def test_saved_rooted_callers_and_candidate_pages_survive_current_change
    Dir.mktmpdir do |dir|
      root, store = File.join(dir, 'input'), File.join(dir, 'store')
      FileUtils.cp_r(FIXTURE, root)
      generation = Thistle.capture(root: root, output: store).fetch('generation')
      reader = Thistle::Reader.new(store, generation: generation)
      begin
        widgets = reader.find('Widget').select { |fact| fact['kind'] == 'class' && fact['name'] == 'Widget' }
        assert_equal 2, widgets.length
        assert_equal 2, widgets.map { |fact| fact.fetch('id') }.uniq.length
        widget = widgets.first
        shop = reader.find('Shop::Widget').find { |fact| fact['kind'] == 'class' && fact['name'] == 'Shop::Widget' }
        rooted = reader.find('RootCaller#perform').find { |fact| fact['name'] == 'RootCaller#perform' }
        old_fact = reader.fact(rooted.fetch('id'))
        old_links = reader.links(rooted.fetch('id'))
        first = reader.references(widget.fetch('id'), direction: 'incoming', limit: 1)
        assert_equal 1, first.fetch('relationships').length
        refute_nil first.fetch('next_cursor'), 'the other rooted callers must remain reachable'
        assert first.dig('coverage', 'not_searched')
        first.fetch('relationships').each { |row| assert_equal 'label_match_binding_unknown', row.fetch('match_basis') }

        outgoing = reader.references(rooted.fetch('id'))
        row = outgoing.fetch('relationships').find { |item| item['candidate_label'] == '::Widget' }
        assert_equal 2, row.fetch('candidate_matches')
        assert row.fetch('candidate_search_complete')
        assert_equal widgets.map { |item| item.fetch('id') }.sort, row.fetch('candidates').map { |item| item.fetch('id') }.sort
        assert_equal old_links.fetch(row.fetch('link_ordinal')), row.fetch('link')
        source = reader.source(rooted.fetch('id'))
        bytes = File.binread(File.join(FIXTURE, 'callers.rb'))
        assert_equal bytes, source.fetch('content')
        assert_equal Digest::SHA256.hexdigest(bytes), source.fetch('sha256')
        receiver = row.dig('link', 'attributes', 'thistle_call', 'data')
        assert_equal 'constant', receiver.fetch(0)
        assert_equal '::Widget', receiver.fetch(1)
        start_byte, end_byte = receiver.fetch(5)
        assert_equal '::Widget', bytes.byteslice(start_byte...end_byte)
        candidates = reader.references(rooted.fetch('id'), candidate_link: row.fetch('link_ordinal'), limit: 1)
        assert_equal 'ambiguous', candidates.fetch('candidate_status')
        refute_nil candidates.fetch('next_cursor')

        File.write(File.join(root, 'callers.rb'), "class Changed; end\n")
        refute_equal generation, Thistle.capture(root: root, output: store).fetch('generation')
        # CLI opens fresh Readers pinned to the old generation, with no rewrite.
        rows = first.fetch('relationships') + cli_pages(widget.fetch('id'), store, generation,
          direction: 'incoming', cursor: first.fetch('next_cursor')).flat_map { |page| page.fetch('relationships') }
        assert_equal CALLERS.sort, rows.map { |item| item.dig('origin', 'name') }.sort
        assert_equal 3, rows.map { |item| [item.dig('origin', 'id'), item.fetch('link_ordinal')] }.uniq.length
        assert rows.all? { |item| item['match_basis'] == 'label_match_binding_unknown' }
        assert rows.any? { |item| item['candidate_label'] == '::Widget' }

        remaining = cli_pages(rooted.fetch('id'), store, generation,
          candidate_link: row.fetch('link_ordinal'), cursor: candidates.fetch('next_cursor'))
        ids = candidates.fetch('candidates').map { |item| item.fetch('id') } +
          remaining.flat_map { |page| page.fetch('candidates').map { |item| item.fetch('id') } }
        assert_equal widgets.map { |item| item.fetch('id') }.sort, ids.sort
        assert remaining.all? { |page| page['candidate_status'] == 'ambiguous' && page['candidate_matches'] == 2 }
        reopened = Thistle::Reader.new(store, generation: generation)
        begin
          assert_equal old_fact, reopened.fact(rooted.fetch('id'))
          assert_equal old_links, reopened.links(rooted.fetch('id'))
          assert_equal source, reopened.source(rooted.fetch('id'))
          namespaced = reopened.references(shop.fetch('id'), direction: 'incoming')
          assert_equal %w[RootShopCaller#perform ShopCaller#perform], namespaced.fetch('relationships').map { |item| item.dig('origin', 'name') }.sort
          shop_origin = reader.find('RootShopCaller#perform').find { |fact| fact['name'] == 'RootShopCaller#perform' }
          shop_row = reopened.references(shop_origin.fetch('id')).fetch('relationships').find { |item| item['candidate_label'] == '::Shop::Widget' }
          assert_equal [shop.fetch('id')], shop_row.fetch('candidates').map { |item| item.fetch('id') }
          assert_equal 'unresolved', shop_row.dig('link', 'resolution')
        ensure
          reopened.close
        end
        current = Thistle::Reader.new(store)
        begin
          assert_raises(Thistle::InvalidInput) do
            current.references(widget.fetch('id'), direction: 'incoming', cursor: first.fetch('next_cursor'))
          end
        ensure
          current.close
        end
      ensure
        reader.close
      end
    end
  end

  private

  def cli_pages(id, store, generation, direction: nil, candidate_link: nil, cursor:)
    pages, seen = [], []
    8.times do
      refute_includes seen, cursor
      seen << cursor
      args = ['references', id, '--store', store, '--generation', generation, '--limit', '1', '--cursor', cursor]
      args.concat(['--direction', direction]) if direction
      args.concat(['--candidate-link', candidate_link.to_s]) if candidate_link
      out, err = StringIO.new, StringIO.new
      assert_equal 0, Thistle::CLI.new(out: out, err: err).run(args), err.string
      page = JSON.parse(out.string)
      assert_equal generation, page.fetch('generation')
      pages << page
      cursor = page.fetch('next_cursor')
      return pages unless cursor
    end
    flunk 'tiny rooted-reference domain did not exhaust within eight pages'
  end
end
