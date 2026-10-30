# frozen_string_literal: true

# A separate fresh process: no fixture boot, live application, or source load.
require 'json'
require 'digest'
require 'thistle/map'

store, receipt_path = ARGV
raise 'Expected callback store and receipt' unless ARGV.length == 2
raise 'Fresh callback consumer loaded Rails' if defined?(Rails) || defined?(ActiveRecord)
receipt = JSON.parse(File.read(receipt_path))
reader = latest = nil
begin
  reader = Thistle::Reader.new(store, generation: receipt.fetch('generation'))
  latest = Thistle::Reader.new(store)
  raise 'Current/pinned generation mismatch' unless latest.generation == receipt.fetch('current_generation') && latest.generation != reader.generation
  facts = reader.facts.select { |fact| fact['kind'] == 'rails_save_callbacks' }
  child = facts.find { |fact| fact['name'] == 'CallbackFixture::Child' } or raise 'Missing callback child'
  data = child.fetch('attributes').fetch('callbacks')
  raise 'Provenance changed' unless data['coherence'] == 'unknown' && data['provenance'] == 'registered_metadata'
  raise 'Runtime fact claimed captured binding' unless child['path'].nil? && child['location'].nil?
  entries = data.fetch('save').fetch('entries')
  raise 'Registered positions changed' unless entries.map { |entry| entry.fetch('position') } == entries.each_index.to_a
  stamp = entries.find { |entry| entry.dig('filter', 'name') == 'parent_stamp' } or raise 'Inherited stamp missing'
  raise 'Effective override/inheritance missing' unless stamp['inherited'] == true && stamp.dig('filter', 'owner') == 'CallbackFixture::Child'
  raise 'Skipped registration survived' if entries.any? { |entry| entry.dig('filter', 'name') == 'removed' }
  raise 'Around registration missing' unless entries.any? { |entry| entry['kind'] == 'around' && entry.dig('filter', 'name') == 'wrap' }
  raise 'Condition metadata missing' unless stamp.fetch('if').any? { |condition| condition['name'] == 'allowed?' }
  empty = facts.find { |fact| fact['name'] == 'CallbackFixture::Empty' } or raise 'Empty chain model missing'
  raise 'Empty chain meaning changed' unless empty.dig('attributes', 'callbacks', 'save') == { 'status' => 'observed', 'entries' => [] }
  raise 'Label relationship resolved' unless reader.links(child.fetch('id')).all? { |link| link['resolution'] == 'unresolved' }
  source = reader.source_file('records.rb')
  raise 'Pinned source changed' unless source.fetch('generation') == reader.generation && source.fetch('sha256') == receipt.fetch('fixture_source_sha256')
  view = Thistle::Map::View.new(reader: reader, mount: '/map', params: { 'id' => child.fetch('id') })
  html = view.source
  ['Registered save callbacks', 'Method :parent_stamp', 'Captured source (coherence unknown)',
   "generation=#{reader.generation}", "file=#{Digest::SHA256.hexdigest('records.rb')}", 'not execution chronology'].each do |text|
    raise "Missing callback Map evidence: #{text}" unless html.include?(text)
  end
  raise 'Check lost pinned generation' unless reader.check.fetch('generation') == reader.generation
  native = $LOADED_FEATURES.find { |path| path.match?(%r{/thistle/thistle_native\.(so|bundle|dll)\z}) }
  gem_home = File.realpath(ENV.fetch('GEM_HOME'))
  %w[thistle thistle-map].each do |name|
    raise 'Loaded checkout product code' unless File.realpath(Gem.loaded_specs.fetch(name).full_gem_path).start_with?(gem_home + File::SEPARATOR)
  end
  raise 'Installed native missing' unless native && File.realpath(native).start_with?(gem_home + File::SEPARATOR)
  native_hash = Digest::SHA256.file(native).hexdigest
  raise 'Producer/consumer native changed' unless native_hash == receipt.fetch('native_sha256')
  explanation = reader.callback_effects(child.fetch('id'))
  explained_stamp = explanation.fetch('callbacks').find { |row| row.dig('filter', 'name') == 'parent_stamp' } or raise 'Missing explained inherited filter'
  potential = explained_stamp.dig('explanation', 'effects', 0) or raise 'Missing source-supported potential effect'
  raise 'Explanation lost pinned source/owner' unless explanation.fetch('generation') == reader.generation && explained_stamp.dig('explanation', 'method', 'owner') == 'CallbackFixture::Child' && explained_stamp.dig('explanation', 'source', 'sha256') == source.fetch('sha256')
  raise 'Potential request changed' unless potential.fetch('operation') == 'CallbackFixture::DeliveryJob.perform_later' && explained_stamp.dig('explanation', 'coherence') == 'unknown'
  call_span = potential.fetch('call_span')
  raise 'Supporting source span changed' unless source.fetch('content').byteslice(call_span.fetch('start_byte')...call_span.fetch('end_byte')).start_with?('CallbackFixture::DeliveryJob.perform_later')
  raise 'Opaque callbacks gained effects' unless explanation.fetch('callbacks').any? { |row| row.dig('explanation', 'reason') == 'opaque_or_incomplete_observed_method_descriptor' }
  raise 'Map potential evidence missing' unless html.include?('Potential save callback effects') && html.include?('CallbackFixture::DeliveryJob.perform_later') && html.include?('No observed enqueue')
  puts JSON.generate('status' => 'passed', 'generation' => reader.generation,
    'callback_effects' => { 'operation' => potential.fetch('operation'), 'source_sha256' => source.fetch('sha256'), 'coherence' => 'unknown' },
    'current_advanced' => true, 'fresh_consumer_without_rails' => true,
    'callback_id' => child.fetch('id'), 'callback_model_count' => facts.length,
    'fixture_source_sha256' => source.fetch('sha256'), 'native_sha256' => native_hash,
    'ruby' => RUBY_DESCRIPTION, 'core_version' => Thistle::VERSION, 'map_version' => Thistle::Map::VERSION)
ensure
  latest&.close
  reader&.close
end
