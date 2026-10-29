# frozen_string_literal: true

# Copied outside the checkout by the candidate-owned installed runner. Only the
# harmless boot fixture is loaded here; Thistle implementation comes from gems.
require 'json'
require 'fileutils'
require 'digest'
require 'thistle'

fixture, root, store = ARGV
raise 'Expected fixture, root and store' unless fixture && root && store
FileUtils.mkdir_p(root)
FileUtils.cp(File.join(fixture, 'records.rb'), File.join(root, 'records.rb'))
require File.join(fixture, 'booted_app')
app = ModelFixture.boot(root)
def app.eager_load! = raise('eager load attempted')
def app.reload_routes! = raise('reload attempted')
ModelFixture::Order.reflect_on_association(:items).define_singleton_method(:klass) { raise 'through target loaded' }
ModelFixture::Item.reflect_on_association(:product).define_singleton_method(:klass) { raise 'target loaded' }
manifest = Thistle.capture(root: root, output: store, rails: app)
puts JSON.generate('generation' => manifest.fetch('generation'),
  'fixture_source_sha256' => Digest::SHA256.file(File.join(root, 'records.rb')).hexdigest,
  'active_record_version' => ActiveRecord::VERSION::STRING)
