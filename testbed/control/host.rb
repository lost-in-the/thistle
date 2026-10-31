# frozen_string_literal: true

# A finite, booted Rails process. Its private Unix listener opens only AFTER GO;
# there is no eval endpoint. It waits for actual OCI/PID/namespace/mount limits before
# loading candidate code or touching a database socket.
require_relative 'profile'
session = ENV.fetch('THISTLE_HOST_SESSION')
raise 'Host session path refused' unless session.match?(%r{\A/work/sessions/[0-9a-f]{32}\z})
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 45
until File.exist?(File.join(session, 'admission.json'))
  raise 'Admission deadline' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  sleep 0.1
end
admission = JSON.parse(File.read(File.join(session, 'admission.json')))
%w[pid net mnt user].each do |name|
  raise 'Namespace admission drift' unless File.readlink("/proc/self/ns/#{name}") == admission.fetch('namespaces').fetch(name)
end
raise 'Admission expired' unless Time.now.to_f < admission.fetch('expires_at')
require_relative 'install'
gem 'puma', "= #{HostProfile.config.fetch('puma_version')}"
require 'puma'
require 'rails'
require 'active_record'
require 'action_controller/railtie'
raise 'Framework cohort drift' unless Rails.version == '7.1.6' && ActiveRecord::VERSION::STRING == '7.1.6'
HostProfile.write(File.join(session, 'cohort-ready.json'), { 'token' => admission.fetch('token'),
  'identity' => HostProfile.identities(client: true) })
# Framework/native/client/lock validation is complete without opening any DB
# credential or connection. Only the separate GO permits application boot.
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
until File.exist?(File.join(session, 'go.json'))
  raise 'GO deadline' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  sleep 0.1
end
go = JSON.parse(File.read(File.join(session, 'go.json')))
raise 'GO identity drift' unless go.fetch('token') == admission.fetch('token') && go.fetch('namespaces') == admission.fetch('namespaces')
raise 'GO expired' unless Time.now.to_f < go.fetch('expires_at')
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
require 'rack/urlmap'
raise 'Host session token drift' unless session == "/work/sessions/#{go.fetch('token')}"
selection_lock = Mutex.new
selected_key = selected_app = nil
map = lambda do |env|
  selected = JSON.parse(File.read(File.join(session, 'selected.json')))
  attempt = selected.fetch('attempt')
  raise 'Map selection identity refused' unless attempt.match?(/\A[0-9a-f]{32}\z/) && selected.fetch('token') == go.fetch('token')
  store = File.join(session, 'attempts', attempt, 'store')
  raise 'Map store ownership mismatch' unless selected.fetch('store') == store
  generation = selected.fetch('generation')
  raise 'Selected generation refused' unless generation.match?(/\A[0-9a-f]{64}\z/)
  # Retain one presentation app for this selected store/generation; in-flight
  # requests may finish with the older immutable app after a selection change.
  app = selection_lock.synchronize do
    key = [store, generation]
    unless selected_key == key
      selected_app = Thistle::Map::App.new(store: store,
        reader_factory: ->(path, requested) { Thistle::Reader.new(path, generation: requested || generation) })
      selected_key = key
    end
    selected_app
  end
  app.call(env)
rescue Errno::ENOENT
  [503, { 'content-type' => 'text/plain' }, ['Run the installed journey to select this session\'s saved evidence.']]
end
app = Rack::URLMap.new('/map' => map, '/' => Rails.application)
sink = File.open(File::NULL, 'w')
server = Puma::Server.new(app, nil, log_writer: Puma::LogWriter.new(sink, sink), min_threads: 0, max_threads: 2)
socket_path = File.join(session, 'http.sock')
begin
  File.lstat(socket_path)
  raise 'Existing or stale HTTP socket refused'
rescue Errno::ENOENT
  # Fresh token-owned session directory; never unlink someone else's socket.
end
info = File.stat(session)
raise 'HTTP session directory mode/owner' unless info.uid == Process.uid && (info.mode & 0o777) == 0o700
server.add_unix_listener(socket_path, 0o077, 0o600, 16)
server.run
HostProfile.write(File.join(session, 'ready.json'), { 'token' => go.fetch('token'), 'database' => data,
  'identity' => HostProfile.identities(client: true), 'booted' => Rails.application.initialized? })
begin
  sleep 0.2 while Time.now.to_f < go.fetch('expires_at')
ensure
  server.stop(true)
end
