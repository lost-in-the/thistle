# frozen_string_literal: true

require 'net/http'
require 'json'
# Real loopback TCP request inside the admitted isolated network namespace.
# No forwarded headers, mapped ports, network proxy, or authorization adapter.
http = Net::HTTP.new('127.0.0.1', 9292, nil)
http.open_timeout = 2
http.read_timeout = 2
request = Net::HTTP::Get.new('/orders/1', 'Host' => 'localhost:9292')
response = http.request(request)
raise 'Developer endpoint not ready' unless response.code == '200' && JSON.parse(response.body) == {
  'reference' => 'retained-order-1', 'quantities' => [2, 3] }
puts JSON.generate('status' => 'passed', 'url' => 'http://127.0.0.1:9292/orders/1',
  'topology' => 'inside worker network namespace only; no published host port', 'peer' => '127.0.0.1')
