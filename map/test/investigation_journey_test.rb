# frozen_string_literal: true

# Real Reader/capture regression. Authored here; run only in an admitted native
# Map lane after composing the supporting Core compact-identity seam.
require_relative 'test_helper'
require 'cgi'

class InvestigationJourneyTest < Minitest::Test
  include MapTestSupport

  def test_reopened_collection_and_source_keep_saved_generation_after_current_advances
    Dir.mktmpdir('thistle-investigation-') do |directory|
      root, store = %w[source store].map { |part| File.join(directory, part) }
      FileUtils.mkdir_p(root)
      File.binwrite(File.join(root, 'selected.rb'), "class SavedChoice\n  def saved = :old_evidence\nend\n")
      saved = Thistle.capture(root: root, output: store).fetch('generation')
      reader = Thistle::Reader.new(store, generation: saved)
      begin
        selected = reader.find('SavedChoice#saved').fetch(0).fetch('id')
      ensure
        reader.close
      end
      app = Thistle::Map::App.new(store: store)
      selection = Thistle::Map::Investigation.new(generation: saved, ids: [selected, '0' * 64])
      uri = URI.parse(selection.url)
      code, _, first = request(app, uri.path, query: uri.query)
      assert_equal 200, code
      assert_includes first, 'Missing selection'
      File.binwrite(File.join(root, 'selected.rb'), "class NewChoice; end\n")
      current = Thistle.capture(root: root, output: store).fetch('generation')
      refute_equal saved, current
      code, _, reopened = request(app, uri.path, query: uri.query)
      assert_equal 200, code
      assert_equal first, reopened
      source_href = reopened.scan(/href="([^"]+)"/).flatten.map { |href| CGI.unescapeHTML(href) }.find { |href| href.start_with?('/source?') }
      source = URI.parse(source_href)
      code, _, html = request(app, source.path, query: source.query)
      assert_equal 200, code
      assert_includes html, 'old_evidence'
      refute_includes html, 'NewChoice'
      assert_includes html, 'Remove from investigation'
      assert_includes html, "selection=#{selected}%2C#{'0' * 64}"
      assert_equal 400, request(app, '/investigation', query: "selection=#{selected}").first
      assert_equal 404, request(app, '/investigation', query: "generation=#{'f' * 64}&selection=#{selected}").first
    end
  end
end
