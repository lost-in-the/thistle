# frozen_string_literal: true

require 'erb'
require 'json'
require 'uri'
require 'digest'

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

      def initialize(generation:, mount: '', reader: nil)
        @generation, @mount, @reader = generation, mount, reader
      end

      def render(fact)
        return '' unless fact['kind'] == 'rails_save_callbacks'
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

      private

      def conditions(entry)
        %w[if unless].map do |polarity|
          values = entry[polarity]
          if values.nil?
            "#{polarity}: Unavailable; not evaluated"
          elsif values.empty?
            "#{polarity}: None registered"
          else
            "#{polarity}: " + values.map { |value| reference(value) }.join('; ')
          end
        end.join('<br>')
      end

      def reference(value)
        text = case value.fetch('kind')
        when 'method' then "Method :#{value.fetch('name')} · effective owner: #{value['owner'] || 'Unknown'}"
        when 'proc' then 'Proc; body opaque and not evaluated'
        when 'opaque' then 'Opaque reference; not evaluated or formatted'
        else 'Reference unavailable; not evaluated'
        end
        result = +h(text)
        hint = value['source']
        return result + ' · Source unavailable' unless hint
        result << " · location hint #{h(hint.fetch('path'))}:#{h(hint.fetch('line'))}"
        if captured_line?(hint)
          query = URI.encode_www_form('generation' => @generation, 'file' => Digest::SHA256.hexdigest(hint.fetch('path')))
          result << " · <a href=\"#{h(@mount)}/source?#{h(query)}#L#{hint.fetch('line')}\">Captured source (coherence unknown)</a>"
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
      rescue Thistle::Error
        false
      end

      def h(value) = ERB::Util.html_escape(value.to_s)
      def notice(text) = "<p class=\"notice ui\">#{h(text)}</p>"
    end
  end
end
