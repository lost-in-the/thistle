# frozen_string_literal: true

require 'erb'
require 'uri'

module Thistle
  module Map
    # Renders evidence returned by the bounded Find operation. Routing and the
    # surrounding layout remain the application's responsibility.
    class FindPresenter
      def initialize(generation:, mount: '')
        @generation = generation
        @mount = mount
      end

      def render(result)
        raise ArgumentError, 'Find generation mismatch' unless result.fetch('generation') == @generation

        status = result.fetch('status')
        raise ArgumentError, 'Invalid Find status' unless %w[complete partial unavailable].include?(status)

        body = '<h1 class="t1">Find code</h1>'
        body << '<p class="notice ui">Search is incomplete; absence of a match does not prove absence from the capture.</p>' unless status == 'complete'
        body << '<p class="notice ui">Results were truncated. Narrow the search.</p>' if result.fetch('truncated')
        body << '<p class="ui">Name matches identify candidates; they do not establish runtime dispatch.</p>'
        rows = result.fetch('results').map { |match| row(match) }.join
        if rows.empty?
          body << '<p class="notice ui">No matches returned. Check capture coverage before concluding code is absent.</p>'
        else
          body << '<table><caption>Search results</caption><thead><tr><th>Match</th><th>Origin</th><th>File</th><th>Snippet</th></tr></thead><tbody>'
          body << rows << '</tbody></table>'
        end
        body
      end

      private

      def row(match)
        origin = match.fetch('origin')
        raise ArgumentError, 'Invalid Find origin' unless %w[source metadata].include?(origin)
        path = match['path']
        name = match['name'] || path || 'Source unavailable'
        params = { 'generation' => @generation }
        anchor = ''
        if origin == 'source'
          span = match.fetch('span')
          line = span.fetch('start_line')
          raise ArgumentError, 'Invalid source location' unless path.is_a?(String) && line.is_a?(Integer) && line.positive?
          params['path'] = path
          anchor = "#L#{line}"
        elsif match['fact_id']
          params['id'] = match['fact_id']
        end
        title = if params.key?('path') || params.key?('id')
          href = "#{@mount}/source?#{URI.encode_www_form(params)}#{anchor}"
          "<a data-result-link href=\"#{h(href)}\">#{h(name)}</a>"
        else
          h(name)
        end
        "<tr><td>#{title}</td><td>#{h(origin)}</td><td>#{h(path || 'Source unavailable')}</td><td><code>#{h(match['snippet'] || '')}</code></td></tr>"
      end

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end
    end
  end
end
