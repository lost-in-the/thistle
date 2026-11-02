# frozen_string_literal: true

# AUTHORED UNRUN. Explicit temporary public data; installed Core only.
require 'json'
require 'digest'
require 'fileutils'
require 'thistle'
raise 'Framework unexpectedly loaded' if defined?(Rails) || defined?(ActiveRecord)
installed = File.realpath(ENV.fetch('THISTLE_FIXTURE_INSTALLED_ROOT'))
gem_path = File.realpath(Gem.loaded_specs.fetch('thistle').full_gem_path)
raise 'Checkout Core used' unless gem_path.start_with?(installed + File::SEPARATOR)
raise 'Expected a new public fixture directory' unless ARGV.length == 1 && !File.exist?(ARGV[0])
work = File.expand_path(ARGV.fetch(0)); Dir.mkdir(work, 0700)
work = File.realpath(work)
root = File.join(work, 'workspace'); Dir.mkdir(root, 0700)
FileUtils.mkdir_p(File.join(root, 'sub'))
store = File.join(work, 'store')
source_a = "class SavedFreshness\nend\n"
source_b = "class CurrentFreshness\nend\n"
def data(source)
  files = { 'sub/source.rb' => source, 'stable.rb' => "stable\n", 'empty.rb' => '',
    'missing.rb' => "missing\n", 'link.rb' => "link\n" }
  { 'root_id' => Digest::SHA256.hexdigest('public-source-freshness-root'), 'producer' => { 'name' => 'public-source-freshness-no-parser' },
    'files' => files.map { |path, content| { 'path' => path, 'sha256' => Digest::SHA256.hexdigest(content),
      'bytes' => content.bytesize, 'encoding' => 'UTF-8', 'content' => content } },
    'facts' => [{ 'id' => 'b' * 64, 'kind' => 'class', 'name' => 'SavedFreshness', 'path' => 'sub/source.rb',
      'location' => nil, 'evidence' => 'static', 'attributes' => {}, 'links' => [] }],
    'coverage' => [{ 'family' => 'ruby', 'status' => 'partial', 'scope' => 'public fixture', 'reason' => 'No runtime evidence' }],
    'diagnostics' => [] }
end
a = data(source_a); a.fetch('files').each { |row| File.binwrite(File.join(root, row.fetch('path')), row.fetch('content')) }
saved_a = Thistle::Store.new(store).publish(a).fetch('generation')
# Retain this exact public handle across CURRENT advancement and disk edits.
retained_reader = Thistle::Reader.new(store, generation: saved_a)
begin
  # The producer never invokes Capture, a parser or an application.
  saved_b = Thistle::Store.new(store).publish(data(source_b)).fetch('generation')
  raise 'Generation did not advance' if saved_a == saved_b
  File.binwrite(File.join(root, 'sub/source.rb'), source_b)
  retained_source = retained_reader.source('b' * 64)
  retained_freshness = retained_reader.source_freshness('sub/source.rb', workspace_root: root)
  retained_check = retained_reader.check
  raise 'Retained Source changed' unless retained_source.fetch('content') == source_a
  raise 'Retained freshness differs' unless retained_freshness.values_at('generation', 'status') == [saved_a, 'changed']
  raise 'Check adopted freshness' unless retained_check.values_at('integrity', 'freshness') == %w[verified not_checked]
  retained_card = { 'generation' => retained_reader.generation, 'source_sha256' => retained_source.fetch('sha256'),
    'source_bytes' => retained_source.fetch('content').bytesize, 'status' => retained_freshness.fetch('status'),
    'check_integrity' => retained_check.fetch('integrity'), 'check_freshness' => retained_check.fetch('freshness') }
ensure
  retained_reader.close
end
File.unlink(File.join(root, 'missing.rb'))
File.unlink(File.join(root, 'link.rb')); File.symlink('stable.rb', File.join(root, 'link.rb'))
File.symlink(root, File.join(work, 'root_alias'))
protected = ['CURRENT'] + [saved_a, saved_b].flat_map do |generation|
  %w[manifest.json facts.json].map { |name| "generations/#{generation}/#{name}" }
end
protected += (a.fetch('files') + data(source_b).fetch('files')).map { |row| "blobs/#{row.fetch('sha256')}" }.uniq
fingerprints = protected.to_h { |path| [path, Digest::SHA256.file(File.join(store, path)).hexdigest] }
raise 'Framework unexpectedly loaded' if defined?(Rails) || defined?(ActiveRecord)
puts JSON.generate({ 'version' => 1, 'root' => root, 'root_alias' => File.join(work, 'root_alias'), 'store' => store,
  'saved_a' => saved_a, 'current_b' => saved_b, 'fact_id' => 'b' * 64, 'protected_files' => fingerprints,
  'retained_reader_after_b' => retained_card,
  'producer' => { 'core_version' => Gem.loaded_specs.fetch('thistle').version.to_s,
    'rails_loaded' => false, 'active_record_loaded' => false, 'capture_invoked' => false } })
