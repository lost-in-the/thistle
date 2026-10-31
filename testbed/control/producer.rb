# frozen_string_literal: true

require_relative 'profile'
HostProfile.activate
attempt_app = File.join(ARGV.fetch(0), 'app')
ENV['RAILS_ENV'] = 'test'
require File.join(attempt_app, 'config/environment')
require_relative 'database'
require 'thistle/map'
require 'rack/mock'
out = ARGV.fetch(0)
raise 'Expected private attempt path' unless out.match?(%r{\A/work/sessions/[0-9a-f]{32}/attempts/[0-9a-f]{32}\z})
ownership = JSON.parse(File.read(File.join(out, 'begin.json')))
raise 'Attempt owner mismatch' unless ownership.fetch('attempt') == File.basename(out) && ownership.fetch('token') == out.split('/')[3]
before = HostDatabase.verify
# Actual Rails controller dispatch via Rack::MockRequest, without a TCP server.
response = Rack::MockRequest.new(Rails.application).get('/orders/1', 'HTTP_HOST' => 'localhost')
raise 'Controller known answer failed' unless response.status == 200 && JSON.parse(response.body) == {
  'reference' => 'retained-order-1', 'quantities' => [2, 3] }
raise 'Association missing' unless Order.reflect_on_association(:items).klass == Item
raise 'Callback registration missing' unless Order._save_callbacks.any? { |callback| callback.filter == :normalize_reference }
store = File.join(out, 'store')
raise 'Attempt store already exists' if File.exist?(store)
source_path = File.join(attempt_app, 'app/services/inspection.rb')
original = File.binread(source_path)
saved = Thistle.capture(root: Rails.root.to_s, output: store, rails: Rails.application)
HostProfile.write(File.join(out, 'saved-manifest.json'), saved)
begin
  File.binwrite(source_path, original + "\n# Deliberate LOS139 CURRENT advancement.\n")
  current = Thistle.capture(root: Rails.root.to_s, output: store, rails: Rails.application)
  raise 'CURRENT did not advance' if current.fetch('generation') == saved.fetch('generation')
  HostProfile.write(File.join(out, 'current-manifest.json'), current)
ensure
  File.binwrite(source_path, original)
end
raise 'Test mutated retained rows' unless HostDatabase.verify == before
HostProfile.write(File.join(out, 'producer.json'), {
  'status' => 'passed', 'saved' => saved.fetch('generation'), 'current' => current.fetch('generation'),
  'source_sha256' => Digest::SHA256.hexdigest(original), 'database' => before,
  'identity' => HostProfile.identities(client: true), 'controller' => 'Rack request passed; HTTP/browser/human unobserved' })
