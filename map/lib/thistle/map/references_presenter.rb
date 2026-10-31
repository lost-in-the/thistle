# frozen_string_literal: true

require 'erb'
require 'uri'
require_relative 'constant_occurrence'
require_relative 'navigation_context'

module Thistle
  module Map
    # Selection, ambiguity and limits belong to the native pinned Reader.
    class ReferencesPresenter
      MAX_OUTPUT_BYTES = 262_144

      def initialize(generation:, mount:, schema_version: nil, files: [], navigation: nil)
        @generation, @mount = generation, mount
        @files = files
        @navigation = navigation || NavigationContext.new(generation: generation, mount: mount)
        @occurrences = ConstantOccurrence.new(generation: generation, mount: mount, schema_version: schema_version, navigation: @navigation)
      end

      def render(result)
        raise Thistle::InvalidSnapshot, 'References substituted a different generation' unless result.fetch('generation') == @generation
        return candidate_page(result) if result.key?('candidate_link')

        raise Investigation::Limit, 'Reference page exceeds the row budget.' if result.fetch('relationships').length > 50

        coverage = result.fetch('coverage')
        body = +'<section aria-label="Recorded references"><h2 class="t2">Recorded references</h2>'
        body << '<p class="notice ui">Recorded relationship groups are not macro or textual occurrence counts. Name matches have binding unknown; neither equal labels nor recorded resolution prove runtime dispatch.</p>'
        body << "<p class=\"ui\">#{h(result.fetch('direction'))}: #{coverage.fetch('known_matches')} known matching groups; #{coverage.fetch('known_omitted')} known omitted by result/output limits. "
        body << (coverage.fetch('scan_complete') ? 'Relationship scan complete within this capture.' : 'Relationship scan incomplete for this page; additional input was not searched.')
        body << (coverage.fetch('capture_partial') ? ' Capture partial or unavailable; absence cannot prove no references.' : ' Capture coverage is scoped; see Check.')
        body << '</p>'
        if result.fetch('relationships').empty?
          body << '<p class="ui">No matching recorded relationships found in the searched evidence. This does not establish that the model has no references.</p>'
        end
        incoming = result.fetch('direction') == 'incoming'
        sizes = incoming ? source_sizes(result.fetch('relationships')) : {}
        result.fetch('relationships').each do |row|
          origin, link = row.fetch('origin'), row.fetch('link')
          body << "<article><h3>#{h(link.fetch('relation'))}: #{h(link.fetch('target'))}</h3>"
          body << "<p>Recorded at #{navigation(origin, candidate: false)} · #{source(origin)} · #{h(origin.fetch('evidence'))}; recorded resolution #{h(link.fetch('resolution'))}.</p>"
          # Outgoing site details belong to the paginated table, which verifies
          # its one bounded Source read. Do not duplicate them or contradict its
          # availability with this compact summary's conservative fallback.
          if incoming
            bytes = sizes[origin['path']]
            # The manifest has bytes, not newline counts. At most 10,000 bytes
            # proves at most 10,000 lines. Otherwise keep eligibility unknown.
            body << @occurrences.render(link, origin: origin, detail_omitted: row.fetch('detail_omitted'),
              source_bytes: bytes, line_budget_unknown: bytes.nil? || bytes > ConstantOccurrence::WEB_SOURCE_LINES)
          end
          body << "<p>Link detail omitted by display budget. Follow the recorded origin's Links page for captured details.</p>" if row.fetch('detail_omitted')
          candidates = row.fetch('candidates')
          body << "<p>#{row.fetch('candidate_matches')} known name-match candidates; binding unknown. "
          body << 'Additional candidates not searched. ' unless row.fetch('candidate_search_complete')
          body << 'Some known candidates omitted. ' if row.fetch('candidate_matches') > candidates.length
          body << 'No supported candidate to follow. ' if candidates.empty?
          raise Investigation::Limit, 'Reference row exceeds its candidate budget.' if candidates.length > 4
          body << candidates.map { |candidate| "#{navigation(candidate)} · #{source(candidate)}" }.join('; ')
          if (followup = row['candidate_followup']) && row.fetch('candidate_matches') > candidates.length
            unless followup['generation'] == @generation && followup['id'] == origin['id'] && followup['candidate_link'].instance_of?(Integer) && followup['candidate_link'] >= 0
              raise Thistle::InvalidSnapshot, 'Invalid candidate continuation'
            end
            target = @navigation.url('/references/outgoing', 'id' => origin['id'], 'candidate' => followup['candidate_link'].to_s, 'cursor' => nil)
            body << " · <a href=\"#{h(target)}\">Browse recorded label candidates</a>"
          end
          body << '</p></article>'
          check_budget!(body)
        end
        body << next_link(result, direction: result.fetch('direction')) << '</section>'
        check_budget!(body)
        body
      end

      private

      def candidate_page(result)
        candidates = result.fetch('candidates')
        raise Investigation::Limit, 'Candidate page exceeds the row budget.' if candidates.length > 8
        body = +'<section><h2>Recorded label candidates</h2><p>Names do not establish binding or runtime dispatch. '
        body << "#{h(result.fetch('candidate_matches'))} known matches; status #{h(result.fetch('candidate_status'))}. "
        body << "Search complete: #{h(result.fetch('candidate_search_complete'))}; capture partial: #{h(result.dig('coverage', 'capture_partial'))}.</p>"
        body << "<p>#{candidates.length} candidates returned on this page. An empty or shortened page does not establish absence.</p>"
        candidates.each do |fact|
          body << "<p>#{navigation(fact)} · #{source(fact)}</p>"
          check_budget!(body)
        end
        body << '<p>No candidate returned in this page; capture coverage and omitted evidence remain separate.</p>' if candidates.empty?
        body << next_link(result, direction: 'outgoing', candidate: result.fetch('candidate_link')) << '</section>'
        check_budget!(body)
        body
      end

      def next_link(result, direction:, candidate: nil)
        cursor = result['next_cursor']
        return '' unless cursor
        id = result.fetch('anchor').fetch('id')
        NavigationContext.validate_cursor!(cursor, generation: @generation, scope: ['references', id, direction == 'incoming', candidate])
        target = @navigation.url("/references/#{direction}", 'id' => id, 'cursor' => cursor, 'candidate' => candidate&.to_s)
        "<p><a href=\"#{h(target)}\">Next recorded #{candidate ? 'candidates' : 'references'} page</a> · More saved evidence remains; this page does not establish absence.</p>"
      end

      def check_budget!(body)
        raise Investigation::Limit, 'References exceed the rendered output budget; no partial page was returned.' if body.bytesize > MAX_OUTPUT_BYTES
      end

      def source_sizes(rows)
        # One pass over the already-pinned manifest, retaining only this page's
        # constant origins. No full file index, Source read or fact expansion.
        wanted = rows.each_with_object({}) do |row, paths|
          paths[row.fetch('origin')['path']] = nil if row.fetch('link')['relation'] == 'references_constant'
        end
        return wanted if wanted.empty? || !@files.instance_of?(Array)

        @files.each do |file|
          next unless file.instance_of?(Hash) && wanted.key?(file['path'])
          bytes = file['bytes']
          wanted[file['path']] = bytes if bytes.instance_of?(Integer) && bytes >= 0
        end
        wanted
      end

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end

      def href(path, id)
        @navigation.url(path, 'id' => id)
      end

      def navigation(fact, candidate: true)
        label = "#{fact.fetch('name')} (#{fact.fetch('kind')})"
        label += '; name match / binding unknown' if candidate
        "<a href=\"#{h(href('/links', fact.fetch('id')))}\">#{h(label)}</a>"
      end

      def source(fact)
        return 'No captured source' unless fact['path']

        "<a href=\"#{h(href('/source', fact.fetch('id')))}\">Captured Source: #{h(fact.fetch('path'))}</a>"
      end
    end
  end
end
