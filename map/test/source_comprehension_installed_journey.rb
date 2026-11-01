# frozen_string_literal: true

# UNRUN. Opt-in installed-only producer/consumer contract, not a source-phase
# helper or served/browser acceptance. Root supplies the finite execution lease.
raise 'Explicit installed LOS-147 execution admission required' unless ENV['THISTLE_LOS147_INSTALLED'] == '1'
require 'json'
require 'digest'
require 'fileutils'
require 'thistle'

def verify(condition, message)
  raise message unless condition
end

case ARGV.shift
when 'produce'
  fixture, root, store = ARGV
  raise 'Expected fixture, new source root and new store' unless fixture && root && store
  verify(!File.exist?(root) && !File.exist?(store), 'Disposable source/store must be new')
  FileUtils.mkdir_p(root, mode: 0o700)
  %w[parent concerns order caller].each { |name| FileUtils.cp(File.join(fixture, "#{name}.rb"), root) }
  require File.join(fixture, 'boot.rb')
  app = Los147.boot(root)
  saved = Thistle.capture(root: root, output: store, rails: app,
    source_comprehension: { models: [Los147::Order], stop_before: ActiveRecord::Base })
  expected = %w[parent concerns order caller].to_h do |name|
    ["#{name}.rb", Digest::SHA256.file(File.join(root, "#{name}.rb")).hexdigest]
  end
  # Only disposable fixture source is changed. A remains retained in the store.
  File.write(File.join(root, 'order.rb'), "class CurrentBReplacement; end\n")
  newer = Thistle.capture(root: root, output: store)
  verify(saved.fetch('generation') != newer.fetch('generation'), 'CURRENT did not advance')
  puts JSON.generate('generation_a' => saved.fetch('generation'), 'generation_b' => newer.fetch('generation'),
    'source_sha256' => expected, 'scope' => 'installed producer only; no served/person acceptance')
when 'consume'
  store, generation_a, generation_b = ARGV
  verify(store && generation_a && generation_b, 'Expected store, A, B')
  require 'thistle/map'
  verify(!defined?(Rails) && !defined?(ActiveRecord), 'Fresh consumer loaded producing framework')
  current = Thistle::Reader.new(store)
  begin
    verify(current.generation == generation_b, 'CURRENT is not B')
  ensure
    current.close
  end
  reader = Thistle::Reader.new(store, generation: generation_a)
  begin
    model = reader.find('Los147::Order').find { |fact| fact['kind'] == 'rails_model' && fact['name'] == 'Los147::Order' }
    verify(model, 'Missing saved loaded model')
    verify(reader.respond_to?(:source_comprehension), 'Root Reader integration is absent')
    contributions, missing, pages, outlines = [], [], 0, {}
    %w[contributions methods].each do |family|
      outlines[family] = []
      cursor = nil
      loop do
        pages += 1
        verify(pages <= 128, 'Family continuation exceeded finite journey allowance')
        page = reader.source_comprehension(model.fetch('id'), family: family, limit: 8, cursor: cursor)
        verify(page.fetch('generation') == generation_a, 'Comprehension lost A')
        verify(page.fetch('source_runtime_coherence') == 'unknown', 'Invented source/runtime coherence')
        verify(page.fetch('rows').length <= 8 && page.fetch('contributions').length <= 8, 'Reader exceeded the row/candidate page allowance')
        contributions.concat(page.fetch('contributions'))
        missing.concat(page.fetch('observed_only'))
        outlines[family].concat(page.fetch('rows'))
        next_page = page['continuation']
        break unless next_page
        verify(next_page.fetch('generation') == generation_a && next_page.fetch('id') == model.fetch('id') && next_page.fetch('family') == family, 'Invalid continuation scope')
        next_cursor = next_page.fetch('cursor')
        verify(next_cursor != cursor, 'Continuation made no progress')
        cursor = next_cursor
      end
    end
    %w[contributions methods].each do |family|
      rows = outlines.fetch(family)
      verify(rows.any? { |row| row['status'] == 'anonymous_owner_no_label_candidate' && row['returned'] == 0 }, "Anonymous owner was hidden in #{family}")
      verify(rows.any? { |row| row['owner'] == 'Los147::Parent' }, "Named suffix became unreachable in #{family}")
    end
    by_name = contributions.group_by { |row| row.fetch('fact').fetch('name') }
    verify(by_name.key?('Los147::Tagged#tag_text'), 'Missing included concern source')
    verify(by_name.key?('Los147::Parent#inherited_label'), 'Missing superclass source')
    prepend = by_name.fetch('Los147::Decorated#display_name')
    verify(prepend.any? { |row| row['status'] == 'observed_loaded_owner_source_binding_unknown' }, 'Prepend owner observation missing')
    duplicates = by_name.fetch('Los147::Order#duplicate_label')
    verify(duplicates.map { |row| row['fact']['id'] }.uniq.length == 2, 'Duplicate candidates collapsed')
    verify(duplicates.all? { |row| row['status'].start_with?('ambiguous_', 'unknown_') }, 'Saved duplicate was promoted to effective body')
    verify(missing.any? { |row| row['name'] == 'native_hash' }, 'Missing source descriptor was hidden')
    verify(!by_name.key?('Los147::Optional'), 'Conditional syntax became registered contribution')
    direct = by_name.fetch('Los147::Order#direct_label').first.fetch('fact')
    source = reader.source(direct.fetch('id'))
    verify(source.fetch('generation') == generation_a, 'Source lost A')
    verify(source.fetch('content').include?('def direct_label'), 'A source was replaced by B')
    verify(!source.fetch('content').include?('CurrentBReplacement'), 'Source fell back to current workspace')
    verify(source.fetch('sha256') == Digest::SHA256.hexdigest(source.fetch('content')), 'Physical source digest mismatch')
    location = direct.fetch('location')
    verify(source.fetch('content').lines.fetch(location.fetch('start_line') - 1).include?('def direct_label'), 'Physical line was renumbered')
    incoming = reader.references(direct.fetch('id'), direction: 'incoming', limit: 2)
    # The independent served investigator checks caller selection and its exact
    # source witness; this installed harness records the actual bounded response.
    puts JSON.generate('generation' => generation_a, 'model_id' => model.fetch('id'), 'pages' => pages,
      'direct_source_id' => direct.fetch('id'), 'direct_source_line' => location.fetch('start_line'),
      'incoming' => incoming, 'scope' => 'installed Reader only; served/screenshots/independent answers UNRUN')
  ensure
    reader.close
  end
