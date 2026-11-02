# frozen_string_literal: true

# AUTHORED UNRUN. Outside checkout, fresh process, installed Core only.
require 'json'
require 'digest'
require 'tmpdir'
require 'fileutils'
require 'thistle'
raise 'Consumer booted an application' if defined?(Rails) || defined?(ActiveRecord)
installed = File.realpath(ENV.fetch('THISTLE_FIXTURE_INSTALLED_ROOT'))
loaded = File.realpath(Gem.loaded_specs.fetch('thistle').full_gem_path)
raise 'Checkout Core used' unless loaded.start_with?(installed + File::SEPARATOR)
raise 'Expected producer receipt JSON and independent cards JSON' unless ARGV.length == 2
receipt = JSON.parse(File.binread(ARGV.fetch(0)))
cards = JSON.parse(File.binread(ARGV.fetch(1)))
store = receipt.fetch('store')

def demand(ok, message)
  raise message unless ok
end

def compare(left, right, selection, **options)
  left.generation_comparison(right, selection: selection, **options)
end

def known_pair(answer, left, right, selection)
  demand(answer.fetch('version') == 1, 'Unsupported comparison DTO')
  demand(answer.dig('pair', 'left', 'generation') == left.generation, 'Lost explicit A')
  demand(answer.dig('pair', 'right', 'generation') == right.generation, 'Lost explicit B')
  # Root may serialize role:null for non-job kinds; compare the selected fields.
  demand(selection.all? { |key, value| answer.fetch('selection')[key] == value }, 'Typed selection changed')
  demand(answer.fetch('unavailable').include?('git_commit_comparison'), 'Fabricated Git comparison')
end

def recorded_receiver(row)
  extension = row.dig('recorded_link', 'attributes', 'thistle_call')
  return nil unless extension
  extension['version'] == 2 ? extension.fetch('data').fetch(1) : extension.dig('receiver', 'name')
end

def field_cards(comparison, card, receipt, left, right)
  return unless card['field_changes']
  evidence = comparison.dig('metadata', 'evidence')
  demand(evidence && evidence['status'] == 'complete', 'Concrete metadata evidence incomplete')
  demand(evidence.dig('context', 'left', 'generation') == left.generation &&
    evidence.dig('context', 'right', 'generation') == right.generation, 'Changed fields lost A/B context')
  card.fetch('field_changes').each do |expected|
    path = expected['path'] || expected.fetch('path_template').sub('{delayed_index}', receipt.dig('default_a', 'index').to_s)
    row = evidence.fetch('items').find { |item| item['path'] == path }
    demand(row, "Missing named changed field #{path}")
    %w[before after].each do |side|
      value = expected.key?(side) ? expected.fetch(side) : receipt.fetch(expected.fetch("#{side}_oracle")).fetch('value')
      actual = row.fetch(side)
      demand(actual['present'] == true && actual['value_status'] == 'shown' && actual.key?('value'), 'Typed value/presence omitted')
      demand(JSON.generate(actual.fetch('value')) == JSON.generate(value), "Wrong typed #{side} value for #{path}")
    end
  end
end

def source_card(comparison, card, left, right)
  return unless card['source_content']
  witness = comparison.dig('source', 'witness')
  demand(witness && witness['status'] == 'shown' && witness['complete_hunks'] == false, 'Missing honest source-content witness')
  %w[left right].each do |side|
    owner = side == 'left' ? left : right
    row = witness.fetch(side)
    demand(row.fetch('generation') == owner.generation, 'Source witness lost explicit generation')
    source = owner.source(row.fetch('fact_id'))
    region = row.fetch('region')
    content = source.fetch('content')
    text = region.fetch('text')
    demand(text == content.byteslice(region.fetch('start_byte'), region.fetch('end_byte') - region.fetch('start_byte')), 'Source text differs from exact physical region')
    demand(region.fetch('start_line') == content.byteslice(0, region.fetch('start_byte')).count("\n") + 1 &&
      region.fetch('end_line') == content.byteslice(0, region.fetch('end_byte')).count("\n") + 1, 'Original physical line coordinates changed')
    demand(row.fetch('payload_sha256') == source.fetch('sha256') && region.fetch('sha256') == Digest::SHA256.hexdigest(text), 'Source witness digest differs')
    demand(text.bytesize <= 512, 'Source witness exceeded bounded window')
    expected = card.fetch('source_content').fetch(side == 'left' ? 'before_contains' : 'after_contains')
    demand(expected.all? { |part| text.include?(part) }, 'Source witness does not explain concrete normalization/default change')
    followup = comparison.dig('source', 'followups', side)
    demand(followup == { 'operation' => 'source', 'generation' => owner.generation, 'id' => row.fetch('fact_id') }, 'Source reveal lost saved identity')
  end
