# frozen_string_literal: true

# A finite, booted Rails process. Its loopback listener opens only AFTER GO;
# there is no eval endpoint. It waits for actual OCI/PID/namespace/mount limits before
# loading candidate code or touching a database socket.
require_relative 'profile'
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 45
until File.exist?('/work/go.json')
  raise 'Admission deadline' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  sleep 0.1
end
go = JSON.parse(File.read('/work/go.json'))
%w[pid net mnt user].each do |name|
  raise 'Namespace admission drift' unless File.readlink("/proc/self/ns/#{name}") == go.fetch('namespaces').fetch(name)
end
raise 'Admission expired' unless Time.now.to_f < go.fetch('expires_at')
require_relative 'install'
require '/input/app/config/environment'
require_relative 'database'
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20
begin
  ActiveRecord::Base.connection.execute('SELECT 1')
rescue ActiveRecord::ConnectionNotEstablished, Mysql2::Error::ConnectionError
  raise 'Database readiness deadline' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  sleep 0.2
  retry
end
data = HostDatabase.verify(initialize_empty: go.fetch('initialize_empty'))
HostProfile.write('/work/ready.json', { 'token' => go.fetch('token'), 'database' => data,
  'identity' => HostProfile.identities(client: true), 'booted' => Rails.application.initialized? })
gem 'puma', "= #{HostProfile.config.fetch('puma_version')}"
require 'puma'
require 'rack/urlmap'
session = "/work/sessions/#{go.fetch('token')}"
map = lambda do |env|
  selected = JSON.parse(File.read(File.join(session, 'selected.json')))
  attempt = selected.fetch('attempt')
  raise 'Map selection identity refused' unless attempt.match?(/\A[0-9a-f]{32}\z/) && selected.fetch('token') == go.fetch('token')
  store = File.join(session, 'attempts', attempt, 'store')
  raise 'Map store ownership mismatch' unless selected.fetch('store') == store
  Thistle::Map::App.new(store: store).call(env)
rescue Errno::ENOENT
  [503, { 'content-type' => 'text/plain' }, ['Run the installed journey to select this session\'s saved evidence.']]
end
app = Rack::URLMap.new('/map' => map, '/' => Rails.application)
sink = File.open(File::NULL, 'w')
server = Puma::Server.new(app, nil, log_writer: Puma::LogWriter.new(sink, sink), min_threads: 0, max_threads: 2)
server.add_tcp_listener('127.0.0.1', 9292)
server.run
begin
  sleep 0.2 while Time.now.to_f < go.fetch('expires_at')
ensure
  server.stop(true)
end
