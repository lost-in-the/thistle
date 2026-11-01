# frozen_string_literal: true

require 'erb'
require 'json'
require_relative 'navigation_context'

module Thistle
  module Map
    # Presentation only: one Rust page supplies the list and diagram verbatim.
    class ModelNeighborhoodPresenter
      MAX_BODY_BYTES = 65_536
      def self.page_limit(navigation)
        [[49_152 / (navigation.reference_url_bytes * 7 + 2048), 1].max, 8].min
      end

      def self.request_bytes(navigation, limit)
        [[(MAX_BODY_BYTES - 8192 - (limit * 7 + 12) * navigation.reference_url_bytes) / 4, 1024].max, 32768].min
      end

      def initialize(answer, navigation:, generation:, id:, family:, direction:, type:, candidate: nil, cursor: nil, limit: 8, max_bytes: 32768)
        @answer, @navigation, @generation, @id = answer, navigation, generation, id
        @family, @direction, @type, @candidate, @cursor = family, direction, type, candidate, cursor
        unless answer.instance_of?(Hash) && JSON.generate(answer).bytesize <= max_bytes && answer['version'] == 1 &&
            answer.values_at('generation', 'family', 'direction', 'type', 'candidate') == [generation, family, direction, type, candidate] &&
            answer['items'].instance_of?(Array) && answer['items'].length <= limit && answer['model'].instance_of?(Hash) &&
            answer['semantics'].instance_of?(String) && answer['coverage'].instance_of?(Hash) &&
            [true, false].include?(answer.dig('coverage', 'page_complete')) &&
            answer.dig('coverage', 'default_presence') == 'not_recorded' &&
            answer.dig('coverage', 'database_constraints_indexes_on_delete') == 'not_recorded' &&
            answer.dig('coverage', 'candidate_count_unit') == 'saved_representations_not_distinct_model_definitions'
          invalid!('Model neighborhood envelope mismatch')
        end
        identity!(answer.fetch('root'))
        invalid!('Model neighborhood root mismatch') unless answer.dig('root', 'id') == id && answer.dig('root', 'kind') == 'rails_model'
        answer.fetch('items').each { |row| validate_row!(row) }
        token = answer['next_cursor']
        if token
          NavigationContext.validate_cursor!(token, generation: generation, scope: scope)
          invalid!('Model neighborhood continuation made no progress') if token == cursor || answer.dig('coverage', 'page_complete')
        elsif answer.dig('coverage', 'page_complete') != true
          invalid!('Model neighborhood omitted its continuation')
        end
      rescue KeyError, TypeError, NoMethodError, JSON::NestingError
        invalid!('Malformed model neighborhood projection')
      end

      def render
        root = @answer.fetch('root')
        body = "<section class=\"model-neighborhood\"><h1 class=\"t1\">#{h(root.fetch('name'))}: model neighborhood</h1>"
        body << '<nav aria-label="Model schema and relationships"><p>'
        body << { 'edges' => 'Named relationships', 'columns' => 'Columns', 'database' => 'Database facts' }.map { |family, label| link(label, route(family, 'outgoing', 'all'), 'id' => @id, 'cursor' => nil) }.join(' · ')
        body << '</p></nav>'
        body << "<p>Saved model ID #{h(@id)} · Table #{value(@answer.dig('model', 'table'))} · Primary key #{value(@answer.dig('model', 'primary_key'))}. Generation #{h(@generation)}.</p>"
        if @family == 'edges'
          body << controls
          body << '<h2 id="named-relationships">Named relationships</h2><p>The list and optional diagram show exactly this page’s recorded edges. Targets and source candidates remain unbound.</p>'
          body << '<ol class="mn-edges">'
          @answer.fetch('items').each_with_index { |row, index| body << edge(row, index) }
          body << '</ol>'
          body << '<p>No matching edges returned on this page; unsearched and capture limits below still apply.</p>' if @answer['items'].empty?
          body << diagram unless @answer['items'].empty?
        elsif @family == 'columns'
          body << '<h2>Columns</h2><p>Raw recorded database column values. Default presence was not recorded; literal null does not prove an explicit DEFAULT NULL clause. Ruby attribute defaults were not evaluated.</p>'
          body << '<div class="mn-table" role="region" aria-label="Recorded columns" tabindex="0"><table><thead><tr><th>Name</th><th>Type / SQL type</th><th>Nullability</th><th>Raw default value</th></tr></thead><tbody>'
          @answer.fetch('items').each do |row|
            col = row.fetch('column')
            body << "<tr><th>#{value(col['name'])}</th><td>#{value(col['type'])} / #{value(col['sql_type'])}</td><td>#{value(col['null'])}</td><td>#{default(col)}</td></tr>"
          end
          body << '</tbody></table></div>'
        elsif @family == 'database'
          body << '<h2>Database facts</h2><p>Physical database foreign keys, indexes and ON DELETE inventory were not recorded. They are unavailable, not known absent. Table and key labels above retain this saved model’s identity. Rails foreign_key and dependent association options are declarations, not physical constraints or DB ON DELETE.</p>'
        else
          body << '<h2>Saved target representations</h2><p>These are named saved representations, not a count of distinct model definitions. Indexed, static and runtime representations do not establish separate implementations or runtime bindings.</p><ul>'
          @answer.fetch('items').each { |row| body << "<li>#{identity_links(row.fetch('identity'))}</li>" }
          body << '</ul>'
        end
        if @answer['next_cursor']
          body << '<p>' + link('Continue recorded rows', route, 'id' => @id, 'candidate' => @candidate, 'cursor' => @answer['next_cursor']) + '</p>'
        end
        body << "<p class=\"notice ui\">#{h(@answer.fetch('semantics'))}</p>"
        body << '<details><summary>Coverage, counts and limits</summary><p>Counts concern saved representations and this cursor domain. Unknown remaining counts do not mean zero; unsearched input remains unknown.</p>'
        body << "<pre>#{h(JSON.pretty_generate(@answer.fetch('coverage')))}</pre></details></section>"
        raise View::Limit, 'Model neighborhood markup exceeds its display budget.' if body.bytesize > MAX_BODY_BYTES

        body
      end

      private

      def invalid!(message) = raise(Thistle::InvalidSnapshot, message)
      def h(value) = ERB::Util.html_escape(value.to_s)
      def value(data) = data.nil? ? 'Not recorded' : h(JSON.generate(data))
      def scope = ['model_neighborhood', @id, @family, @direction, @type, @candidate]
      def route(family = @family, direction = @direction, type = @type) = "/model-neighborhood/#{family}/#{direction}/#{type}"
      def link(label, path, controls) = "<a href=\"#{h(@navigation.url(path, controls))}\">#{h(label)}</a>"

      def identity!(identity)
        unless identity.instance_of?(Hash) && Investigation::DIGEST.match?(identity['id'].to_s) &&
            %w[name kind evidence].all? { |key| identity[key].instance_of?(String) } &&
            (identity['path'].nil? || identity['path'].instance_of?(String)) &&
            (identity['location'].nil? || identity['location'].instance_of?(Hash))
          invalid!('Invalid saved neighborhood identity')
        end
        if identity['location']
          from, to = identity['location'].values_at('start_line', 'end_line')
          invalid!('Invalid saved physical Source span') unless from.instance_of?(Integer) && to.instance_of?(Integer) && from.positive? && to >= from
        end
      end

      def validate_row!(row)
        invalid!('Invalid neighborhood row') unless row.instance_of?(Hash)
        if @family == 'edges'
          unless row['kind'] == 'edge' && %w[association reference].include?(row['type']) && row['direction'] == @direction &&
              (@type == 'all' || row['type'] == @type) && row['relation'].instance_of?(String) &&
              (row['target_label'].nil? || row['target_label'].instance_of?(String)) && row['target_status'].instance_of?(String) &&
              row['binding'] == 'unknown' && row['candidates'].instance_of?(Array) && row['candidates'].length <= 4 &&
              row['candidate_matches'].instance_of?(Integer) && row['candidate_matches'] >= row['candidates'].length &&
              [true, false].include?(row['candidate_search_complete']) && row['candidate_known_omitted'].instance_of?(Integer)
            invalid!('Invalid selected neighborhood edge')
          end
          identity!(row.fetch('origin')); row.fetch('candidates').each { |candidate| identity!(candidate) }
          if row['association']
            witness = row.fetch('witness')
            invalid!('Association witness mismatch') unless @direction == 'outgoing' && row['origin'] == @answer['root'] &&
              witness['fact_id'] == @id && witness['family'] == 'associations' && witness['ordinal'].instance_of?(Integer) && witness['ordinal'] >= 0 &&
              row['association'].instance_of?(Hash) && row['association']['target'] == row['target_label'] && row['association']['macro'] == row['relation'] &&
              row['candidate_selector'] == "a:#{witness['ordinal']}"
          else
            recorded = row.fetch('recorded')
            invalid!('Reference witness mismatch') unless recorded['origin'] == row['origin'] && recorded['candidates'].nil? &&
              recorded.dig('link', 'relation') == row['relation'] && recorded['candidate_label'] == row['target_label'] &&
              recorded['link_ordinal'].instance_of?(Integer) && recorded['link_ordinal'] >= 0 &&
              (@direction != 'outgoing' || row['origin']['id'] == @id && row['candidate_selector'] == "r:#{recorded['link_ordinal']}")
          end
        elsif @family == 'columns'
          invalid!('Invalid column row') unless row['kind'] == 'column' && row['column'].instance_of?(Hash) &&
            [true, false].include?(row.dig('column', 'default_recorded')) && row.dig('column', 'default_presence') == 'not_recorded'
        elsif @family == 'candidates'
          invalid!('Invalid candidate row') unless row['kind'] == 'candidate'
          identity!(row.fetch('identity'))
        else
          invalid!('Database inventory must remain unavailable')
        end
      end

      def controls
        '<nav aria-label="Relationship filters"><p>Direction: ' + %w[outgoing incoming].map { |direction| link(direction.capitalize, route('edges', direction, @type), 'id' => @id, 'cursor' => nil) }.join(' · ') +
          '</p><p>Type: ' + { 'all' => 'All recorded types', 'association' => 'Associations', 'reference' => 'References' }.map { |type, label| link(label, route('edges', @direction, type), 'id' => @id, 'cursor' => nil) }.join(' · ') + '</p></nav>'
      end

      def identity_links(identity)
        name = "#{identity.fetch('name')} (#{identity.fetch('kind')}, #{identity.fetch('evidence')})"
        text = link(name, '/links', 'id' => identity.fetch('id'))
        if identity['path'] && identity['location']
          line = identity.fetch('location').fetch('start_line')
          href = @navigation.url('/source', 'id' => identity.fetch('id')) + "#L#{line}"
          text << " · <a href=\"#{h(href)}\">#{h(identity['path'])}:#{line} Source</a>"
        else
          text << ' · Physical Source unavailable'
        end
        text
      end

      def endpoints(row)
        [row.fetch('origin').fetch('name'), row['target_label'] || 'Unknown / polymorphic target']
      end

      def edge(row, index)
        from, to = endpoints(row)
        text = "<li id=\"mn-edge-#{index}\" data-neighborhood-edge=\"#{index}\"><p><strong>#{h(from)} → #{h(to)}</strong> · #{h(row.fetch('relation'))} · #{h(row.fetch('direction'))} · #{h(row.fetch('type'))}</p>"
        evidence_kind = row['association'] ? 'Saved association declaration' : 'Original recorded reference'
        text << "<p>#{evidence_kind}. #{h(row.fetch('target_status'))}. Binding unknown. Evidence: #{identity_links(row.fetch('origin'))}</p>"
        if row['association']
          text << "<p>Declared association #{value(row.dig('association', 'name'))}; through #{value(row.dig('association', 'through'))}; polymorphic #{value(row.dig('association', 'polymorphic'))}. Runtime declaration witness #{h(@id)} / associations / #{row.dig('witness', 'ordinal')}.</p>"
          text << "<details><summary>Recorded Rails association options</summary><pre>#{h(JSON.pretty_generate(row.fetch('association')))}</pre><p>foreign_key and dependent are Rails options; physical DB foreign keys and ON DELETE were not recorded.</p></details>"
        else
          text << "<details><summary>Original recorded link and witness</summary><pre>#{h(JSON.pretty_generate(row.fetch('recorded')))}</pre></details>"
        end
        text << "<p>#{row.fetch('candidate_matches')} known saved representations; candidate search complete: #{h(row.fetch('candidate_search_complete'))}; #{row.fetch('candidate_known_omitted')} not displayed. These are not distinct model-definition counts.</p><ul>"
        row.fetch('candidates').each { |candidate| text << "<li>#{identity_links(candidate)}</li>" }
        text << '</ul>'
        if row['candidate_selector'] && row['candidate_known_omitted'].positive?
          text << '<p>' + link('Inspect all saved target representations', route('candidates', 'outgoing', @type), 'id' => @id, 'candidate' => row['candidate_selector'], 'cursor' => nil) + '</p>'
        end
        text + '</li>'
      end

      def diagram
        rows = @answer.fetch('items')
        svg = +'<details class="mn-diagram"><summary>Diagram of these same named edges</summary><p>One row per selected edge; repeated endpoints are evidence rows, not additional model definitions. The full names and links are in the list above. Scroll this finite diagram if needed.</p><div class="dia" role="region" aria-label="Same selected relationship edges" tabindex="0">'
        svg << "<svg class=\"dw\" xmlns=\"http://www.w3.org/2000/svg\" width=\"840\" height=\"#{rows.length * 64}\" role=\"img\" aria-label=\"One-hop relationships; equivalent named list above\">"
        rows.each_with_index do |row, index|
          from, to = endpoints(row); y = index * 64 + 24
          svg << "<g data-neighborhood-diagram-edge=\"#{index}\"><title>#{h(from)} → #{h(to)} · #{h(row['relation'])}</title><text x=\"8\" y=\"#{y}\">#{h(from)}</text><text x=\"432\" y=\"#{y}\">#{h(to)}</text><path d=\"M 8 #{y + 12} H 816 l -8 -4 m 8 4 l -8 4\"/><text x=\"8\" y=\"#{y + 30}\">#{h(row['relation'])} · #{h(row['direction'])} · #{h(row['type'])}</text></g>"
        end
        svg + '</svg></div></details>'
      end

      def default(column)
        return 'Value not recorded; default presence not recorded' unless column.fetch('default_recorded')

        tagged = column['default']
        return 'Value unavailable; default presence not recorded' unless tagged.instance_of?(Hash)
        case tagged['kind']
        when 'literal', 'symbol' then "#{h(JSON.generate(tagged['value']))} (#{h(tagged['kind'])}; default presence not recorded)"
        when 'expression' then 'Expression (text not recorded; not evaluated)'
        when 'opaque' then 'Opaque value (not evaluated)'
        else 'Value kind unavailable'
        end
      end
    end
  end
end
