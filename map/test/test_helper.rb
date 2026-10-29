# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
require 'thistle/map'

module MapTestSupport
  GENERATION = 'a' * 64
  FACT_ID = 'b' * 64

  class Reader
    attr_reader :generation, :manifest

    def initialize(generation = GENERATION, facts: nil, content: nil, links: nil)
      @generation = generation || GENERATION
      @facts = facts || [{
        'id' => FACT_ID, 'name' => 'Demo#show', 'kind' => 'method', 'evidence' => 'static',
        'path' => 'lib/demo.rb', 'location' => { 'start_line' => 2, 'end_line' => 2 }, 'attributes' => {}
      }]
      @content = content || "class Demo\n  def show = '<script>alert(1)</script>'\nend\n"
      @links = links || [{ 'relation' => 'calls', 'target' => 'render', 'resolution' => 'unresolved' }]
      @manifest = { 'coverage' => [{ 'family' => 'ruby', 'status' => 'partial', 'scope' => '*.rb', 'reason' => 'Dynamic calls unresolved' }] }
    end

    def find(query, limit:)
      @facts.select { |fact| fact['name'].include?(query) }.first(limit)
    end

    def fact(id)
      @facts.find { |fact| fact['id'] == id } || raise(Thistle::NotFound, 'Internal path /private/source')
    end

    def source(id)
      { 'generation' => generation, 'fact' => fact(id), 'content' => @content, 'sha256' => Digest::SHA256.hexdigest(@content) }
    end

    def links(id)
      fact(id)
      @links
    end

    def check
      { 'generation' => generation, 'coverage' => manifest['coverage'], 'live_freshness' => 'unknown' }
    end
  end

  def stored_call_fields(reader, link)
    data = link.fetch('attributes').fetch('thistle_call')
    if reader.manifest['schema_version'] == 2 && data['version'] == 2
      kind, name, omitted, safe, call, receiver = data.fetch('data')
      location = ->(tuple) { tuple && Hash[%w[start_byte end_byte start_line end_line].zip(tuple)] }
      { 'receiver' => { 'kind' => kind, 'name' => name, 'omitted_limit' => omitted },
        'safe_navigation' => safe, 'call_location' => location.call(call), 'receiver_location' => location.call(receiver) }
    else
      data
    end
  end

  def request(app, path = '/', query: '', method: 'GET', env: {})
    base = {
      'REQUEST_METHOD' => method, 'PATH_INFO' => path, 'QUERY_STRING' => query,
      'SCRIPT_NAME' => '', 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1',
      'rack.url_scheme' => 'http'
    }
    status, headers, body = app.call(base.merge(env))
    [status, headers, body.each.to_a.join]
  end

  def make_app(reader = Reader.new, **options)
    Thistle::Map::App.new(store: '/tmp/unused-thistle-map-test-store', reader_factory: ->(_, _) { reader }, **options)
  end
end
