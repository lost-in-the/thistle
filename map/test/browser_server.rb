# frozen_string_literal: true

# Local-only test adapter; WEBrick is a development dependency, not shipped.
require 'webrick'
require_relative 'test_helper'

app = if ENV['THISTLE_MAP_TEST_STORE']
        Thistle::Map::App.new(store: ENV.fetch('THISTLE_MAP_TEST_STORE'))
      else
        sample = "class Demo\n  def show = '<script>alert(1)</script>'\n  # #{'source ' * 40}\nend\n"
        Thistle::Map::App.new(
          store: '/tmp/unused-thistle-map-browser-store',
          reader_factory: ->(_, generation) { MapTestSupport::Reader.new(generation, content: sample) }
        )
      end

server = WEBrick::HTTPServer.new(
  BindAddress: '127.0.0.1', Port: Integer(ENV.fetch('THISTLE_MAP_TEST_PORT', '41237')),
  AccessLog: [], Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN)
)
server.mount_proc('/') do |request, response|
  env = {
    'REQUEST_METHOD' => request.request_method, 'PATH_INFO' => request.path,
    'QUERY_STRING' => request.query_string.to_s, 'SCRIPT_NAME' => '',
    'HTTP_HOST' => request['host'], 'REMOTE_ADDR' => request.peeraddr[3],
    'HTTP_ORIGIN' => request['origin'], 'HTTP_SEC_FETCH_SITE' => request['sec-fetch-site'],
    'rack.url_scheme' => 'http'
  }
  status, headers, body = app.call(env)
  response.status = status
  headers.each { |name, value| response[name] = value }
  response.body = body.each.to_a.join
end
trap('INT') { server.shutdown }
trap('TERM') { server.shutdown }
puts "Map test server ready on 127.0.0.1:#{server.config[:Port]}"
$stdout.flush
server.start
