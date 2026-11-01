# frozen_string_literal: true

# Standalone mocked Rack boundary. No Native/Rails/store/server/browser is loaded.
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
    class Reader
      attr_reader :calls, :closed, :generation, :manifest
      def initialize(mode)
        @mode, @calls, @generation, @manifest = mode, [], ModelNeighborhoodAnswers::G, { 'files' => [], 'coverage' => [] }
      end
      def model_neighborhood(id, **options)
        @calls << [id, options]
        raise Thistle::Busy, 'busy' if @mode == :busy
        raise Thistle::InvalidSnapshot, 'invalid' if @mode == :invalid
        answer = ModelNeighborhoodAnswers.page(**options.slice(:family, :direction, :type, :candidate))
        if @mode == :long
          # Actual admitted DTO size, long escaped labels and a retained 2-ID/q
          # context. The view must fit the complete same-edge list/diagram or
          # explicitly refuse display; it may not prune one representation.
          4096.downto(1) do |length|
            answer['root']['name'] = '&' * length
            break if JSON.generate(answer).bytesize + 64 <= options.fetch(:max_bytes)
          end
        elsif @mode == :long_default
          answer['items'] = [{ 'kind' => 'column', 'ordinal' => 0, 'column' => {
            'name' => 'note', 'type' => 'string', 'sql_type' => 'text', 'null' => false,
            'default_recorded' => true, 'default_presence' => 'not_recorded', 'default' => { 'kind' => 'literal', 'value' => '' } } }]
          1365.downto(1) do |length|
            answer['items'][0]['column']['default']['value'] = '"&<' * length
            break if JSON.generate(answer).bytesize + 64 <= options.fetch(:max_bytes)
          end
        end
        answer
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
    def test_one_reader_operation_close_head_and_error_propagation
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
      assert_equal 422, request.first
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
    def test_long_near_admitted_labels_with_retained_context_fit_or_explicitly_refuse_display
      selected = [ModelNeighborhoodAnswers::ID, ModelNeighborhoodAnswers::OTHER].join(',')
      { long: '/model-neighborhood/edges/outgoing/all', long_default: '/model-neighborhood/columns/outgoing/all' }.each do |mode, path|
        @mode = mode
        status, _, body = request({ 'selection' => selected, 'q' => 'orders' * 40 }, path: path)
        assert_equal 1, @readers.last.calls.length
        assert @readers.last.closed
        if status == 200
          assert_operator body.join.bytesize, :<=, 65_536
          assert_equal body.join.scan(/data-neighborhood-edge="(\d+)"/), body.join.scan(/data-neighborhood-diagram-edge="(\d+)"/)
          assert_includes body.join, "selection=#{URI.encode_www_form_component(selected)}"
        else
          assert_equal 422, status
          assert_match(/display budget/, body.join)
        end
        puts "Mock display admission #{mode}: status=#{status}, bytes=#{body.join.bytesize} (no Native/framework)"
      end
    end
  end
end
