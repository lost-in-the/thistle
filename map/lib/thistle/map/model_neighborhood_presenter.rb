# frozen_string_literal: true

require 'erb'
require 'json'
require_relative 'navigation_context'

module Thistle
  module Map
    # Rust selects the semantic rows. This class budgets and presents those rows.
    class ModelNeighborhoodPresenter
      class DisplayLimit < StandardError; end
      MAX_BODY_BYTES = 65_536
      NATIVE_BYTES = 32_768
      TEXT_GROWTH = 5 # &: 1 JSON byte -> 5 HTML bytes; JSON quote escaping costs 2.
      CURSOR_BYTES = NavigationContext::MAX_CURSOR_BYTES * 3 + 128
      COST_COUNTERS = %w[reference_attempts completed_reference_steps transient_reservation_bytes source_attempts].freeze
      USAGE_COUNTERS = %w[returned_items wire_bytes_including_envelope_and_newline].freeze
      # These required numeric headers are never rendered. Count their minimum
      # JSON bytes instead of charging HTML expansion for invisible accounting.
      # Validation below guarantees the credited fields; larger counters and all
      # other non-rendered cost fields receive no additional speculative credit.
      HIDDEN_ENVELOPE_BYTES = JSON.generate('version' => 1,
        'cost' => COST_COUNTERS.to_h { |key| [key, 0] },
        'usage' => USAGE_COUNTERS.to_h { |key| [key, 0] }).bytesize
      # Joint admission targets a compact page; it is not a promise that arbitrary
      # 4096-byte saved labels fit. The literal Rust-shaped 24-ID/256-q regression
      # measures the mandatory envelope + four long candidate identities.
      COMPACT_PAGE_TARGET = 4626 # measured literal four-long-candidate useful-page fixture

      def self.url_bytes(navigation)
        # Forecast only, never a target identity: every real candidate ID has
        # these same 64 hex bytes. Count escaped attributes exactly through Nav.
        # Sixteen bytes cover the physical #L fragment; longer continuation and
        # collection paths/controls use the separate CURSOR_BYTES reserve.
        ERB::Util.html_escape(navigation.url('/source', 'id' => '0' * 64)).bytesize + 16
      end

      def self.layout_reserve(navigation)
        # Unchanged View layout: brand + five navigation links + collection = 7;
        # form values cost <=2 encoded-query units. Include its cursor and markup.
        4096 + (navigation.model_id ? 10 : 9) * url_bytes(navigation) + CURSOR_BYTES
      end

      def self.row_links(family, direction)
        return 0 if %w[columns database].include?(family)
        return 1 if family == 'candidates' || direction == 'incoming'

        4 # one physical Source/Links href per candidate; no duplicate Links href
      end

      def self.request_bytes(navigation, limit, family: 'edges', direction: 'outgoing')
        unit = url_bytes(navigation)
        # One shared GET form for all family/filter/candidate controls, plus one
        # continuation href. No query state is repeated for each filter button.
        controls = 2048 + 3 * unit + CURSOR_BYTES
        remaining = MAX_BODY_BYTES - layout_reserve(navigation) - controls -
          row_links(family, direction) * limit * unit
        [remaining / TEXT_GROWTH + HIDDEN_ENVELOPE_BYTES, NATIVE_BYTES].min
      end

      def self.admission(navigation, family: 'edges', direction: 'outgoing')
        8.downto(1) do |limit|
          bytes = request_bytes(navigation, limit, family: family, direction: direction)
          return [limit, bytes] if bytes >= COMPACT_PAGE_TARGET
        end
        raise DisplayLimit, 'Navigation context leaves no useful model page; narrow search or continue with fewer collected IDs.'
      end

      def self.page_limit(navigation, family: 'edges', direction: 'outgoing')
        admission(navigation, family: family, direction: direction).first
      end

      def initialize(answer, navigation:, generation:, id:, family:, direction:, type:, candidate: nil, cursor: nil, limit: 8, max_bytes: 32768)
        @answer, @navigation, @generation, @id = answer, navigation, generation, id
        @family, @direction, @type, @candidate, @cursor = family, direction, type, candidate, cursor
        @layout_reserve = self.class.layout_reserve(navigation)
        unless answer.instance_of?(Hash) && JSON.generate('ok' => true, 'result' => answer).bytesize + 1 <= max_bytes &&
            answer['version'] == 1 && answer.values_at('generation', 'family', 'direction', 'type', 'candidate') == [generation, family, direction, type, candidate] &&
            answer['items'].instance_of?(Array) && answer['items'].length <= limit && answer['model'].instance_of?(Hash) &&
            answer['cost'].instance_of?(Hash) && answer['usage'].instance_of?(Hash) &&
            COST_COUNTERS.all? { |key| answer['cost'][key].instance_of?(Integer) && answer['cost'][key] >= 0 } &&
            USAGE_COUNTERS.all? { |key| answer['usage'][key].instance_of?(Integer) && answer['usage'][key] >= 0 } &&
            answer['semantics'].instance_of?(String) && answer['coverage'].instance_of?(Hash) &&
            [true, false].include?(answer.dig('coverage', 'page_complete')) &&
            answer.dig('coverage', 'default_presence') == 'not_recorded' &&
            answer.dig('coverage', 'database_constraints_indexes_on_delete') == 'not_recorded' &&
            answer.dig('coverage', 'candidate_count_unit') == 'saved_representations_not_distinct_model_definitions'
          invalid!('Model neighborhood envelope mismatch')
        end
        identity!(answer.fetch('root'))
        invalid!('Model neighborhood root mismatch') unless answer.dig('root', 'id') == id && answer.dig('root', 'kind') == 'rails_model'
        if family == 'candidates'
          context = answer.fetch('candidate_context')
          invalid!('Candidate context mismatch') unless context.instance_of?(Hash) && context['selector'] == candidate &&
            context['kind'] == (candidate.start_with?('a:') ? 'association' : 'reference') && (context['name'].nil? || context['name'].instance_of?(String)) &&
            (context['target_label'].nil? || context['target_label'].instance_of?(String))
        end
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
        body << controls
        if @navigation.model_id
          body << "<p>Table #{value(@answer.dig('model', 'table'))} · Primary key #{value(@answer.dig('model', 'primary_key'))}.</p>"
          body << "<details><summary>Saved model identity</summary><p>#{h(@id)} · Generation #{h(@generation)}</p></details>"
        else
          body << "<p>Saved model #{h(@id)} · Table #{value(@answer.dig('model', 'table'))} · Primary key #{value(@answer.dig('model', 'primary_key'))}. Generation #{h(@generation)}.</p>"
        end
        if @family == 'edges'
          body << "<p>Showing: #{h(@direction.capitalize)} · #{h(type_label(@type))}.</p>"
          body << unavailable('associations', 'Selected model association')
          body << '<h2 id="named-relationships">Named relationships</h2><p>Declared associations and original recorded references remain different evidence. Binding is unknown.</p><ol class="mn-edges">'
          @answer.fetch('items').each_with_index { |row, index| body << edge(row, index) }
          body << '</ol>'
          body << "<p>No #{@direction} #{h(type_label(@type).downcase)} rows returned on this page; unsearched and capture limits still apply.</p>" if @answer['items'].empty?
        elsif @family == 'columns'
          body << '<h2>Columns</h2><p>Raw recorded database values; default presence was not recorded. Literal null does not prove DEFAULT NULL. Ruby attribute defaults were not evaluated.</p>'
          body << unavailable('columns', 'Column')
          body << '<div class="mn-table" role="region" aria-label="Recorded columns" tabindex="0"><table><thead><tr><th>Name</th><th>Type / SQL type</th><th>Nullability</th><th>Raw default value</th></tr></thead><tbody>'
          @answer.fetch('items').each do |row|
            col = row.fetch('column')
            body << "<tr><th>#{value(col['name'])}</th><td>#{value(col['type'])} / #{value(col['sql_type'])}</td><td>#{value(col['null'])}</td><td>#{default(col.fetch('default'))}</td></tr>"
          end
          body << '</tbody></table></div>'
        elsif @family == 'database'
          body << '<h2>Database facts</h2><p>Physical database foreign keys, indexes and ON DELETE inventory were not recorded. They are unavailable, not known absent. Rails foreign_key and dependent options are declarations, not physical database constraints or DB ON DELETE.</p>'
        else
          context = @answer.fetch('candidate_context')
          body << "<h2>Saved representations for #{h(context.fetch('kind'))} #{value(context['name'])} → #{h(context['target_label'] || 'Unknown target')}</h2>"
          body << '<p>These are saved representations, not distinct model definitions or runtime bindings.</p><ul>'
          @answer.fetch('items').each { |row| body << "<li>#{identity_link(row.fetch('identity'))}</li>" }
          body << '</ul>'
        end
        if @answer['next_cursor']
          body << '<p>' + link('Continue recorded rows', route, 'id' => @id, 'candidate' => @candidate, 'cursor' => @answer['next_cursor']) + '</p>'
        end
        body << "<p class=\"notice ui\">#{h(@answer.fetch('semantics'))}</p>"
        body << '<details><summary>Coverage, counts and limits</summary><p>Only page_complete describes the selected remaining domain. last_reference_step describes one attempt, including row_retained; it is not whole-page completeness. Unknown remaining counts do not mean zero.</p>'
        body << "<pre>#{h(JSON.generate(@answer.fetch('coverage')))}</pre></details>"
        if @family == 'edges' && !@answer['items'].empty?
          svg = diagram
          if body.bytesize + svg.bytesize + @layout_reserve + 32 <= MAX_BODY_BYTES
            body << svg
          else
            body << '<p>Diagram omitted for this page’s label/context budget. The full named list contains every selected edge.</p>'
          end
        end
        body << '</section>'
        raise DisplayLimit, 'Model page exceeds the display budget; narrow the query/context or request a smaller page.' if body.bytesize + @layout_reserve > MAX_BODY_BYTES

        body
      end

      private

      def invalid!(message) = raise(Thistle::InvalidSnapshot, message)
      def h(value) = ERB::Util.html_escape(value.to_s)
      def value(data) = data.nil? ? 'Not recorded' : h(JSON.generate(data))
      def scope = ['model_neighborhood', @id, @family, @direction, @type, @candidate]
      def route(family = @family, direction = @direction, type = @type) = "/model-neighborhood/#{family}/#{direction}/#{type}"
      def link(label, path, controls) = "<a href=\"#{h(@navigation.url(path, controls))}\">#{h(label)}</a>"
      def action(path, controls) = URI.parse(@navigation.url(path, controls)).path
      def type_label(type) = { 'all' => 'All recorded types', 'association' => 'Associations', 'reference' => 'References' }.fetch(type)

      def controls
        # The largest button adds one candidate field. Derive shared fields from
        # that URL so atomic search-drop/9-field/4096-byte policy remains Nav-owned.
        uri = URI.parse(@navigation.url(route('candidates', 'outgoing', @type), 'id' => @id, 'candidate' => 'r:999999', 'cursor' => nil))
        fields = URI.decode_www_form(uri.query).reject { |key, _| key == 'candidate' }
        form = "<form id=\"mn-controls\" method=\"get\" action=\"#{h(action(route('edges', 'outgoing', 'all'), 'id' => @id, 'cursor' => nil))}\" aria-label=\"Model schema and relationship controls\">"
        form << fields.map { |key, data| "<input type=\"hidden\" name=\"#{h(key)}\" value=\"#{h(data)}\">" }.join
        form << '<p>'
        form << { 'edges' => 'Named relationships', 'columns' => 'Columns', 'database' => 'Database facts' }.map do |family, label|
          family == @family ? "<span aria-current=\"page\">#{label}</span>" : button(label, route(family, 'outgoing', 'all'))
        end.join(' · ')
        form << '</p>'
        if @family == 'edges'
          form << '<p>Direction: ' + %w[outgoing incoming].map { |direction| direction == @direction ? "<span aria-current=\"true\">#{direction.capitalize}</span>" : button(direction.capitalize, route('edges', direction, @type)) }.join(' · ') + '</p>'
          form << '<p>Type: ' + %w[all association reference].map { |type| type == @type ? "<span aria-current=\"true\">#{type_label(type)}</span>" : button(type_label(type), route('edges', @direction, type)) }.join(' · ') + '</p>'
        end
        form + '</form>'
      end

      def button(label, path)
        "<button type=\"submit\" formaction=\"#{h(action(path, 'id' => @id, 'cursor' => nil))}\">#{h(label)}</button>"
      end

      def unavailable(family, label)
        return '' unless @answer.dig('coverage', "#{family}_status") == 'unavailable'

        "<p class=\"notice ui\">#{label} observation unavailable (not known empty). Recorded references and capture limits remain separate.</p>"
      end

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
          row.fetch('candidates').each { |candidate| identity!(candidate) }
          if row['association']
            witness = row.fetch('witness')
            invalid!('Association witness mismatch') unless @direction == 'outgoing' && row['origin_id'] == @id && !row.key?('origin') &&
              witness['fact_id'] == @id && witness['family'] == 'associations' && witness['ordinal'].instance_of?(Integer) && witness['ordinal'] >= 0 &&
              row['association'].instance_of?(Hash) && row['association']['target'] == row['target_label'] && row['association']['macro'] == row['relation'] &&
              row['candidate_selector'] == "a:#{witness['ordinal']}"
          else
            identity!(row.fetch('origin'))
            recorded = row.fetch('recorded')
            invalid!('Reference witness mismatch') unless recorded.keys.sort == %w[detail_omitted link link_ordinal match_basis] &&
              recorded.dig('link', 'relation') == row['relation'] && recorded['link_ordinal'].instance_of?(Integer) && recorded['link_ordinal'] >= 0 &&
              (@direction != 'outgoing' || row['origin']['id'] == @id && row['candidate_selector'] == "r:#{recorded['link_ordinal']}")
          end
        elsif @family == 'columns'
          tagged = row.dig('column', 'default')
          invalid!('Invalid column row') unless row['kind'] == 'column' && row['column'].instance_of?(Hash) && tagged.instance_of?(Hash) &&
            %w[literal symbol expression opaque].include?(tagged['kind']) &&
            (!%w[literal symbol].include?(tagged['kind']) || tagged.key?('value')) &&
            !row['column'].key?('default_recorded') && !row['column'].key?('default_presence')
        elsif @family == 'candidates'
          invalid!('Invalid candidate row') unless row['kind'] == 'candidate'
          identity!(row.fetch('identity'))
        else
          invalid!('Database inventory must remain unavailable')
        end
      end

      def origin(row) = row['association'] ? @answer.fetch('root') : row.fetch('origin')

      def identity_link(identity)
        name = "#{identity.fetch('name')} (#{identity.fetch('kind')}, #{identity.fetch('evidence')})"
        return h(name) if identity.fetch('id') == @id

        if identity['path'] && identity['location']
          line = identity.fetch('location').fetch('start_line')
          href = @navigation.url('/source', 'id' => identity.fetch('id')) + "#L#{line}"
          "<a href=\"#{h(href)}\">#{h(name)} · #{h(identity['path'])}:#{line} Source</a>"
        else
          link(name, '/links', 'id' => identity.fetch('id')) + ' · Physical Source unavailable'
        end
      end

      # The full selected name is in the heading. Do not repeat an arbitrarily
      # long root label in every declaration row or reserve that repetition.
      def origin_name(row) = row['association'] ? 'This model' : origin(row).fetch('name')
      def endpoints(row) = [origin_name(row), row['target_label'] || 'Unknown / polymorphic target']

      def edge(row, index)
        from = row['association'] ? 'This model' : identity_link(origin(row))
        text = "<li id=\"mn-edge-#{index}\" data-neighborhood-edge=\"#{index}\"><p><strong>#{from} → #{h(row['target_label'] || 'Unknown / polymorphic target')}</strong> · #{h(row.fetch('relation'))} · #{h(row.fetch('direction'))} · #{h(row.fetch('type'))}</p>"
        text << "<p>#{h(row.fetch('target_status'))}. Binding unknown.</p>"
        if row['association']
          entry = row.fetch('association')
          text << "<p>Saved association declaration #{value(entry['name'])}; through #{value(entry['through'])}; polymorphic #{value(entry['polymorphic'])}; scope #{value(entry['scope'])}; omitted options #{value(entry['omitted_options'])}. Witness #{h(@id)} / associations / #{row.dig('witness', 'ordinal')}.</p>"
          text << "<details><summary>Recorded Rails association options</summary><pre>#{h(JSON.generate(entry.fetch('options')))}</pre><p>foreign_key and dependent are Rails options; physical DB foreign keys and ON DELETE were not recorded.</p></details>"
        else
          text << "<details><summary>Original recorded reference link and witness</summary><pre>#{h(JSON.generate(row.fetch('recorded')))}</pre></details>"
        end
        text << "<p>#{row.fetch('candidate_matches')} known saved representations; candidate search complete: #{h(row.fetch('candidate_search_complete'))}; #{row.fetch('candidate_known_omitted')} not displayed. These are not distinct model-definition counts.</p><ul>"
        row.fetch('candidates').each { |candidate| text << "<li>#{identity_link(candidate)}</li>" }
        text << '</ul>'
        if row['candidate_selector'] && row['candidate_known_omitted'].positive?
          path = action(route('candidates', 'outgoing', @type), 'id' => @id, 'candidate' => row['candidate_selector'], 'cursor' => nil)
          text << "<p><button type=\"submit\" form=\"mn-controls\" formaction=\"#{h(path)}\" name=\"candidate\" value=\"#{h(row['candidate_selector'])}\">Inspect all saved target representations</button></p>"
        end
        text + '</li>'
      end

      def diagram
        rows = @answer.fetch('items')
        svg = +'<details class="mn-diagram"><summary>Diagram of these same named edges</summary><p>The full named list is equivalent. Repeated endpoints are evidence rows, not additional model definitions.</p><div class="dia" role="region" aria-label="Same selected relationship edges" tabindex="0">'
        svg << "<svg class=\"dw\" xmlns=\"http://www.w3.org/2000/svg\" width=\"840\" height=\"#{rows.length * 80}\" role=\"img\" aria-label=\"One-hop relationships; equivalent named list above\">"
        rows.each_with_index do |row, index|
          from, to = endpoints(row); y = index * 80 + 18
          svg << "<g data-neighborhood-diagram-edge=\"#{index}\"><text x=\"8\" y=\"#{y}\">#{h(from)}</text><text x=\"24\" y=\"#{y + 22}\">→ #{h(to)}</text><text x=\"8\" y=\"#{y + 44}\">#{h(row['relation'])} · #{h(row['direction'])} · #{h(row['type'])}</text></g>"
        end
        svg + '</svg></div></details>'
      end

      def default(tagged)
        case tagged.fetch('kind')
        when 'literal', 'symbol' then "#{h(JSON.generate(tagged.fetch('value')))} (#{h(tagged['kind'])})"
        when 'expression' then 'Expression (text not recorded; not evaluated)'
        when 'opaque' then 'Opaque value (not evaluated)'
        end
      end
    end
  end
end
