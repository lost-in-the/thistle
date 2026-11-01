# frozen_string_literal: true

# Correction App probes AUTHORED UNRUN in this source-only phase.
# Root owns their later execution; this author runs only syntax on this file.
if $PROGRAM_NAME == __FILE__
  require_relative 'model_neighborhood_presenter_test'
  $LOADED_FEATURES << File.expand_path('../lib/thistle/map/highlighter.rb', __dir__)
  module Thistle
    module Map
      module Highlighter
        def self.lines(*) = raise('Unexpected source expansion')
      end
    end
  end
  require_relative '../lib/thistle/map/app'
  raise 'Mock App activated Native or Rails' if defined?(Thistle::Native) || defined?(Rails) || defined?(ActiveRecord)
  class ModelNeighborhoodAppTest < Minitest::Test
    class Reader < ModelNeighborhoodAnswers::BudgetReader
      attr_reader :closed, :generation, :manifest
      def initialize(mode)
        super()
        @mode, @generation, @manifest = mode, ModelNeighborhoodAnswers::G, { 'files' => [], 'coverage' => [] }
      end
      def model_neighborhood(id, **options)
        if %i[busy invalid overflow].include?(@mode)
          @calls << options
          raise Thistle::Busy, 'busy' if @mode == :busy
          raise Thistle::InvalidSnapshot, 'invalid' if @mode == :invalid
          raise Thistle::LimitExceeded, 'First selected native row exceeds max_bytes'
        end
        super
      end
      def close = @closed = true
    end
    def setup
      @readers, @mode = [], :normal
      @app = Thistle::Map::App.new(store: 'mock-only', reader_factory: ->(*) { Reader.new(@mode).tap { |r| @readers << r } })
    end
    def request(extra = {}, method: 'GET', host: 'localhost', path: '/model-neighborhood/edges/outgoing/all')
      @app.call('REQUEST_METHOD' => method, 'PATH_INFO' => path, 'QUERY_STRING' => URI.encode_www_form({ 'generation' => ModelNeighborhoodAnswers::G, 'id' => ModelNeighborhoodAnswers::ID }.merge(extra)),
        'HTTP_HOST' => host, 'REMOTE_ADDR' => '127.0.0.1', 'SCRIPT_NAME' => '')
    end
    def test_one_reader_operation_close_head_and_typed_error_propagation
      status, headers, body = request
      assert_equal 200, status
      assert_includes body.join, 'Named relationships'
      assert_equal 1, @readers.last.calls.length
      assert @readers.last.closed
      assert_includes headers['content-security-policy'], "default-src 'none'"
      status, _, body = request(method: 'HEAD')
      assert_equal 200, status
      assert_empty body
      assert @readers.last.closed
      @mode = :busy
      status, headers, = request
      assert_equal 503, status
      assert_equal '1', headers['retry-after']
      assert @readers.last.closed
      @mode = :invalid
      status, _, body = request
      assert_equal 422, status
      assert_includes body.join, 'missing or invalid'
      @mode = :overflow
      status, _, body = request
      assert_equal 422, status
      assert_includes body.join, 'Model neighborhood display limit'
      refute_includes body.join, 'missing or invalid'
      assert @readers.last.closed
    end
    def test_invalid_scope_and_access_refuse_before_reader_factory
      require_relative 'model_neighborhood_navigation_test'
      cursor = ModelNeighborhoodNavigationTest.new('unused').token
      assert_equal 400, request({ 'cursor' => cursor }, path: '/model-neighborhood/edges/incoming/all').first
      assert_equal 400, request({ 'action' => 'c' * 64 }).first
      assert_equal 400, request({ 'candidate' => 'a:0' }).first
      assert_equal 403, request(host: 'foreign.invalid').first
      assert_equal 405, request(method: 'POST').first
      assert_empty @readers
    end
    def test_realistic_budget_enforcing_24_ids_256q_must_render_200
      selected = (1..24).map { |n| n.to_s(16).rjust(64, '0') }.join(',')
      cases = { '/model-neighborhood/edges/outgoing/all' => {},
        '/model-neighborhood/edges/incoming/association' => {},
        '/model-neighborhood/edges/incoming/reference' => {},
        '/model-neighborhood/columns/outgoing/all' => {},
        '/model-neighborhood/candidates/outgoing/all' => { 'candidate' => 'a:0' },
        '/model-neighborhood/database/outgoing/all' => {} }
      cases.each do |path, extra|
        status, _, body = request({ 'selection' => selected, 'q' => 'q' * 256 }.merge(extra), path: path)
        assert_equal 200, status, path
        html = body.join
        assert_operator html.bytesize, :<=, 65_536
        assert_equal 1, @readers.last.calls.length
        assert @readers.last.closed
        assert_includes html, 'name="selection" value="' + selected + '"'
        assert_includes html, 'name="q" value="' + 'q' * 256 + '"'
        list = html.scan(/data-neighborhood-edge="(\d+)"/)
        diagram = html.scan(/data-neighborhood-diagram-edge="(\d+)"/)
        assert_equal list, diagram unless diagram.empty?
        if path.include?('/edges/')
          refute_empty list
        elsif !path.include?('/database/')
          assert_operator html.scan(/<tr>|<li>/).length, :>, 0
        end
      end
    end
  end
end
