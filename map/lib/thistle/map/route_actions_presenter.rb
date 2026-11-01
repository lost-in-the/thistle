# frozen_string_literal: true

require 'erb'
require 'json'
require_relative 'navigation_context'

module Thistle
  module Map
    # Displays Native's selection. NavigationContext is the sole URL authority.
    class RouteActionsPresenter
      MAX_BODY_BYTES = 65_536
      STATUSES = {
        'unique_static_candidate_binding_unknown' => 'One conventional static candidate; binding unknown',
        'ambiguous_static_candidates' => 'Multiple static candidates; no definition selected',
        'no_eligible_recorded_candidate' => 'No eligible recorded candidate; inherited or uncaptured actions remain unknown',
        'discovery_incomplete' => 'Discovery incomplete; visible candidates do not establish complete coverage',
        'unsupported_route_or_naming' => 'Unsupported route or naming; target unresolved'
      }.freeze

      def self.page_limit(navigation)
        [[(MAX_BODY_BYTES / 2) / (navigation.reference_url_bytes * 2), 1].max, 8].min
      end

      def self.identity!(fact, generation:, kind:, id: nil)
        unless fact.instance_of?(Hash) && fact.keys.sort == %w[evidence generation id kind name path span] &&
            fact['generation'] == generation && Investigation::DIGEST.match?(fact['id'].to_s) && (!id || fact['id'] == id) &&
            fact['kind'] == kind && fact['name'].instance_of?(String) && fact['name'].bytesize <= 4096 &&
            fact['evidence'] == (kind == 'route' ? 'runtime' : 'static') &&
            (fact['path'].nil? || (fact['path'].instance_of?(String) && fact['path'].bytesize <= 4096))
          raise Thistle::InvalidSnapshot, 'Route action witness identity mismatch'
        end
        span = fact['span']
        if span
          unless span.instance_of?(Hash) && span.keys.sort == %w[end_byte end_line start_byte start_line] &&
              span.values.all? { |v| v.instance_of?(Integer) && v >= 0 } && span['start_line'].positive? &&
              span['end_line'] >= span['start_line'] && span['end_byte'] >= span['start_byte'] && fact['path']
            raise Thistle::InvalidSnapshot, 'Invalid saved route action span'
          end
        end
        raise Thistle::InvalidSnapshot, 'Recorded route invented a physical source position' if kind == 'route' && (fact['path'] || span)
      end

      def self.validate!(answer, generation:, id:, cursor: nil, limit: 8)
        unless answer.instance_of?(Hash) && JSON.generate(answer).bytesize <= 32768 && answer['version'] == 1 &&
            answer['generation'] == generation && STATUSES.key?(answer['status']) &&
            %w[route naming coverage candidate_count unknowns usage].all? { |key| answer[key].instance_of?(Hash) } &&
            answer['semantics'].instance_of?(String) &&
            %w[binding coherence dispatch reachability execution].all? { |key| answer['unknowns'][key] == 'unknown' }
          raise Thistle::InvalidSnapshot, 'Route actions envelope mismatch'
        end
        identity!(answer.fetch('root'), generation: generation, id: id, kind: 'route')
        unless answer.dig('route','attributes').instance_of?(Hash) && answer.dig('route','links').instance_of?(Array) &&
            answer.dig('candidate_count','lower_bound').instance_of?(Integer) && answer.dig('candidate_count','lower_bound') >= 0 &&
            [true,false].include?(answer.dig('candidate_count','exact')) &&
            %w[capture_partial_or_unknown discovery_complete page_complete work_partial remaining].all? { |key| [true,false].include?(answer['coverage'][key]) } &&
            answer['offset'].instance_of?(Integer) && answer['offset'] >= 0
          raise Thistle::InvalidSnapshot, 'Invalid route actions coverage'
        end
        rows = answer.fetch('candidates')
        raise Thistle::InvalidSnapshot, 'Invalid route actions candidates' unless rows.instance_of?(Array) && rows.length <= limit
        naming, count, coverage = answer.values_at('naming','candidate_count','coverage')
        unless naming['rule'] == 'ascii_snake_path_v1' && %w[unsupported conventional_labels_only].include?(naming['status']) &&
            naming['reason'].instance_of?(String) && %w[owner action].all? { |key| naming[key].nil? || (naming[key].instance_of?(String) && naming[key].bytesize <= 4096) } &&
            count['lower_bound'] >= answer['offset'] + rows.length && coverage['remaining'] == !coverage['page_complete']
          raise Thistle::InvalidSnapshot, 'Route actions naming/count envelope mismatch'
        end
        complete = coverage['discovery_complete'] && !coverage['capture_partial_or_unknown']
        consistent = case answer['status']
                     when 'unique_static_candidate_binding_unknown' then complete && count['exact'] && count['lower_bound'] == 1
                     when 'ambiguous_static_candidates' then complete && count['lower_bound'] >= 2
                     when 'no_eligible_recorded_candidate' then complete && count['exact'] && count['lower_bound'].zero? && rows.empty?
                     when 'discovery_incomplete' then !complete
                     when 'unsupported_route_or_naming' then naming['status'] == 'unsupported' && rows.empty? && !coverage['discovery_complete']
                     end
        raise Thistle::InvalidSnapshot, 'Route actions status contradicts saved coverage/count witnesses' unless consistent
        ids = []
        rows.each do |row|
          raise Thistle::InvalidSnapshot, 'Invalid route actions row' unless row.instance_of?(Hash)
          fact = row.fetch('fact')
          identity!(fact, generation: generation, kind: 'method')
          raise Thistle::InvalidSnapshot, 'Repeated candidate identity' if ids.include?(fact['id'])
          ids << fact['id']
          if row['source_status'] == 'saved_source_available'
            unless fact['path'] && fact['span'] && row['source'] == { 'operation'=>'source', 'generation'=>generation, 'id'=>fact['id'] }
              raise Thistle::InvalidSnapshot, 'Route action Source witness mismatch'
            end
          elsif row['source_status'] != 'saved_source_absent' || row['source'] || (fact['path'] && fact['span'])
            raise Thistle::InvalidSnapshot, 'Invalid absent Source witness'
          end
        end
        next_cursor = answer['next_cursor']
        request = answer['continuation']
        if answer.dig('coverage','page_complete')
          raise Thistle::InvalidSnapshot, 'Complete route actions page has continuation' if next_cursor || request
        else
          expected = { 'operation'=>'route_actions', 'generation'=>generation, 'id'=>id, 'cursor'=>next_cursor }
          unless next_cursor.instance_of?(String) && next_cursor != cursor && request == expected && !rows.empty?
            raise Thistle::InvalidSnapshot, 'Route actions continuation made no progress'
          end
          NavigationContext.validate_cursor!(next_cursor, generation: generation, scope: ['route_actions',id])
          position = JSON.parse(next_cursor).last(2)
          unless position == [answer['offset'] + rows.length,0]
            raise Thistle::InvalidSnapshot, 'Route actions continuation skipped candidates'
          end
        end
        answer
      rescue KeyError, TypeError, JSON::GeneratorError, JSON::NestingError, Investigation::Invalid => error
        raise Thistle::InvalidSnapshot, "Invalid route actions projection (#{error.class})"
      end

      def initialize(navigation:)
        @navigation = navigation
      end

      def render(answer)
        body = +'<section aria-label="Recorded route action candidates"><h2>Controller/action candidates</h2>'
        body << "<p class=\"notice ui\">#{h(STATUSES.fetch(answer.fetch('status')))}</p>"
        body << "<p>#{h(answer.fetch('semantics'))}</p>"
        naming = answer.fetch('naming')
        body << "<p>Conventional owner: #{h(naming['owner'] || 'Unresolved')}; action: #{h(naming['action'] || 'Unresolved')}. #{h(naming['reason'])}</p>"
        body << '<details open><summary>Original saved route defaults, constraints and provenance</summary>' \
          "<pre class=\"check-data\">#{h(JSON.pretty_generate(answer.fetch('route')))}</pre></details>"
        answer.fetch('candidates').each do |row|
          fact = row.fetch('fact')
          body << "<article><h3>#{h(fact.fetch('name'))}</h3><p>#{h(fact['path'] || 'No saved physical source')}</p>"
          if row['source']
            href = @navigation.url('/source', 'id' => fact.fetch('id')) + "#L#{fact.fetch('span').fetch('start_line')}"
            body << "<p><a href=\"#{h(href)}\">Open exact saved Source at line #{fact.fetch('span').fetch('start_line')}</a></p>"
          else
            body << '<p class="notice ui">No physical source mapping was saved for this candidate.</p>'
          end
          body << '</article>'
        end
        body << '<p>No candidates returned on this page. Coverage and unsupported naming remain explicit.</p>' if answer.fetch('candidates').empty?
        body << "<p>Candidate count #{answer.dig('candidate_count','exact') ? 'exact' : 'at least'}: #{h(answer.dig('candidate_count','lower_bound'))}.</p>"
        body << "<pre class=\"check-data\">#{h(JSON.pretty_generate(answer.slice('coverage','unknowns')))}</pre>"
        if answer['continuation']
          body << "<p><a href=\"#{h(@navigation.url('/route-actions', 'id'=>answer.fetch('root').fetch('id'), 'cursor'=>answer.fetch('next_cursor')))}\">Continue saved action candidates</a></p>"
        end
        body << '</section>'
        raise Investigation::Limit, "Route actions page exceeds display budget; inspect the route's bounded Source context instead." if body.bytesize > MAX_BODY_BYTES
        body
      end

      private

      def h(value) = ERB::Util.html_escape(value.to_s)
    end
  end
end