end

left = right = partial = current = nil
results = []
begin
  left = Thistle::Reader.new(store, generation: receipt.fetch('saved_a'))
  right = Thistle::Reader.new(store, generation: receipt.fetch('saved_b'))
  partial = Thistle::Reader.new(store, generation: receipt.fetch('saved_partial'))
  current = Thistle::Reader.new(store)
  demand(current.generation == receipt.fetch('current_c'), 'CURRENT C was not published')
  cards.fetch('cards').each do |card|
    other = card['right_version'] == 'saved_partial' ? partial : right
    answer = compare(left, other, card.fetch('selection'))
    known_pair(answer, left, other, card.fetch('selection'))
    comparison = answer.fetch('comparison')
    demand(comparison.fetch('status') == card.fetch('status'), "Wrong classification: #{card.fetch('label')}")
    %w[source metadata relationships].each do |component|
      next unless card.key?(component)
      demand(comparison.dig(component, 'status') == card.fetch(component), "Wrong #{component}: #{card.fetch('label')}")
    end
    demand(comparison['change_kind'] == card['change_kind'], 'Metadata-only/source-unknown conflated') if card['change_kind']
    field_cards(comparison, card, receipt, left, other)
    source_card(comparison, card, left, other)
    %w[left right].each do |side|
      key = "#{side}_count"
      demand(answer.dig('matching', side, 'count') == card.fetch(key), 'Duplicate identity silently selected') if card.key?(key)
      answer.dig('matching', side, 'identities').each do |identity|
        next unless identity['path'] && identity['location']
        owner = side == 'left' ? left : other
        source = owner.source(identity.fetch('id'))
        demand(source.fetch('generation') == owner.generation, 'Source opened a different generation')
        demand(source.fetch('sha256') == identity.fetch('payload_sha256'), 'Source payload identity changed')
        demand(source.dig('fact', 'path') == identity.fetch('path'), 'Physical Source path changed')
        demand(source.dig('fact', 'location') == identity.fetch('location'), 'Physical Source span changed')
      end
    end
    demand(comparison.dig('line_diff', 'status') == 'unavailable', 'Missing line diff reported as unchanged')
    results << { 'label' => card.fetch('label'), 'answer' => answer }
  end

  null_card = cards.fetch('fidelity_controls').fetch('unchanged_null_default')
  answer = compare(left, right, null_card.fetch('selection'))
  path = "/model/columns/entries/#{receipt.dig('default_a', 'nullable_index')}/default/value"
  demand(answer.dig('comparison', 'metadata', 'evidence', 'items').none? { |row| row['path'] == path }, 'Unchanged present-null default became a change')
  %w[left right].each do |side|
    owner = side == 'left' ? left : right
    id = answer.dig('comparison', 'metadata', 'evidence', 'context', side, 'fact_id')
    columns = owner.fact(id).dig('attributes', 'model', 'columns', 'entries')
    column = columns.find { |entry| entry['name'] == null_card.fetch('column') }
    default = column.fetch('default')
    demand(default.key?('value') == null_card.fetch('value_present') && default.fetch('value') == null_card.fetch('value'), 'Present-null default lost its saved presence')
  end

  # Dedicated disposable copy: a corrupt blob must refuse even when both
  # manifests/digest status appear comparable. Preserve the original store.
  demand(receipt.fetch('protected_files').length <= 256, 'Public fixture unexpectedly grew')
  demand(receipt.fetch('protected_files').keys.sum { |name| File.size(File.join(store, name)) } <= 4 * 1024 * 1024, 'Public corruption fixture exceeds copy budget')
  Dir.mktmpdir('thistle-los151-corrupt-') do |work|
    copy = File.join(work, 'store')
    FileUtils.cp_r(store, copy)
    identity = results.first.fetch('answer').dig('matching', 'left', 'identities').first
    File.binwrite(File.join(copy, 'blobs', identity.fetch('payload_sha256')), 'corrupt')
    corrupt_left = corrupt_right = nil
    begin
      corrupt_left = Thistle::Reader.new(copy, generation: left.generation)
      corrupt_right = Thistle::Reader.new(copy, generation: right.generation)
      begin
        compare(corrupt_left, corrupt_right, cards.fetch('cards').first.fetch('selection'))
        raise 'Corrupt selected source returned a content witness'
      rescue Thistle::InvalidSnapshot
        # Expected exact integrity refusal, never a passing hash-only answer.
      end
    ensure
      [corrupt_left, corrupt_right].compact.each(&:close)
    end
  end

  selected = { 'kind' => 'class', 'name' => 'Order' }
  cursor = nil
  witnesses = []
  finished = false
  32.times do
    answer = compare(left, right, selected, family: 'references', direction: 'incoming', limit: 1, cursor: cursor)
    known_pair(answer, left, right, selected)
    # Count the actual native success envelope with no invented newline.
    demand(JSON.generate({ 'ok' => true, 'result' => answer }).bytesize <= 32768, 'Native envelope exceeded ceiling')
    witnesses.concat(answer.fetch('items'))
    next_cursor = answer['next_cursor']
    demand(next_cursor.nil? || next_cursor != cursor, 'Zero-progress cursor')
    cursor = next_cursor
    if cursor.nil?
      demand(answer.dig('scan', 'complete') == true, 'No continuation despite unfinished scan')
      finished = true
      break
    end
  end
  demand(finished, 'Finite witness page bound exhausted')
  expected = cards.fetch('incoming_order_witness')
  expected.fetch('sides').each do |side|
    demand(witnesses.any? { |row| row['side'] == side && row.dig('origin', 'name') == expected.fetch('origin') &&
      row['relation'] == expected.fetch('relation') && row['target_label'] == expected.fetch('target_label') &&
      row['direction'] == expected.fetch('direction') && recorded_receiver(row) == expected.fetch('receiver_label') &&
      row['candidate_label'] == expected.fetch('candidate_label') },
      "Missing recorded #{side} job-to-Order witness")
  end
  demand(witnesses.none? { |row| row.dig('origin', 'name') == 'UnrelatedChange' }, 'Unrelated changes polluted selected root')
  token = compare(left, right, selected, family: 'references', limit: 1)['next_cursor']
  demand(!token.nil?, 'Fixture must produce a real continuation')
  begin
    compare(right, left, selected, family: 'references', limit: 1, cursor: token)
    raise 'Reversed pair cursor accepted'
  rescue Thistle::Error
    # Expected native refusal, not success for an unrelated reason.
  end
  right.close
  begin
    compare(left, right, selected)
    raise 'Closed borrowed Reader accepted'
  rescue Thistle::Error
  end
ensure
  [left, right, partial, current].compact.each(&:close)
  receipt.fetch('protected_files').each do |name, sha|
    demand(Digest::SHA256.file(File.join(store, name)).hexdigest == sha, 'Read-only comparison mutated saved store')
  end
end
demand(!defined?(Rails) && !defined?(ActiveRecord), 'Consumer booted framework')
demand($LOADED_FEATURES.grep(/(?:^|\/)woods(?:[\/.]|$)/).empty?, 'Woods dependency loaded')
puts JSON.generate({ 'version' => 1, 'status' => 'passed', 'cards' => results, 'witnesses' => witnesses,
  'installed_core' => loaded, 'rails_loaded' => false, 'store_unchanged' => true,
  'limits' => 'Core/installed cards only; Map/client/person/real Git comparison remain unproved' })
