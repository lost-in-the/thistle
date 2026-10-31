# frozen_string_literal: true

require_relative 'test_helper'
require 'uri'
require 'cgi'

class MapConstantOccurrenceJourneyTest < Minitest::Test
  include MapTestSupport

  def test_same_target_sites_follow_their_saved_source_after_current_and_live_file_change
    Dir.mktmpdir('map-constant-sites-') do |directory|
      root = File.join(directory, 'input')
      store = File.join(directory, 'store')
      FileUtils.mkdir_p(root)
      followed_pages = []
      original = "class Widget; end\nclass Demo\n  def work\n    take(Widget)\n    other = Widget\n  end\nend\n"
      File.write(File.join(root, 'demo.rb'), original)
      saved = Thistle.capture(root: root, output: store).fetch('generation')
      reader = Thistle::Reader.new(store, generation: saved)
      begin
        origin = reader.find('Demo#work').find { |fact| fact['name'] == 'Demo#work' }
        widget = reader.find('Widget').find { |fact| fact['name'] == 'Widget' && fact['kind'] == 'class' }
        sites = reader.links(origin.fetch('id')).select { |link| link['relation'] == 'references_constant' }
        assert_equal 2, sites.length
        assert_equal ['Widget'], sites.map { |link| link.fetch('target') }.uniq
        assert_equal [4, 5], sites.map { |link| link.dig('attributes', 'thistle_constant', 'location', 2) }.sort
      ensure
        reader.close
      end
      app = make_real_app(store)
      incoming_query = URI.encode_www_form('generation' => saved, 'id' => widget.fetch('id'), 'direction' => 'incoming')
      status, _, html = request(app, '/links', query: incoming_query, env: { 'SCRIPT_NAME' => '/map' })
      assert_equal 200, status
      assert_equal 2, html.scan('class="constant-site"').length
      assert_includes html, 'Role: argument'
      assert_includes html, 'Role: value'
      assert_includes html, '<noscript>'
      assert_includes html, 'Binding unknown'
      hrefs = html.scan(/href="([^"]+#L[45])"/).flatten.map { |href| CGI.unescapeHTML(href) }.uniq
      assert_equal 2, hrefs.length
      assert_equal %w[L4 L5], hrefs.map { |href| URI.parse(href).fragment }.sort
      refute_match(/onclick=/, html)
      File.write(File.join(root, 'demo.rb'), "class Replacement; end\n")
      current = Thistle.capture(root: root, output: store).fetch('generation')
      refute_equal saved, current
      hrefs.each do |href|
        uri = URI.parse(href)
        params = URI.decode_www_form(uri.query).to_h
        assert_equal saved, params.fetch('generation')
        assert_equal origin.fetch('id'), params.fetch('id')
        status, _, source = request(app, uri.path.delete_prefix('/map'), query: uri.query, env: { 'SCRIPT_NAME' => '/map' })
        assert_equal 200, status
        assert_includes source, "id=\"#{uri.fragment}\""
        assert_includes source, Digest::SHA256.hexdigest(original)
        refute_includes source, 'Replacement'
        followed_pages << { 'href' => href, 'status' => status, 'html' => source }
      end
      status, _, outgoing = request(app, '/links', query: URI.encode_www_form('generation' => saved, 'id' => origin.fetch('id')))
      assert_equal 200, status
      assert_includes outgoing, 'Line 4 · Role: argument'
      assert_includes outgoing, 'Line 5 · Role: value'
      assert_equal 403, request(app, '/links', query: incoming_query, env: { 'REMOTE_ADDR' => '192.0.2.1' }).first
    ensure
      # Optional finite-run evidence: preserve even an unsuccessful new journey
      # before this test's disposable directory is removed. No installed data is
      # consulted; all source and captures here are the tiny public fixture above.
      if (evidence = ENV['THISTLE_MAP_JOURNEY_EVIDENCE'])
        raise 'Private evidence directory required' unless (File.stat(evidence).mode & 0o777) == 0o700
        File.open(File.join(evidence, 'journey.json'), File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.write(JSON.pretty_generate('saved' => saved, 'current' => current, 'origin' => origin,
            'sites' => sites, 'source_sha256' => original && Digest::SHA256.hexdigest(original),
            'incoming_html' => html, 'outgoing_html' => outgoing, 'followed_pages' => followed_pages))
        end
        FileUtils.cp_r(store, File.join(evidence, 'store')) if store && File.directory?(store)
      end
    end
  end

  private

  def make_real_app(store)
    Thistle::Map::App.new(store: store)
  end
end
