# frozen_string_literal: true

require 'erb'
require 'json'

module Thistle
  module Map
    # Presentation only. Core owns model validation and all evidence semantics.
    class ModelPresenter
      MAX_BYTES = 262_144
      MAX_ROWS = 200

      def self.render(fact)
        return '' unless fact['kind'] == 'rails_model'
        new.render(fact.dig('attributes', 'model'))
      end

      def render(data)
        return notice('Model details unavailable: unknown format.') unless data.is_a?(Hash) && data['version'] == 1
        return notice('Model details exceed the web display budget. Use the Reader fact API for the complete evidence.') if JSON.generate(data).bytesize > MAX_BYTES

        columns = data.fetch('columns')
        associations = data.fetch('associations')
        body = '<section aria-label="Loaded model"><h2>Loaded model</h2>'
        body += notice('Loaded inventory only. Targets and base classes are labels, not runtime dispatch. Source/runtime coherence is unknown; source unavailable.')
        body += '<dl>' + {
          'Model label' => data['name'], 'Base model label' => data['base_class'], 'Superclass label' => data['superclass'],
          'Abstract' => data['abstract'], 'Table' => data['table'], 'Primary key' => data['primary_key'],
          'STI inheritance column' => data['inheritance_column'], 'Active Record version' => data['active_record_version']
        }.map { |key, value| "<dt>#{h(key)}</dt><dd>#{h(display(value))}</dd>" }.join + '</dl>'
        body += '<h3>Database columns</h3><p>Database defaults only. Ruby attribute defaults are not evaluated or represented.</p>'
        body += family(columns, ['Name', 'Type', 'SQL type', 'Allows null', 'Database default']) do |column|
          [column['name'], column['type'], column['sql_type'], display(column['null']), scalar(column['default'])]
        end
        body += '<h3>Observed associations</h3><p>Effective named reflections; not every textual macro occurrence. Through targets may remain unknown to avoid loading classes.</p>'
        body += family(associations, ['Name', 'Type', 'Target label', 'Through', 'Polymorphic', 'Scope', 'Declared options']) do |association|
          options = association.fetch('options').map { |key, value| "#{key}: #{scalar(value)}" }
          omitted = association.fetch('omitted_options')
          options << "#{omitted} options not represented" if omitted.positive?
          [association['name'], association['macro'], display(association['target']), display(association['through']),
            display(association['polymorphic']), association['scope'], options.empty? ? 'None observed' : options.join('; ')]
        end
        body + '</section>'
      rescue KeyError, TypeError, NoMethodError, JSON::GeneratorError
        notice('Model details unavailable: invalid evidence shape.')
      end

      private

      def family(data, headings)
        return notice('Unavailable; this is not evidence of an empty family.') unless data['status'] == 'observed'
        entries = data.fetch('entries')
        return '<p>No entries observed in this family.</p>' if entries.empty?
        rows = entries.first(MAX_ROWS).map do |entry|
          '<tr>' + yield(entry).map { |value| "<td>#{h(display(value))}</td>" }.join + '</tr>'
        end.join
        body = '<div class="table-wrap" role="region" tabindex="0" aria-label="Model evidence"><table class="tbl"><thead><tr>' +
          headings.map { |heading| "<th scope=\"col\">#{h(heading)}</th>" }.join + '</tr></thead><tbody>' + rows + '</tbody></table></div>'
        body += notice("Showing #{MAX_ROWS} of #{entries.length} entries. Use the Reader fact API for complete evidence.") if entries.length > MAX_ROWS
        body
      end

      def scalar(value)
        case value.fetch('kind')
        when 'literal' then JSON.generate(value.fetch('value'))
        when 'symbol' then ':' + JSON.generate(value.fetch('value'))
        when 'expression' then 'Database expression; not evaluated'
        else 'Opaque; not evaluated'
        end
      end

      def display(value)
        value.nil? ? 'Unknown' : value.is_a?(Array) ? value.map { |item| display(item) }.join(', ') : value
      end

      def h(value) = ERB::Util.html_escape(value.to_s)
      def notice(text) = "<p class=\"notice ui\">#{h(text)}</p>"
    end
  end
end
