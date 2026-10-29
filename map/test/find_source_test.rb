# frozen_string_literal: true
require_relative 'test_helper'

class FindSourceTest < Minitest::Test
  include MapTestSupport
  class FileReader < MapTestSupport::Reader
    attr_reader :closed, :queries
    CONTENT = "# é\n<script>literal</script>\n"
    def search_evidence(query, **filters)
      @queries = [query, filters]
      { 'generation' => generation, 'version' => 1, 'status' => 'complete', 'truncated' => false,
        'results' => [{ 'origin' => 'source', 'path' => 'spec/file.rb', 'snippet' => '<script>literal</script>', 'span' => { 'start_line' => 2 } }] }
    end
    def source_file(path)
      raise Thistle::NotFound unless path == 'spec/file.rb'
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
    assert_includes html, "generation=#{GENERATION}&amp;path=spec%2Ffile.rb#L2"
    assert_includes html, '&lt;script&gt;literal&lt;/script&gt;'
    status, _, source = request(app, '/source', query: "generation=#{GENERATION}&path=spec%2Ffile.rb")
    assert_equal 200, status
    assert_includes source, 'id="L2"'
    assert_includes source, 'No declaration owner'
    assert reader.closed
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
