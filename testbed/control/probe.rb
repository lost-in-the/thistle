# frozen_string_literal: true

require 'json'
require_relative 'http'
socket = ARGV.fetch(0)
response = HostHTTP.request(socket, '/orders/1')
raise 'Internal UNIX controller answer failed' unless response.code == '200' && JSON.parse(response.body) == {
  'reference' => 'retained-order-1', 'quantities' => [2, 3] }
health = HostHTTP.request(socket, '/health')
expected = { 'fixture' => 'reusable-host-v1', 'peer' => '127.0.0.1', 'host' => '127.0.0.1' }
raise 'Actual UNIX peer/Host mismatch' unless health.code == '200' && JSON.parse(health.body) == expected
puts JSON.generate('status' => 'passed', 'transport' => 'private-unix', 'socket' => socket,
  'peer' => '127.0.0.1', 'scope' => 'INTERNAL UNIX request; separate host URL probe required')
