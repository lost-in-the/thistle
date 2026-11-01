# frozen_string_literal: true

# AUTHORED UNRUN: a fresh installed Core process, no Rails/DB/Map/server.
require 'json'
require 'digest'
require 'thistle'
raise 'Framework unexpectedly loaded' if defined?(Rails) || defined?(ActiveRecord)
installed = File.realpath(ENV.fetch('THISTLE_FIXTURE_INSTALLED_ROOT'))
gem_path = File.realpath(Gem.loaded_specs.fetch('thistle').full_gem_path)
raise 'Checkout Core used' unless gem_path.start_with?(installed + File::SEPARATOR)
receipt = JSON.parse(File.read(ARGV.fetch(0)))
cards = JSON.parse(File.read(File.join(__dir__, 'expected_cards.json')))
def demand(condition, message) = (raise message unless condition)
store = receipt.fetch('store'); root = receipt.fetch('root')
reader = Thistle::Reader.new(store, generation: receipt.fetch('saved_a'))
results = []
begin
  cards.fetch('comparisons').each do |card|
    supplied_root = case card.fetch('root')
                    when 'nil' then nil
                    when 'operator_workspace' then root
                    when 'symlink_alias' then receipt.fetch('root_alias')
                    when 'relative_refusal' then '../refused-root'
                    else raise 'Unknown answer-card root'
                    end
    options = { workspace_root: supplied_root }
    options[:max_bytes] = card.fetch('max_bytes') if card.key?('max_bytes')
    answer = reader.source_freshness(card.fetch('file_path'), **options)
    demand(answer.values_at('version', 'generation', 'status', 'reason') ==
      [1, receipt.fetch('saved_a'), card.fetch('status'), card.fetch('reason')], "Answer card differs: #{card.fetch('name')}")
    source_card = cards.fetch('files').fetch(card.fetch('file_path'))
    demand(answer.fetch('file') == source_card.slice('path', 'sha256', 'bytes'), 'Saved identity differs from independent card')
    usage = answer.fetch('usage'); limits = answer.fetch('limits')
    demand(usage.fetch('bytes_read') <= limits.fetch('max_read_bytes') && usage.fetch('bytes_hashed') == usage.fetch('bytes_read'), 'Partial work charge differs')
    demand(usage.fetch('io_attempts') == usage.values_at('directory_open_attempts', 'file_open_attempts', 'stat_attempts', 'read_attempts').sum, 'Attempt total differs')
    demand(usage.fetch('io_attempts') <= limits.fetch('max_io_attempts'), 'Attempt allowance exceeded')
    demand(usage.fetch('io_attempts').zero?, 'Not-checked touched workspace') if supplied_root.nil?
    demand(usage.fetch('bytes_read').zero?, 'Refusal read bytes') if %w[byte_limit unsafe_root].include?(card.fetch('reason'))
    encoded = JSON.generate(answer)
    demand(!encoded.include?(root) && !encoded.include?(store) && !answer.key?('content') && !answer.key?('live_sha256'), 'Private/live data leaked')
    results << { 'name' => card.fetch('name'), 'status' => answer.fetch('status'), 'reason' => answer.fetch('reason'), 'usage' => usage }
  end
  # Ordinary Source remains saved A after CURRENT B and changed disk bytes.
  source_a = cards.fetch('files').fetch('sub/source.rb')
  demand(reader.source_file('sub/source.rb').fetch('content') == source_a.fetch('content'), 'Source file no longer saved A')
  demand(reader.source(receipt.fetch('fact_id')).fetch('content') == source_a.fetch('content'), 'Fact Source no longer saved A')
  demand(reader.check.values_at('integrity', 'freshness') == %w[verified not_checked], 'Check silently adopted live freshness')
  current = Thistle::Reader.new(store)
  begin
    demand(current.generation == receipt.fetch('current_b') && current.generation != reader.generation, 'CURRENT B was not distinct')
  ensure
    current.close
  end
  demand(File.binread(File.join(root, 'sub/source.rb')) == cards.fetch('source_b'), 'Live fixture unexpectedly changed')
  receipt.fetch('protected_files').each do |path, digest|
    demand(Digest::SHA256.file(File.join(store, path)).hexdigest == digest, 'Comparison rewrote CURRENT/generation/blob')
  end
ensure
  reader.close
end
demand(!defined?(Rails) && !defined?(ActiveRecord), 'Framework unexpectedly loaded')
demand(!$LOADED_FEATURES.any? { |path| path.match?(%r{/(?:rails|active_record)(?:/|\.rb)}) }, 'Framework feature loaded')
puts JSON.generate({ 'version' => 1, 'generation' => receipt.fetch('saved_a'), 'current_generation' => receipt.fetch('current_b'),
  'cards' => results, 'source_remained_saved_a' => true, 'protected_store_files_unchanged' => true,
  'rails_loaded' => false, 'active_record_loaded' => false, 'qualification' => 'UNQUALIFIED' })
