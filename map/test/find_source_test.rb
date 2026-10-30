# frozen_string_literal: true
require_relative 'test_helper'
require 'cgi'
require_relative '../../test/fixtures/find_models'

class FindSourceTest < Minitest::Test
  include MapTestSupport
  def test_saved_model_find_to_model_and_reference_source_after_current_advances
    Dir.mktmpdir('map-find-models') do |dir|
      root, store = File.join(dir, 'source'), File.join(dir, 'store')
      first = SavedFindModels.publish(root: root, store: store)
      File.write(File.join(root, 'order.rb'), "class Replacement; end\n")
      refute_equal first.fetch('generation'), Thistle.capture(root: root, output: store).fetch('generation')
      reader = Thistle::Reader.new(store, generation: first.fetch('generation'))
      begin
        payment_id = reader.find('Payment').find { |fact| fact['kind'] == 'class' }.fetch('id')
      ensure
        reader.close
      end
      app = Thistle::Map::App.new(store: store)
      %w[state payments].each do |query|
        status, _, html = request(app, '/', query: URI.encode_www_form(
          'q' => query, 'domain' => 'metadata', 'kind' => 'rails_model', 'generation' => first.fetch('generation')))
        assert_equal 200, status
        family = query == 'state' ? 'columns' : 'associations'
        assert_includes html, "attributes.model.#{family}.entries[].name"
        assert_includes html, 'Saved model inventory: partial'
        links = html.scan(/data-result-link href="([^"]+)"/).flatten
        assert_equal 2, links.length
        source = URI.parse(CGI.unescapeHTML(links.first))
        params = URI.decode_www_form(source.query).to_h
        assert_equal first.fetch('generation'), params.fetch('generation')
        status, _, model = request(app, source.path, query: source.query)
        assert_equal 200, status
        assert_includes model, 'No file or line was captured'
        assert_includes model, 'payments'
        assert_includes model, 'unknown'
        status, _, references = request(app, '/links', query: URI.encode_www_form(params.slice('generation', 'id')))
        assert_equal 200, status
        assert_includes references, 'Payment'
        assert_includes references, 'binding unknown'
        destination = references.scan(/href="([^"]+)"/).flatten.map { |href| URI.parse(CGI.unescapeHTML(href)) }.find do |uri|
          uri.path == '/source' && uri.query && URI.decode_www_form(uri.query).to_h['id'] == payment_id
        end
        refute_nil destination
        assert_equal first.fetch('generation'), URI.decode_www_form(destination.query).to_h.fetch('generation')
        status, _, saved_source = request(app, destination.path, query: destination.query)
        assert_equal 200, status
        displayed = CGI.unescapeHTML(saved_source.gsub(/<[^>]+>/, ''))
        assert_includes displayed, 'class Payment'
        refute_includes displayed, 'class Replacement'
      end
    end
  end

  class FileReader < MapTestSupport::Reader
    attr_reader :closed, :queries
    CONTENT = "# é\n<script>literal</script>\n"
    def initialize(path: 'spec/file.rb')
      super()
      @path = path
      @manifest['files'] = [{ 'path' => path, 'bytes' => CONTENT.bytesize,
        'sha256' => Digest::SHA256.hexdigest(CONTENT) }]
    end
    def search_evidence(query, **filters)
      @queries = [query, filters]
      { 'generation' => generation, 'version' => 1, 'status' => 'complete', 'truncated' => false,
        'results' => [{ 'origin' => 'source', 'path' => @path, 'snippet' => '<script>literal</script>', 'span' => { 'start_line' => 2 } }] }
    end
    def source_file(path)
      raise Thistle::NotFound unless path == @path
      hash = Digest::SHA256.hexdigest(CONTENT)
      { 'generation' => generation, 'file' => { 'path' => path, 'bytes' => CONTENT.bytesize, 'sha256' => hash }, 'sha256' => hash, 'content' => CONTENT }
    end
    def close = @closed = true
  end
  def test_find_to_generation_pinned_file_source_without_fact_owner
    reader = FileReader.new
    app = make_app(reader)
    status, _, html = request(app, '/', query: 'q=literal&domain=source&kind=file&prefix=spec%2F')
    assert_equal 200, status
    assert_equal({ limit: 50, kind: 'file', path: 'spec/', domain: 'source' }, reader.queries.last)
    assert_includes html, "generation=#{GENERATION}&amp;file=#{Thistle::Map::FindPresenter.file_reference('spec/file.rb')}&amp;q=literal"
    assert_includes html, '&lt;script&gt;literal&lt;/script&gt;'
    link = URI.parse(CGI.unescapeHTML(html[/data-result-link href="([^"]+)"/, 1]))
    context = { 'q' => 'literal', 'domain' => 'source', 'kind' => 'file', 'prefix' => 'spec/' }
    assert_equal context, URI.decode_www_form(link.query).to_h.slice(*context.keys)
    status, _, source = request(app, link.path, query: link.query)
    assert_equal 200, status
    assert_includes source, 'id="L2"'
    assert_includes source, 'No declaration owner'
    navigation = source[/<nav aria-label="Evidence views">(.*?)<\/nav>/m, 1]
    navigation.scan(/href="([^"]+)"/).flatten.each do |href|
      target = URI.parse(CGI.unescapeHTML(href))
      params = URI.decode_www_form(target.query).to_h
      assert_equal context, params.slice(*context.keys)
      refute params.key?('path')
      assert_equal target.path == '/source', params.key?('file')
      assert_equal 200, request(app, target.path, query: target.query).first
    end
    assert_includes source, 'value="literal"'
    assert_includes source, 'value="spec/"'
    assert reader.closed
  end
  def test_long_unicode_path_follows_a_bounded_manifest_reference
    path = ([('é' * 100)] * 7).join('/') + '.rb'
    assert_operator URI.encode_www_form('generation' => GENERATION, 'path' => path).bytesize, :>, Thistle::Map::App::MAX_QUERY_BYTES
    reader = FileReader.new(path: path)
    app = make_app(reader)
    status, _, html = request(app, '/', query: 'q=literal&domain=source')
    assert_equal 200, status
    link = URI.parse(CGI.unescapeHTML(html[/data-result-link href="([^"]+)"/, 1]))
    assert_operator link.query.bytesize, :<=, Thistle::Map::App::MAX_QUERY_BYTES
    assert_equal 'L2', link.fragment
    status, _, source = request(app, link.path, query: link.query)
    assert_equal 200, status
    assert_includes source, path
    assert_includes source, 'id="L2"'
    source.scan(/href="([^"]+)"/).flatten.each do |href|
      target = URI.parse(CGI.unescapeHTML(href))
      next unless target.query
      assert_operator target.query.bytesize, :<=, Thistle::Map::App::MAX_QUERY_BYTES
      refute URI.decode_www_form(target.query).to_h.key?('path')
      assert_equal 200, request(app, target.path, query: target.query).first
    end
    assert reader.closed
    query = "generation=#{GENERATION}&file=#{'f' * 64}"
    assert_equal 404, request(app, '/source', query: query).first
    assert_equal 400, request(app, '/source', query: "#{query}&path=spec%2Ffile.rb").first
    assert_equal 400, request(app, '/source', query: "file=#{'f' * 64}").first
    assert_equal 400, request(app, '/source', query: "generation=#{GENERATION}&file=bad").first
  end
  def test_file_source_preserves_access_method_generation_and_path_gates
    app = make_app(FileReader.new)
    query = "generation=#{GENERATION}&path=spec%2Ffile.rb"
    assert_equal 403, request(app, '/source', query: query, env: { 'REMOTE_ADDR' => '192.0.2.1' }).first
    assert_equal 405, request(app, '/source', query: query, method: 'POST').first
    assert_equal 400, request(app, '/source', query: 'path=spec%2Ffile.rb').first
    assert_equal 400, request(app, '/source', query: "#{query}&id=#{FACT_ID}").first
    assert_equal 400, request(app, '/source', query: "generation=#{GENERATION}&path=..%2Fsecret").first
    assert_equal 404, request(app, '/source', query: "generation=#{GENERATION}&path=absent.rb").first
  end

  def test_near_limit_search_keeps_navigation_valid_and_explains_context_fallback
    prefix = 'x' * 4015
    query = URI.encode_www_form('q' => 'x', 'prefix' => prefix)
    assert_operator query.bytesize, :<=, Thistle::Map::App::MAX_QUERY_BYTES
    app = make_app(FileReader.new)
    status, _, html = request(app, '/', query: query)
    assert_equal 200, status
    assert_includes html, 'Search context exceeds the navigation link budget'
    assert_includes html, "value=\"#{prefix}\""
    html.scan(/href="([^"]+)"/).flatten.each do |href|
      target = URI.parse(CGI.unescapeHTML(href))
      next unless target.query
      assert_operator target.query.bytesize, :<=, Thistle::Map::App::MAX_QUERY_BYTES
      assert_equal GENERATION, URI.decode_www_form(target.query).to_h['generation']
      assert_equal 200, request(app, target.path, query: target.query).first
    end
  end
  def test_file_source_caps_and_identity_fail_closed_with_cleanup
    reader = FileReader.new
    def reader.source_file(path)
      result = super
      result['content'] = 'x' * (Thistle::Map::View::MAX_SOURCE_BYTES + 1)
      result
    end
    query = "generation=#{GENERATION}&path=spec%2Ffile.rb"
    assert_equal 422, request(make_app(reader), '/source', query: query).first
    assert reader.closed
    corrupt = FileReader.new
    def corrupt.source_file(path)
      super.merge('sha256' => 'f' * 64)
    end
    assert_equal 422, request(make_app(corrupt), '/source', query: query).first
    assert corrupt.closed
  end

end
