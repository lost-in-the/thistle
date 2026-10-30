# frozen_string_literal: true

# Saved primitives only: no Rails boot, reflection, database or records.
module SavedFindModels
  def self.publish(root:, store:)
    FileUtils.mkdir_p(root)
    File.write(File.join(root, 'order.rb'), "class Item; end\nclass Payment; end\n")
    capture = Thistle::Capture.new(root: root).call
    observation = JSON.parse(File.read(File.join(__dir__, '../../engine/tests/fixtures/models.json')))
    observation.fetch('models') << Marshal.load(Marshal.dump(observation.fetch('models').first))
    context = { 'limits' => capture.fetch('producer').fetch('effective_limits').slice('max_facts', 'max_links', 'max_entries', 'max_diagnostics'),
      'facts' => capture.fetch('facts').length, 'links' => 0, 'diagnostics' => capture.fetch('diagnostics').length,
      'fact_bytes' => JSON.generate(capture.fetch('facts')).bytesize }
    added = Thistle::Native.call('op' => 'model_batch', 'context' => context, 'observation' => observation)
    capture.fetch('facts').concat(added.fetch('facts'))
    capture.fetch('coverage').concat(added.fetch('coverage'))
    capture.fetch('producer')['model_observer'] = added.fetch('model_observer')
    Thistle::Store.new(store).publish(capture)
  end
end
