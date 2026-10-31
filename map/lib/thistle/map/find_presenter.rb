# frozen_string_literal: true

require 'erb'
require 'uri'
require 'digest'
require_relative 'investigation'

module Thistle
  module Map
    # Renders evidence returned by the bounded Find operation. Routing and the
    # surrounding layout remain the application's responsibility.
    class FindPresenter
      MAX_QUERY_BYTES = Investigation::MAX_QUERY_BYTES
      SEARCH_FIELDS = %w[q domain kind prefix].freeze

      # The generation selects the manifest; this fixed-size key selects its path.
      def self.file_reference(path)
        Digest::SHA256.hexdigest(path)
      end

      def initialize(generation:, mount: '', search: {}, selection: nil)
        @generation = generation
        @mount = mount
        @search = search.slice(*SEARCH_FIELDS)
        @selection = selection
        raise ArgumentError, 'Find selection must be normalized investigation state' if selection && !selection.instance_of?(Investigation)
        raise ArgumentError, 'Find selection generation mismatch' if selection && selection.generation != generation
      end

      def render(result)
        raise ArgumentError, 'Find generation mismatch' unless result.fetch('generation') == @generation

        status = result.fetch('status')
        raise ArgumentError, 'Invalid Find status' unless %w[complete partial unavailable].include?(status)

        body = +'<h1 class="t1">Find code</h1>'
        body << '<p class="notice ui">Search is incomplete; absence of a match does not prove absence from the capture.</p>' unless status == 'complete'
        body << '<p class="notice ui">Results were truncated. Narrow the search.</p>' if result.fetch('truncated')
        body << '<p class="ui">Literal text; ASCII case-insensitive, other Unicode exact. Source returns the first match per captured file. Kind file selects source hits. Capture coverage is separate from search completeness.</p>'
        coverage = result.fetch('search_coverage', {})
        if coverage.key?('metadata_facts_not_searched')
          body << "<p class=\"ui\">Metadata facts searched: #{h(coverage['metadata_facts_searched'])}; not searched: #{h(coverage['metadata_facts_not_searched'])}. Allowed fields omitted: #{h(coverage['metadata_fields_omitted'])}. Each metadata row is the first matching field in that fact.</p>"
        end
        if (models = coverage['model_capture_families']) && models['inventory'] != 'not_searched'
          body << "<p class=\"notice ui\">Saved model inventory: #{h(models['inventory'])}. Search completeness does not establish complete model capture. No match concerns searched saved names only.</p>"
          %w[columns associations].each do |family|
            counts = models.fetch(family)
            body << "<p class=\"ui\">Captured model #{h(family)} in eligible facts: observed #{h(counts['observed'])}; unavailable #{h(counts['unavailable'])}; unknown #{h(counts['unknown'])}. Observed empty metadata differs from unavailable metadata.</p>"
          end
        end
        if coverage.key?('source_files_not_searched')
          body << "<p class=\"ui\">Captured files searched: #{h(coverage['source_files_searched'])}; not searched: #{h(coverage['source_files_not_searched'])}. Matching source files omitted by result limit: #{h(coverage['source_matching_files_omitted'])}. Each source row is the first occurrence in that file.</p>"
          body << "<p class=\"ui\">Confirmed source matches without a displayed span (work budget): #{h(coverage.fetch('source_matches_without_span', 0))}.</p>"
        end
        body << '<p class="ui">Name matches identify candidates; they do not establish runtime dispatch.</p>'
        rows = result.fetch('results').map { |match| row(match, block_given? ? yield(match) : nil) }.join
        if rows.empty?
          body << '<p class="notice ui">No result rows returned. Check capture and search coverage before concluding code is absent.</p>'
        else
          body << '<table><caption>Search results</caption><thead><tr><th>Match</th><th>Origin</th><th>File</th><th>Snippet</th></tr></thead><tbody>'
          body << rows << '</tbody></table>'
        end
        body
      end

      private

      def row(match, detail)
        origin = match.fetch('origin')
        raise ArgumentError, 'Invalid Find origin' unless %w[source metadata].include?(origin)
        path = match['path']
        name = match['name'] || path || 'Source unavailable'
        params = { 'generation' => @generation }
        params.merge!(@selection.parameters) if @selection && !@selection.ids.empty?
        anchor = ''
        if origin == 'source'
          span = match.fetch('span')
          line = span.fetch('start_line')
          raise ArgumentError, 'Invalid source location' unless path.is_a?(String) && line.is_a?(Integer) && line.positive?
          params['file'] = self.class.file_reference(path)
          anchor = "#L#{line}"
        elsif match['fact_id']
          params['id'] = match['fact_id']
        elsif path
          params['file'] = self.class.file_reference(path)
        end
        title = if params.key?('file') || params.key?('id')
          query = URI.encode_www_form(params.merge(@search))
          # A valid Find query can already occupy the entire request budget.
          # Keep Source usable without emitting an invalid URL or hiding the loss.
          context_omitted = query.bytesize > MAX_QUERY_BYTES
          query = URI.encode_www_form(params) if context_omitted
          raise Investigation::Limit, 'Find destination exceeds the URL budget; no selections were removed.' if query.bytesize > MAX_QUERY_BYTES
          href = "#{@mount}/source?#{query}#{anchor}"
          link = "<a data-result-link href=\"#{h(href)}\">#{h(name)}</a>"
          link += '<small>Search context exceeds the link budget; use Back to return to these results.</small>' if context_omitted
          link
        else
          h(name)
        end
        entry = match.key?('entry_index') ? " · entry #{h(match['entry_index'])}: #{h(match['entry_name'])}" : ''
        "<tr><td>#{title}</td><td>#{h(origin)}#{match['field'] ? " · #{h(match['field'])}" : ''}#{entry}</td><td>#{h(path || 'Source unavailable')}</td><td><code>#{h(match['snippet'] || '')}</code>#{detail ? "<p>#{h(detail)}</p>" : ''}</td></tr>"
      end

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end
    end
  end
end
