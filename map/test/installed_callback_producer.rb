# frozen_string_literal: true

# This harmless fixture is copied outside the checkout; product code loads only
# from the installed gems. No callback body or condition should ever execute.
require 'json'
require 'fileutils'
require 'digest'
require 'thistle'

fixture, root, store = ARGV
raise 'Expected fixture, root and store' unless ARGV.length == 3
FileUtils.mkdir_p(root)
FileUtils.cp(File.join(fixture, 'records.rb'), File.join(root, 'records.rb'))
require File.join(fixture, 'booted_app')
app = CallbackFixture.boot(root)
def app.eager_load! = raise('eager load attempted')
def app.reload_routes! = raise('reload attempted')
saved = Thistle.capture(root: root, output: store, rails: app)
current = Thistle.capture(root: root, output: store)
raise 'Current did not advance' if saved.fetch('generation') == current.fetch('generation')
native = $LOADED_FEATURES.find { |path| path.match?(%r{/thistle/thistle_native\.(so|bundle|dll)\z}) }
raise 'Installed native missing' unless native
puts JSON.generate('generation' => saved.fetch('generation'),
  'current_generation' => current.fetch('generation'),
  'fixture_source_sha256' => Digest::SHA256.file(File.join(root, 'records.rb')).hexdigest,
  'active_record_version' => ActiveRecord::VERSION::STRING,
  'native_sha256' => Digest::SHA256.file(native).hexdigest)