when 'served'
  # The integration owner supplies an actual admitted focus URL. This test never
  # invents a route, starts a server, accepts a token or claims browser evidence.
  require 'net/http'
  require 'uri'
  require 'cgi'
  entry_text, generation_a = ARGV
  entry = URI(entry_text || '')
  verify(entry.is_a?(URI::HTTP) && entry.scheme == 'http' && %w[localhost 127.0.0.1].include?(entry.host) && !entry.userinfo,
    'Expected admitted loopback HTTP URL without credentials')
  original = URI.decode_www_form(entry.query || '').to_h
  verify(original['generation'] == generation_a, 'Entry URL must explicitly pin A')
  requests = 0
  fetch = lambda do |uri|
    verify(uri.host == entry.host && uri.port == entry.port && uri.scheme == entry.scheme, 'Cross-origin witness refused')
    requests += 1
    verify(requests <= 8, 'Served request allowance exceeded')
    body = +''
    Net::HTTP.start(uri.host, uri.port, open_timeout: 3, read_timeout: 3) do |http|
      http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
        verify(response.code == '200', "Served request failed: #{response.code}")
        response.read_body do |chunk|
          verify(body.bytesize + chunk.bytesize <= 1_048_576, 'Served body exceeds test allowance')
          body << chunk
        end
      end
    end
    body
  end
  links = lambda do |html|
    html.scan(/href="([^"]+)"/).flatten.map { |href| URI.join(entry.to_s, CGI.unescapeHTML(href)) }
  end
  page = fetch.call(entry)
  verify(page.include?('Model source comprehension') && page.include?('class="cv codeview"'), 'Missing primary source reading surface')
  witness = links.call(page).find { |uri| uri.fragment&.match?(/\AL[1-9][0-9]*\z/) }
  verify(witness, 'No exact physical Source witness')
  preserved = original.select { |key, _| %w[generation q kind prefix domain selection].include?(key) }
  verify(preserved.all? { |key, value| URI.decode_www_form(witness.query || '').to_h[key] == value }, 'Source witness lost context')
  source = fetch.call(witness)
  verify(source.include?("id=\"#{witness.fragment}\""), 'Physical Source line anchor missing')
  # The actual investigator separately exercises browser Back (including no-JS)
  # and Investigation. This HTTP control reopens the original admitted focus URL;
  # it does not claim that replaying a URL establishes browser-history behavior.
  reopened = fetch.call(entry)
  verify(reopened.include?('Model source comprehension'), 'Saved focus URL did not reopen the reading surface')
  puts JSON.generate('generation' => generation_a, 'http_requests' => requests, 'physical_line' => witness.fragment,
    'scope' => 'served HTTP link control only; browser/narrow/keyboard/screenshots/independent investigator UNRUN')
else
  raise 'Use produce FIXTURE NEW_ROOT NEW_STORE, consume STORE A B, or served ADMITTED_FOCUS_URL A'
end
