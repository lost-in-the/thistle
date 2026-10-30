# frozen_string_literal: true

# Synthetic saved evidence only: no Rails boot, database, private source or capture.
module RecordedDomainFixture
  NAME = 'RecordedDomain::Target'
  ANCHOR = format('%064x', 1).freeze
  ORIGIN = format('%064x', 20_059).freeze
  LATE = format('%064x', 20_060).freeze

  def self.capture
    facts = (1..20_060).map do |id|
      { 'id' => format('%064x', id), 'kind' => 'class',
        'name' => [1, 20_060].include?(id) ? NAME : "RecordedDomain::Filler#{id}",
        'path' => nil, 'location' => nil, 'evidence' => 'static', 'attributes' => {}, 'links' => [] }
    end
    facts[20_058]['links'] = Array.new(50_000) { { 'relation' => 'references', 'target' => 'Elsewhere', 'resolution' => 'unresolved' } }
    facts[20_058]['links'] << { 'relation' => 'references', 'target' => NAME, 'resolution' => 'unresolved' }
    model = JSON.parse(File.read(File.expand_path('../../../engine/tests/fixtures/models.json', __dir__)))
    model['models'][0]['name'] = NAME
    model['models'][0]['base_class'] = NAME
    context = { 'schema_version' => 3, 'limits' => { 'max_facts' => 100_000, 'max_links' => 100_000,
      'max_entries' => 100_000, 'max_diagnostics' => 100 }, 'facts' => 0, 'links' => 0, 'diagnostics' => 0, 'fact_bytes' => 2 }
    batch = Thistle::Native.call('op' => 'model_batch', 'context' => context, 'observation' => model)
    model_id = batch.fetch('facts')[0].fetch('id')
    facts.concat(batch.fetch('facts'))
    registry = { 'name' => NAME, 'superclass' => nil, 'save' => { 'status' => 'observed', 'entries' => [] } }
    callbacks = Thistle::Native.call('op' => 'callback_batch', 'context' => context,
      'observation' => { 'version' => 1, 'active_record_version' => '8.1.4', 'root' => '/synthetic',
        'status' => 'observed', 'models' => [registry, registry] })
    facts.concat(callbacks.fetch('facts'))
    [{ 'schema_version' => 3, 'root_id' => 'a' * 64, 'producer' => {}, 'files' => [], 'diagnostics' => [],
      'coverage' => [{ 'family' => 'synthetic_recorded_domain', 'status' => 'partial',
        'scope' => 'Known saved labels only', 'reason' => 'No application capture or execution evidence' }], 'facts' => facts }, model_id]
  end
end
