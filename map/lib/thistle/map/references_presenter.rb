# frozen_string_literal: true

require 'erb'
require 'uri'

module Thistle
  module Map
    # Selection, ambiguity and limits belong to the native pinned Reader.
    class ReferencesPresenter
      def initialize(generation:, mount:)
        @generation, @mount = generation, mount
      end

      def render(result)
        raise Thistle::InvalidSnapshot, 'References substituted a different generation' unless result.fetch('generation') == @generation

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
        result.fetch('relationships').each do |row|
          origin, link = row.fetch('origin'), row.fetch('link')
          body << "<article><h3>#{h(link.fetch('relation'))}: #{h(link.fetch('target'))}</h3>"
          body << "<p>Recorded at #{navigation(origin, candidate: false)} · #{source(origin)} · #{h(origin.fetch('evidence'))}; recorded resolution #{h(link.fetch('resolution'))}.</p>"
          body << "<p>Link detail omitted by display budget. Follow the recorded origin's Links page for captured details.</p>" if row.fetch('detail_omitted')
          candidates = row.fetch('candidates')
          body << "<p>#{row.fetch('candidate_matches')} known name-match candidates; binding unknown. "
          body << 'Additional candidates not searched. ' unless row.fetch('candidate_search_complete')
          body << 'Some known candidates omitted. ' if row.fetch('candidate_matches') > candidates.length
          body << 'No supported candidate to follow. ' if candidates.empty?
          body << candidates.map { |candidate| "#{navigation(candidate)} · #{source(candidate)}" }.join('; ')
          body << '</p></article>'
        end
        body << '</section>'
      end

      private

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end

      def href(path, id)
        "#{@mount}#{path}?#{URI.encode_www_form('generation' => @generation, 'id' => id)}"
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
