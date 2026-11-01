# frozen_string_literal: true

# MANUAL installed contract, UNRUN in the initial source-only phase. Root runs
# this outside the checkout with isolated GEM_HOME/GEM_PATH and a finite lease.
# Loading this file during a source suite does not launch installed/framework work.
if $PROGRAM_NAME == __FILE__
  require 'json'
  require 'open3'
  require 'rbconfig'
  require 'tmpdir'
  require 'fileutils'

  def demand(value, message)
    raise message unless value
  end

  def installed!
    require 'thistle'
    home = File.realpath(ENV.fetch('GEM_HOME'))
    demand(File.realpath(Gem.loaded_specs.fetch('thistle').full_gem_path).start_with?(home + '/'), 'Core not loaded from isolated gems')
    demand(Gem::Specification.find_all.none? { |s| %w[woods woods-map].include?(s.name) }, 'Woods runtime present')
  end

  def pages(reader, id, family)
    rows = []
    cursor = nil
    256.times do
      answer = reader.job_mail(id, family: family, limit: 1, cursor: cursor)
      demand(answer.fetch('generation') == reader.generation, 'Family changed generation')
      rows.concat(answer.fetch('items'))
      return rows if answer.fetch('page_complete')
      next_cursor = answer.fetch('next_cursor')
      demand(next_cursor && next_cursor != cursor, 'Family continuation made no progress')
      cursor = next_cursor
    end
    raise 'Family continuation exceeded fixture bound'
  end

  mode, fixture, store, generation, map_path = ARGV
  if mode == 'capture'
    installed!
    require File.join(fixture, 'booted_app.rb')
    app = JobMailFixture.boot
    demand(Rails.version == '8.1.4', 'LOS148 first installed fixture requires Rails 8.1.4')
    require 'thistle/job_mail_observer'
    observed = Thistle::JobMailObserver.new(app: app, root: fixture,
      jobs: [ReceiptJob, RegistryOverrideJob], mailers: [ReceiptMailer], framework_version: Rails.version,
      limits: { max_facts: 100, max_entries: 1000 }, evidence_budget: 262_144).call
    expected = JSON.parse(File.read(File.join(fixture, 'expected_cards.json')))
    registry = observed.fetch('classes').find { |c| c['name'] == 'ReceiptJob' }.fetch('rescue_handlers')
    demand(registry['status'] == 'observed', 'Supported framework registry unavailable')
    demand(registry['entries'].map { |r| r['exception'] } == expected.dig('registry', 'exceptions_in_registered_order'), 'Wrong registered exception order')
    demand(registry['entries'].map { |r| r['shared_with_superclass'] } == expected.dig('registry', 'shared_with_superclass'), 'Wrong inherited/local rows')
    demand(observed['classes'].find { |c| c['name'] == 'RegistryOverrideJob' }.dig('rescue_handlers', 'status') == 'unavailable', 'Application private getter was accepted')
    context = { jobs: [ReceiptJob, RegistryOverrideJob], mailers: [ReceiptMailer],
      templates: %w[app/views/receipt_mailer/receipt.html.erb app/views/receipt_mailer/_footer.html.erb] }
    a = Thistle.capture(root: fixture, output: store, rails: app, job_mail: context)
    source = File.join(fixture, 'app/jobs/application_job.rb')
    File.write(source, File.read(source).sub('attempts: 4', 'attempts: 7'))
    b = Thistle.capture(root: fixture, output: store, rails: app, job_mail: context)
    demand(a['generation'] != b['generation'], 'B did not publish changed bytes')
    puts JSON.generate('a' => a.fetch('generation'), 'b' => b.fetch('generation'))
  elsif %w[read served].include?(mode)
    installed!
    demand(!defined?(Rails), 'Reader process loaded Rails')
    reader = Thistle::Reader.new(store, generation: generation)
    begin
      registry = reader.find('ReceiptJob', limit: 50).find { |r| r['kind'] == 'rails_job_mail' && r['name'] == 'ReceiptJob' }
      demand(registry, 'Integrated installed capture omitted job registry')
      registrations = pages(reader, registry.fetch('id'), 'registrations')
      demand(registrations.map { |r| r.dig('registration', 'exception') } == %w[DeliveryTimeout MissingRecipient UnloadedDeliveryError], 'Saved A lost policy registry')
      declarations = pages(reader, registry.fetch('id'), 'declarations')
      parent = declarations.find { |r| r['role'] == 'superclass' }.fetch('candidate')
      policy = pages(reader, parent.fetch('id'), 'policy')
      demand(policy.any? { |r| r.dig('evidence', 'operation') == 'retry_on' && r.dig('evidence', 'options', 'attempts', 'source') == '4' }, 'Pinned A did not retain inherited retry options')
      perform = declarations.find { |r| r['role'] == 'perform' }.fetch('candidate')
      handoffs = pages(reader, perform.fetch('id'), 'handoff')
      %w[receipt archive digest dynamic_receipt].zip([1, 2, 0, 1]).each do |action, count|
        rows = handoffs.select { |r| r.dig('evidence', 'action') == action }
        demand(!rows.empty? && rows.all? { |r| r['candidate_matches'] == count }, "Wrong candidates for #{action}")
      end
      receipt = handoffs.find { |r| r.dig('evidence', 'action') == 'receipt' }.fetch('candidate')
      templates = pages(reader, receipt.fetch('id'), 'handoff')
      template = templates.find { |r| r.dig('evidence', 'kind') == 'template_selection' }.fetch('candidate')
      refs = pages(reader, template.fetch('id'), 'template_references')
      demand(refs.any? { |r| r.dig('evidence', 'name') == '@recipient' }, 'Template variable missing')
      demand(refs.any? { |r| r.dig('evidence', 'name') == 'receipt_heading' }, 'Template helper candidate missing')
      demand(refs.any? { |r| r.dig('candidate', 'path') == 'app/views/receipt_mailer/_footer.html.erb' }, 'Partial source path missing')
      demand(refs.none? { |r| %w[@escaped_only @comment_only imaginary_helper].include?(r.dig('evidence', 'name')) }, 'ERB literal/comment treated as code')
      dynamic = handoffs.find { |r| r.dig('evidence', 'action') == 'dynamic_receipt' }.fetch('candidate')
      demand(pages(reader, dynamic.fetch('id'), 'handoff').any? { |r| r.dig('evidence', 'status') == 'dynamic_unknown' }, 'Dynamic template selection asserted')
      demand(!defined?(Rails), 'Saved Reader analysis loaded Rails')
      if mode == 'served'
        require 'thistle/map'
        demand(map_path && map_path.start_with?('/'), 'Root must supply the actual integrated projection route')
        app = Thistle::Map::App.new(store: store)
        require 'uri'
        status, _, body = app.call('REQUEST_METHOD' => 'GET', 'PATH_INFO' => map_path, 'SCRIPT_NAME' => '',
          'QUERY_STRING' => URI.encode_www_form('id' => registry.fetch('id'), 'generation' => generation),
          'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1', 'rack.url_scheme' => 'http')
        html = body.each.to_a.join
        body.close if body.respond_to?(:close)
        demand(status == 200 && html.include?('Job, mailer and template evidence'), 'Integrated Map projection unavailable')
        demand(html.include?('Inspect declarations') && html.include?(generation), 'Map lost followable pinned family navigation')
      end
      puts JSON.generate('generation' => reader.generation, 'result' => 'bounded installed job/mail/ERB assertions passed', 'mode' => mode)
    ensure
      reader.close
    end
  else
    # Each subprocess is a fresh Ruby interpreter, without checkout -I flags.
    # Driver inherits the Root-owned process/output/deadline controls.
    fixture_source = File.expand_path('fixtures/los148_job_mail', __dir__)
    script = File.expand_path(__FILE__)
    Dir.mktmpdir('los148-installed-') do |directory|
      copied = File.join(directory, 'fixture')
      FileUtils.cp_r(fixture_source, copied)
      saved_store = File.join(directory, 'store')
      out, err, result = Open3.capture3(RbConfig.ruby, script, 'capture', copied, saved_store)
      demand(result.success?, "Capture subprocess failed: #{err}")
      tuple = JSON.parse(out.lines.last)
      projection_path = ENV.fetch('LOS148_MAP_PATH', '/job-mail/overview')
      %w[read served].each do |step|
        out, err, result = Open3.capture3(RbConfig.ruby, script, step, copied, saved_store, tuple.fetch('a'), projection_path)
        demand(result.success?, "#{step} subprocess failed: #{err}")
        puts out
      end
      puts JSON.generate(tuple.merge('served' => 'Rack integration exercised; actual served browser journey remains separate'))
    end
  end
end
