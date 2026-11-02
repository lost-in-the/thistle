# frozen_string_literal: true

# AUTHORED UNRUN: installed stdio protocol/equality probe, not an agent-quality
# verdict. Run only in an independently admitted fresh installed consumer.
require 'json'
require 'open3'
require 'optparse'
require 'timeout'
require 'thistle'
require 'thistle/mcp'

module SavedGenerationReaderInstalledProbe
  def self.run(argv)
    options = {}
    parser = OptionParser.new do |p|
      %w[store generation model-id source-id].each { |key| p.on("--#{key} VALUE") { |value| options[key] = value } }
    end
    raise 'explicit store, generation, model-id and source-id required' unless parser.parse(argv).empty? && options.keys.sort == %w[generation model-id source-id store]
    raise 'Rails/ActiveRecord must be absent' if defined?(Rails) || defined?(ActiveRecord)
    generation = options.fetch('generation')
    raise 'explicit SHA256 identities required' unless %w[generation model-id source-id].all? { |key| Thistle::MCP::Limits::ID.match?(options[key]) }
    # Installed paths and actual loaded native identity belong in the retained
    # external artifact report. A checkout load is a failed applicability gate.
    core = Gem.loaded_specs.fetch('thistle')
    adapter = Gem.loaded_specs.fetch('thistle-mcp')
    raise 'adapter package lacks executable' unless File.file?(File.join(adapter.full_gem_path, 'exe', 'thistle-mcp'))
    reader = nil
    stdin = stdout = stderr = wait = nil
    stderr_reader = nil
    report = { 'scope' => 'installed protocol/equality only; actual Codex/Claude investigation UNRUN',
      'generation' => generation, 'core' => core.full_gem_path, 'adapter' => adapter.full_gem_path, 'cases' => [] }
    Timeout.timeout(60) do
      reader = Thistle::Reader.new(options.fetch('store'), generation: generation)
      stdin, stdout, stderr, wait = Open3.popen3(File.join(adapter.full_gem_path, 'exe', 'thistle-mcp'),
        '--store', options.fetch('store'), '--generation', generation, pgroup: true)
      # Drain a finite private diagnostic allowance without deadlocking the peer.
      stderr_reader = Thread.new do
        bytes = 0
        while (chunk = stderr.read(4096))
          bytes += chunk.bytesize
          raise 'diagnostic allowance exceeded' if bytes > 65536
        end
        bytes
      end
      next_id = 0
      output_bytes = 0
      request = lambda do |method, params|
        next_id += 1
        stdin.puts(JSON.generate({ jsonrpc: '2.0', id: next_id, method: method, params: params }))
        stdin.flush
        line = stdout.gets("\n", Thistle::MCP::Limits::WIRE_BYTES)
        raise 'missing or oversized protocol response' unless line && line.end_with?("\n")
        output_bytes += line.bytesize
        raise 'cumulative protocol output allowance exceeded' if output_bytes > Thistle::MCP::Limits::TOTAL_WIRE_BYTES
        response = JSON.parse(line)
        raise 'protocol error or mismatched request identity' unless response['id'] == next_id && !response.key?('error')
        response.fetch('result')
      end
      request.call('initialize', { protocolVersion: '2025-11-25', capabilities: {}, clientInfo: { name: 'saved-generation-installed-probe', version: '1' } })
      stdin.puts(JSON.generate({ jsonrpc: '2.0', method: 'notifications/initialized' }))
      stdin.flush
      names = request.call('tools/list', {}).fetch('tools').map { |tool| tool.fetch('name') }.sort
      raise 'unexpected tool inventory' unless names == Thistle::MCP::Tools::DESCRIPTIONS.keys.sort
      tool_calls = 0
      tool = lambda do |name, args|
        tool_calls += 1
        raise 'probe call allowance exhausted; traversal INCOMPLETE' if tool_calls > 56
        result = request.call('tools/call', { name: "thistle_#{name}", arguments: { generation: generation }.merge(args) })
        data = result.fetch('structuredContent')
        raise 'text/structured answer mismatch' unless JSON.parse(result.fetch('content').first.fetch('text')) == data
        [data, result.fetch('isError')]
      end
      compare = lambda do |name, args, expected|
        data, error = tool.call(name, args)
        raise "#{name} refused" if error
        raise "#{name} differs from direct Reader" unless data.fetch('reader') == expected
        report['cases'] << name
        data.fetch('reader')
      end
      compare.call('find', { query: 'Order', domain: 'metadata', limit: 8 }, reader.search_evidence('Order', domain: 'metadata', limit: 8))
      model = options.fetch('model-id')
      compare.call('model_brief', { id: model, limit: 8 }, reader.model_brief(model, limit: 8, max_bytes: 32768))
      %w[incoming outgoing].each do |direction|
        cursor = nil
        loop do
          args = { id: model, direction: direction, limit: 8 }
          args[:cursor] = cursor if cursor
          expected = reader.references(model, direction: direction, limit: 8, cursor: cursor)
          page = compare.call('links', args, expected)
          # Do not discard candidate saturation. Follow every explicit native
          # candidate followup, including duplicates beyond the first four.
          page.fetch('relationships').each do |row|
            followup = row['candidate_followup']
            next unless followup
            candidate_cursor = nil
            loop do
              selection = { id: followup.fetch('id'), direction: 'outgoing', candidate_link: followup.fetch('candidate_link'), limit: 8 }
              selection[:cursor] = candidate_cursor if candidate_cursor
              candidate = compare.call('links', selection, reader.references(selection.fetch(:id), direction: 'outgoing',
                candidate_link: selection.fetch(:candidate_link), limit: 8, cursor: candidate_cursor))
              candidate_cursor = candidate['next_cursor']
              break unless candidate_cursor
            end
          end
          cursor = page['next_cursor']
          break unless cursor
        end
      end
      id = options.fetch('source-id')
      identity = reader.fact_identity(id)
      expected_source = reader.source_file(identity.fetch('fact').fetch('path'))
      source, error = tool.call('source', { id: id })
      raise 'source differs from direct Reader' if error || source.fetch('reader') != expected_source || source.fetch('selection') != identity.fetch('fact')
      compare.call('check', {}, reader.check)
      bad, error = tool.call('source', { id: id, generation: '0' * 64 })
      raise 'wrong generation did not refuse' unless error && bad.dig('refusal', 'code') == 'wrong_generation'
      stdin.close # Actual EOF and natural child exit; no success before wait.
      raise 'installed child failed' unless wait.value.success?
      report['diagnostic_bytes'] = stderr_reader.value
      report['tool_calls'] = tool_calls
      report['output_bytes'] = output_bytes
      report['rails_free'] = !defined?(Rails) && !defined?(ActiveRecord)
      raise 'framework activated' unless report['rails_free']
    end
    puts JSON.pretty_generate(report)
    0
  ensure
    begin
      reader&.close
    ensure
      stdin&.close unless stdin&.closed?
      if wait&.alive?
        Process.kill('TERM', -wait.pid)
        unless wait.join(5)
          Process.kill('KILL', -wait.pid)
          wait.join
        end
      end
      [stdout, stderr].compact.each { |io| io.close unless io.closed? }
      stderr_reader&.join(5)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    exit SavedGenerationReaderInstalledProbe.run(ARGV)
  rescue StandardError
    warn 'Saved-generation installed probe failed or incomplete; retain private diagnostics and candidate identity.'
    exit 1
  end
end
