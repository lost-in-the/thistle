# frozen_string_literal: true

require 'erb'
require 'json'
require 'uri'
require 'digest'
require_relative 'navigation_context'
require_relative 'constant_occurrence'

module Thistle
  module Map
    # Core validates semantics. This presenter reads only the supplied saved
    # generation, with bounded optional source expansion and no live app access.
    class CallbackPresenter
      MAX_BYTES = 262_144
      MAX_ROWS = 200
      MAX_SOURCE_LINES = 10_000 # Match the destination File Source view.
      MAX_SOURCE_FILES = 16
      MAX_SOURCE_BYTES = 1_048_576

      def initialize(generation:, mount: '', reader: nil, navigation: nil)
        @generation, @mount, @reader = generation, mount, reader
        @navigation = navigation || NavigationContext.new(generation: generation, mount: mount)
      end

      def render(fact)
        return '' unless fact['kind'] == 'rails_save_callbacks'
        explanation = explanation_for(fact)
        render_registry(fact) + explanation
      end

      # Core projection only. registered adds the existing filter/condition display;
      # no source expansion or query is performed by this entry point.
      def render_projection(result, registered: false)
        body = +'<section aria-label="Potential save callback effects"><h2>Potential save callback effects</h2>'
        body << notice(result.fetch('semantics'))
        body << "<p>Saved model: #{h(result['model'] || 'Anonymous')} · Registry: #{h(result.fetch('registry_status'))} · Observed execution: unknown</p>"
        result.fetch('callbacks').each do |row|
          analysis = row.fetch('explanation')
          body << "<article><h3>Registered position #{h(row.fetch('position'))} · #{h(row['kind'] || 'Unknown')}</h3>"
          if registered
            body << "<p>#{reference(row.fetch('filter'), source_hints_only: true)}</p>"
            body << "<p>Conditions (not evaluated): #{conditions(row, source_hints_only: true)}</p>"
            body << "<p>Inherited registered entry: #{h(row['inherited'].nil? ? 'Unknown' : row['inherited'])}; registration site unknown.</p>"
          end
          body << "<p>#{h(analysis.fetch('status'))}: #{h(analysis.fetch('reason'))}</p>"
          if analysis['binding'] == 'descriptor_matched_captured_declaration'
            method, source = analysis.fetch('method'), analysis.fetch('source')
            body << "<p>Descriptor-matched captured declaration: #{h(method.fetch('name'))} · #{h(source.fetch('path'))}:#{h(method.fetch('span').fetch('start_line'))} · runtime/source coherence unknown</p>"
            body << source_link(source, method.fetch('span').fetch('start_line'), method.fetch('name')) if registered
            analysis.fetch('effects').each do |effect|
              location = effect.fetch('call_span')
              body << "<p>Potential enqueue-style request: <code>#{h(effect.fetch('operation'))}</code></p>"
              body << "<pre><code>#{h(effect.fetch('source_excerpt'))}</code></pre>"
              body << notice('Supporting excerpt shortened; exact call span remains recorded.') if effect['excerpt_truncated']
              body << "<p>Captured SHA-256 #{h(source.fetch('sha256'))} · call bytes [#{h(location.fetch('start_byte'))}, #{h(location.fetch('end_byte'))})</p>"
              # Core verified the saved bytes/spans. The established File Source
              # destination has a separate 10,000-line display ceiling.
              if source.fetch('lines') <= MAX_SOURCE_LINES && location.fetch('start_line') <= MAX_SOURCE_LINES
                body << source_link(source, location.fetch('start_line'), 'Supporting captured source (coherence unknown)')
              end
            end
            body << notice("Known potential effects omitted: #{analysis.fetch('known_effects_omitted')}") if analysis.fetch('known_effects_omitted').positive?
          end
          body << notice('Potential effects are non-exhaustive; other effects may exist.') if analysis['effects_non_exhaustive']
          body << '</article>'
        end
        body << '<p>No callback rows returned; this does not establish an empty registered chain.</p>' if result.fetch('callbacks').empty?
        body << coverage_notices(result.fetch('coverage'))
        body + '</section>'
      end

      private

      def coverage_notices(coverage)
        body = +''
        if coverage['truncated'] || !coverage['declaration_scan_complete']
          body << notice("Explanation incomplete: #{coverage.fetch('rows_not_searched')} rows not searched; #{coverage.fetch('rows_metadata_omitted')} metadata rows and #{coverage.fetch('rows_output_omitted')} output rows omitted. Possible effects remain unknown.")
        end
        if coverage.dig('method_directory', 'status') == 'complete' && coverage['declaration_scan_complete']
          body << notice('Captured method candidate lookup completed for selected callbacks; original capture coverage is separate.')
        end
        if coverage.fetch('source_rows_not_searched', 0).positive?
          body << notice("Source evidence not searched for #{coverage.fetch('source_rows_not_searched')} returned callbacks; possible effects remain unknown.")
        end
        body << notice('Capture is partial or unknown; searched source cannot establish all possible effects.') if coverage['capture_partial_or_unknown']
        body
      end

      def render_registry(fact)
        data = fact.dig('attributes', 'callbacks')
        return notice('Registered callbacks unavailable: unknown format.') unless data.is_a?(Hash) && data['version'] == 1
        return notice('Callback details exceed the web display budget. Use the Reader fact API for complete evidence.') if JSON.generate(data).bytesize > MAX_BYTES
        @sources, @source_bytes = {}, 0
        body = +'<section aria-label="Registered save callbacks"><h2>Registered save callbacks</h2>'
        body << notice('Registered metadata only; callbacks and conditions were not executed. Positions are zero-based registered chain positions, not execution chronology. Around callbacks may wrap or halt work. Source/runtime coherence and registration sites are unknown.')
        body << "<p>Model: #{h(data['name'] || 'Anonymous')} · Active Record #{h(data['active_record_version'])}</p>"
        family = data.fetch('save')
        if family['status'] == 'unavailable'
          return body + notice('Save chain unavailable; this is not evidence of an empty chain.') + '</section>'
        end
        body << notice('Partial chain metadata; unknown entries or conditions remain.') if family['status'] == 'partial'
        entries = family.fetch('entries')
        return body + '<p>No registered save callbacks observed.</p></section>' if entries.empty?
        body << '<div class="table-wrap" role="region" tabindex="0" aria-label="Registered callback evidence"><table class="tbl"><caption>Registered save chain</caption><thead><tr>'
        body << ['Position', 'Kind', 'Filter and effective owner', 'Inheritance evidence', 'Conditions'].map { |title| "<th scope=\"col\">#{h(title)}</th>" }.join
        body << '</tr></thead><tbody>'
        entries.first(MAX_ROWS).each do |entry|
          body << "<tr><td>#{h(entry.fetch('position'))}</td><td>#{h(entry['kind'] || 'Unknown')}</td><td>#{reference(entry.fetch('filter'))}</td>"
          inheritance = case entry['inherited']
          when true then "Shared registered entry with superclass #{data['superclass'] || '(anonymous)'}; effective owner shown separately"
          when false then 'Not shared with immediate superclass; registration site unknown'
          else 'Superclass chain comparison unavailable'
          end
          body << "<td>#{h(inheritance)}</td><td>#{conditions(entry)}</td></tr>"
        end
        body << '</tbody></table></div>'
        body << notice("Showing #{MAX_ROWS} of #{entries.length} entries. Use the Reader fact API for complete evidence.") if entries.length > MAX_ROWS
        body + '</section>'
      rescue KeyError, TypeError, NoMethodError, JSON::GeneratorError
        notice('Registered callbacks unavailable: invalid evidence shape.')
      end

      def explanation_for(fact)
        heading = '<section aria-label="Potential save callback effects"><h2>Potential save callback effects</h2>'
        unless @reader && @reader.respond_to?(:callback_effects)
          return heading + notice('Source-supported explanation unavailable: Reader callback_effects API unavailable. Possible effects remain unknown.') + '</section>'
        end
        raise Thistle::InvalidSnapshot, 'Callback Reader generation mismatch' unless @reader.generation == @generation
        begin
          result = @reader.callback_effects(fact.fetch('id'), limit: MAX_ROWS)
        rescue Thistle::LimitExceeded
          return heading + notice('Source-supported explanation unavailable: resource limit. Possible effects remain unknown.') + '</section>'
        rescue Thistle::InvalidInput => error
          # A newer Ruby facade can be paired with an older native engine. Do
          # not swallow other parameter, integrity or implementation failures.
          raise unless error.message == 'Unknown native operation'
          return heading + notice('Source-supported explanation unavailable: native callback_effects API unavailable. Possible effects remain unknown.') + '</section>'
        end
        raise Thistle::InvalidSnapshot, 'Callback explanation generation or registry mismatch' unless result['generation'] == @generation && result['registry_id'] == fact.fetch('id')
        render_projection(result)
      end

      def source_link(source, line, label)
        unless line.is_a?(Integer) && line.positive?
          raise Thistle::InvalidSnapshot, 'Invalid callback physical source line'
        end
        return notice('Supporting Source exceeds this web view byte/line budget; use the Reader Source interface.') if
          line > MAX_SOURCE_LINES || source.fetch('lines') > MAX_SOURCE_LINES || source.fetch('bytes', 0) > ConstantOccurrence::WEB_SOURCE_BYTES
        file = Digest::SHA256.hexdigest(source.fetch('path'))
        target = if @navigation.model_id
                   @navigation.url('/source', { 'id' => nil, 'file' => file }, source_position: [file, line])
                 else
                   @navigation.url('/source', 'id' => nil, 'file' => file)
                 end
        "<p><a href=\"#{h(target)}#L#{line}\">#{h(label)} · #{h(source.fetch('path'))}:#{line}</a></p>"
      end

      def conditions(entry, source_hints_only: false)
        %w[if unless].map do |polarity|
          values = entry[polarity]
          if values.nil?
            "#{polarity}: Unavailable; not evaluated"
          elsif values.empty?
            "#{polarity}: None registered"
          else
            "#{polarity}: " + values.map { |value| reference(value, source_hints_only: source_hints_only) }.join('; ')
          end
        end.join('<br>')
      end

      def reference(value, source_hints_only: false)
        text = case value.fetch('kind')
        when 'method' then "Method :#{value.fetch('name')} · effective owner: #{value['owner'] || 'Unknown'}"
        when 'proc' then 'Proc; body opaque and not evaluated'
        when 'opaque' then 'Opaque reference; not evaluated or formatted'
        else 'Reference unavailable; not evaluated'
        end
        # ActiveSupport's html_escape may return a SafeBuffer whose << escapes
        # appended markup. Own a plain String, keeping untrusted text escaped.
        result = String.new(h(text))
        hint = value['source']
        return result + ' · Source unavailable' unless hint
        result << " · location hint #{h(hint.fetch('path'))}:#{h(hint.fetch('line'))}"
        return result + ' · Source hint only; captured file not expanded in this view' if source_hints_only
        if captured_line?(hint)
          target = @navigation.url('/source', 'id' => nil, 'file' => Digest::SHA256.hexdigest(hint.fetch('path')))
          result << " · <a href=\"#{h(target)}#L#{hint.fetch('line')}\">Captured source (coherence unknown)</a>"
        else
          result << ' · Captured source unavailable or outside display budget'
        end
        result
      end

      def captured_line?(hint)
        return false unless @reader && @reader.generation == @generation
        path, line = hint.fetch('path'), hint.fetch('line')
        return false unless line.is_a?(Integer) && line.positive?
        unless @sources.key?(path)
          return false if @sources.length >= MAX_SOURCE_FILES
          @sources[path] = nil # Missing/oversized files also consume an attempt.
          file = @reader.manifest.fetch('files').find { |item| item['path'] == path }
          return false unless file && file['bytes'].is_a?(Integer) && file['bytes'] <= MAX_BYTES && file['bytes'] >= 0
          return false if @source_bytes + file['bytes'] > MAX_SOURCE_BYTES
          @source_bytes += file['bytes']
          saved = @reader.source_file(path)
          if saved['generation'] == @generation && saved.dig('file', 'path') == path && saved.dig('file', 'sha256') == file['sha256']
            content = saved.fetch('content')
            newlines = content.count("\n")
            if content.bytesize == file['bytes'] && Digest::SHA256.hexdigest(content) == file['sha256'] && newlines <= MAX_SOURCE_LINES
              @sources[path] = newlines + (content.end_with?("\n") ? 0 : 1)
            end
          end
        end
        @sources[path] && line <= @sources[path]
      rescue Thistle::NotFound, Thistle::LimitExceeded
        false
      end

      def h(value) = ERB::Util.html_escape(value.to_s)
      def notice(text) = "<p class=\"notice ui\">#{h(text)}</p>"
    end
  end
end
