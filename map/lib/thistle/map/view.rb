# frozen_string_literal: true

require 'erb'
require 'json'
require 'uri'
require_relative 'highlighter'

module Thistle
  module Map
    # Adapts Woods Map's source-view and fact-tile structure to Thistle's reader.
    # Everything from the capture is escaped before entering markup.
    class View
      class Limit < StandardError; end

      PAGE_SIZE = 50
      MAX_SOURCE_BYTES = 262_144
      MAX_SOURCE_LINES = 10_000
      MAX_CONSTRAINT_ENTRIES = 32
      MAX_CONSTRAINT_FAMILY_BYTES = 8_192
      CONSTRAINT_FIELDS = {
        'string' => %w[key type value encoding].freeze,
        'regexp' => %w[key type value encoding regexp_encoding options].freeze,
        'opaque' => %w[key type].freeze
      }.freeze
      REGEXP_FLAGS = {
        Regexp::IGNORECASE => 'ignore letter case',
        Regexp::EXTENDED => 'ignore pattern spacing and comments',
        Regexp::MULTILINE => 'dot includes newlines',
        Regexp::FIXEDENCODING => 'fixed encoding',
        Regexp::NOENCODING => 'binary matching'
      }.freeze

      def initialize(reader:, mount:, params:)
        @reader = reader
        @mount = mount
        @params = params
        @generation = reader.generation
      end

      def find
        query = @params.fetch('q', '')
        matches = query.strip.empty? ? [] : @reader.find(query, limit: PAGE_SIZE)
        body = '<h1 class="t1">Find code</h1><p class="ui">Use a class, method, route or file name.</p>'
        if query.strip.empty?
          body += '<p class="notice ui">Start with a name you know. Each result shows its source and evidence type.</p>'
        elsif matches.empty?
          body += '<p class="notice ui">No matches in this capture. Check its coverage before concluding the code is absent.</p>'
        else
          body += "<p class=\"ui\">Showing up to #{PAGE_SIZE} matches. Narrow the search if the result you need is missing.</p>"
          show_conditions = matches.any? { |fact| fact['kind'] == 'route' }
          rows = matches.map do |fact|
            conditions = show_conditions ? "<td class=\"route-conditions\">#{h(constraint_summary(fact))}</td>" : ''
            "<tr><td><a data-result-link href=\"#{h(url('/source', 'id' => fact.fetch('id')))}\">#{h(fact.fetch('name'))}</a></td>" \
              "<td>#{h(fact.fetch('kind'))}</td><td>#{h(fact.fetch('evidence'))}</td><td>#{h(fact['path'] || 'Source unavailable')}</td>#{conditions}</tr>"
          end.join
          headings = %w[Name Kind Evidence File]
          headings << 'Route conditions' if show_conditions
          body += table('Search results', headings, rows)
        end
        layout('Find', body)
      end

      def source
        result = @reader.source(@params.fetch('id'))
        fact = result.fetch('fact')
        unless result['generation'] == @generation && fact['id'] == @params['id']
          raise Thistle::InvalidSnapshot, 'Source identity does not match this view'
        end
        content = result.fetch('content')
        raise Limit, 'This source is too large for the web view. Use the Thistle source command for the complete file.' if
          content.bytesize > MAX_SOURCE_BYTES || content.count("\n") > MAX_SOURCE_LINES

        lines = Highlighter.lines(content, language: Highlighter.language_for(fact['path']))
        from = fact.dig('location', 'start_line')
        to = fact.dig('location', 'end_line')
        rows = lines.each_with_index.map do |line, index|
          number = index + 1
          selected = from && to && (from..to).cover?(number)
          "<div class=\"source-row#{' selected' if selected}\" id=\"L#{number}\">" \
            "<a class=\"ln\" href=\"#L#{number}\" aria-label=\"Line #{number}\">#{number}</a><code class=\"src\">#{line}</code></div>"
        end.join
        body = "<h1 class=\"t1\">#{h(fact.fetch('name'))}</h1>" + fact_tiles(fact)
        body += "<p class=\"ui\">Captured file. Highlighted rows mark the selected declaration when a source span is available.</p>" \
          "<p class=\"digest\">Source SHA-256: #{h(result.fetch('sha256'))}</p>" \
          "<div class=\"cvwrap\" role=\"region\" aria-label=\"Source of #{h(fact.fetch('name'))}\" tabindex=\"0\">" \
          "<div class=\"cv codeview\">#{rows}</div></div>"
        layout('Source', body, fact: fact)
      rescue Thistle::Error => error
        raise unless error.code == 'source_unavailable'

        fact = @reader.fact(@params.fetch('id'))
        raise error unless fact['id'] == @params['id'] && fact['path'].nil? && fact['location'].nil?

        body = "<h1 class=\"t1\">#{h(fact.fetch('name'))}</h1>" + fact_tiles(fact)
        body += '<p class="notice ui">No file or line was captured for this fact. Links and Check show the evidence that is available.</p>'
        layout('Source', body, fact: fact)
      end

      def links
        fact = @reader.fact(@params.fetch('id'))
        links = @reader.links(fact.fetch('id'))
        page = @params.fetch('page', '1').to_i
        pages = [(links.length.to_f / PAGE_SIZE).ceil, 1].max
        raise Limit, 'This links page does not exist.' if page > pages

        body = "<h1 class=\"t1\">Links from #{h(fact.fetch('name'))}</h1>" + fact_tiles(fact)
        body += '<p class="notice ui">Unresolved links are names found in the source. They do not prove a runtime call or a resolved target.</p>'
        if links.empty?
          body += '<p class="ui">No links were captured for this fact. This does not prove it has no dependencies.</p>'
        else
          rows = links.slice((page - 1) * PAGE_SIZE, PAGE_SIZE).map do |link|
            detail = call_detail(link, fact)
            "<tr><td>#{h(link.fetch('relation'))}</td><td>#{h(link.fetch('target'))}#{detail}</td><td>#{h(link.fetch('resolution'))}</td></tr>"
          end.join
          body += table('Captured links', %w[Relation Target Evidence], rows)
          body += "<p class=\"pager ui\">Page #{page} of #{pages} · #{links.length} links "
          body += "<a href=\"#{h(url('/links', 'page' => (page - 1).to_s))}\">Previous</a> " if page > 1
          body += "<a href=\"#{h(url('/links', 'page' => (page + 1).to_s))}\">Next</a>" if page < pages
          body += '</p>'
        end
        layout('Links', body, fact: fact)
      end

      def check
        result = @reader.check
        body = '<h1 class="t1">Check this capture</h1><p class="ui">Read coverage and source identity before relying on the result.</p>'
        body += '<p class="notice ui">This view reads a saved generation. It does not establish that the working tree or a running application is unchanged.</p>'
        rows = Array(@reader.manifest['coverage']).map do |coverage|
          "<tr><td>#{h(coverage.fetch('family'))}</td><td>#{h(coverage.fetch('status'))}</td>" \
            "<td>#{h(coverage['scope'])}</td><td>#{h(coverage['reason'] || '')}</td></tr>"
        end.join
        body += table('Capture coverage', %w[Family Status Scope Reason], rows)
        body += "<details><summary>Full check details</summary><pre class=\"check-data\">#{h(JSON.pretty_generate(result))}</pre></details>"
        layout('Check', body)
      end

      private

      # Custom readers are not necessarily native readers. Do not interpolate
      # arbitrary metadata values or create an anchor from malformed bounds.
      def call_detail(link, fact)
        return '' unless link['relation'] == 'calls'
        attrs = link['attributes']
        data = attrs.is_a?(Hash) ? attrs['thistle_call'] : nil
        return '' if data.nil?
        fallback = '<br>Receiver details unavailable'
        return fallback unless data.instance_of?(Hash) && data.keys.all? { |key| key.instance_of?(String) } && data.keys.sort == %w[call_location receiver receiver_location safe_navigation version].sort && data['version'].instance_of?(Integer) && data['version'] == 1 && link['resolution'] == 'unresolved' &&
          [true, false].include?(data['safe_navigation']) && fact['evidence'] == 'static' && fact['path'].is_a?(String)
        receiver = data['receiver']
        return fallback unless receiver.instance_of?(Hash) && receiver.keys.all? { |key| key.instance_of?(String) } && receiver.keys.sort == %w[kind name omitted_limit].sort && [true, false].include?(receiver['omitted_limit'])
        kind, name, omitted = receiver.values_at('kind', 'name', 'omitted_limit')
        named = %w[constant local instance_variable].include?(kind)
        return fallback unless %w[implicit self constant local instance_variable call literal expression].include?(kind)
        return fallback unless named ? (omitted ? name.nil? : name.instance_of?(String) && !name.empty? && name.bytesize <= 256) : (name.nil? && !omitted)
        call_loc = data['call_location']
        bounds = fact['location']
        return fallback unless valid_call_location?(call_loc) && valid_call_location?(bounds) &&
          call_loc['start_byte'] >= bounds['start_byte'] && call_loc['end_byte'] <= bounds['end_byte'] &&
          call_loc['start_line'] >= bounds['start_line'] && call_loc['end_line'] <= bounds['end_line']
        receiver_loc = data['receiver_location']
        return fallback unless kind == 'implicit' ? (receiver_loc.nil? && !data['safe_navigation']) : valid_call_location?(receiver_loc)
        labels = { 'implicit' => 'implicit receiver', 'self' => 'self', 'constant' => 'constant', 'local' => 'local',
          'instance_variable' => 'instance variable', 'call' => 'call result — unknown',
          'literal' => 'literal syntax — value not resolved', 'expression' => 'expression — unknown' }
        label = labels.fetch(kind)
        label += omitted ? ' — name omitted (limit)' : " #{name}" if named
        label += ' · safe navigation' if data['safe_navigation']
        grouped = %w[implicit self].include?(kind) || (named && !omitted)
        anchor = "#{url('/source', 'id' => fact.fetch('id'))}#L#{call_loc['start_line']}"
        "<br>#{h(label)} · <a href=\"#{h(anchor)}\">#{grouped ? 'Representative source' : 'Source'}</a>"
      end

      def valid_call_location?(location)
        return false unless location.instance_of?(Hash) && location.keys.all? { |key| key.instance_of?(String) } && location.keys.sort == %w[start_byte end_byte start_line end_line].sort
        a, b, c, d = location.values_at('start_byte', 'end_byte', 'start_line', 'end_line')
        [a, b, c, d].all? { |n| n.instance_of?(Integer) && n >= 0 && n <= 4_194_304 } && a <= b && c > 0 && c <= d
      end

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end

      def url(path, extra = {})
        params = @params.reject { |key, _| key == 'page' }.merge('generation' => @generation).merge(extra)
        params.delete('id') if path == '/'
        "#{@mount}#{path}?#{URI.encode_www_form(params)}"
      end

      def layout(title, body, fact: nil)
        selected = fact || (@params['id'] && @reader.fact(@params['id']))
        source_link = selected ? nav_link('Source', '/source', title, 's', selected['id']) : '<span class="disabled">Source <small>Choose a result</small></span>'
        links_link = selected ? nav_link('Links', '/links', title, 'g', selected['id']) : '<span class="disabled">Links <small>Choose a result</small></span>'
        <<~HTML
          <!doctype html>
          <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{h(title)} · Thistle Map</title>
          <link rel="stylesheet" href="#{h(@mount)}/assets/woods-map-tokens.css">
          <link rel="stylesheet" href="#{h(@mount)}/assets/map.css">
          <script src="#{h(@mount)}/assets/map.js" defer></script></head>
          <body><a class="skip" href="#main">Skip to evidence</a><div class="wm thistle-workbench" id="workbench" tabindex="-1">
          <header class="app-header"><a class="brand" href="#{h(url('/'))}">Thistle <span>Map</span></a>
          <form method="get" action="#{h(@mount)}/" class="find-form"><label for="find-query">Find code</label>
          <input type="search" name="q" id="find-query" value="#{h(@params.fetch('q', ''))}" maxlength="256" placeholder="Class, method, route or file" autocomplete="off">
          <input type="hidden" name="generation" value="#{h(@generation)}"><button class="btn primary" type="submit">Find</button></form></header>
          <nav aria-label="Evidence views">#{nav_link('Find', '/', title, 'f')}#{source_link}#{links_link}#{nav_link('Check', '/check', title, nil)}</nav>
          <main id="main" tabindex="-1"><p class="capture ui">Saved capture <code>#{h(@generation[0, 12])}</code> · live freshness not checked</p>
          #{body}</main>
          <footer><label class="shortcut-setting ui" hidden><input id="letter-shortcuts" type="checkbox"> Use letter shortcuts</label>
          <p class="ui" id="shortcut-help">Optional: F Find, S Source, G Links, J/K results. Keys act only within this workbench and never while entering text.</p>
          <noscript><p class="ui">Letter shortcuts require JavaScript. All evidence views work through the visible links and form.</p></noscript>
          <p class="ui">Private implementation preview · incomplete product coverage</p></footer></div></body></html>
        HTML
      end

      def nav_link(label, path, active, key, id = nil)
        attrs = label == active ? ' aria-current="page"' : ''
        attrs += " data-shortcut=\"#{key}\"" if key
        "<a href=\"#{h(url(path, id ? { 'id' => id } : {}))}\"#{attrs}>#{label}</a>"
      end

      def fact_tiles(fact)
        tiles = [
          ['Identity', [['Kind', fact['kind']], ['Evidence', fact['evidence']]]],
          ['Source', [['File', fact['path'] || 'Unavailable'], ['Line', fact.dig('location', 'start_line') || 'Unavailable']]]
        ]
        if fact['kind'] == 'route'
          tiles << ['Route conditions', [['Observed conditions', constraint_summary(fact)],
            ['Meaning', 'Route presence does not prove a request will match.']]]
        end
        '<div class="facts">' + tiles.map do |eyebrow, rows|
          klass = eyebrow == 'Route conditions' ? ' class="route-conditions"' : ''
          "<div#{klass}><span class=\"eyebrow\">#{h(eyebrow)}</span><dl>" +
            rows.map { |label, value| "<dt>#{h(label)}</dt><dd>#{h(value)}</dd>" }.join + '</dl></div>'
        end.join + '</div>'
      end

      def constraint_summary(fact)
        return 'Not applicable' unless fact['kind'] == 'route'
        data = fact.dig('attributes', 'route_constraints')
        return 'Unknown; conditions were not captured' if data.nil?
        return 'Unknown; conditions are invalid or exceed the display budget' unless constraint_metadata_valid?(data)

        parts = []
        [['request', 'Request'], ['segments', 'Path segment']].each do |key, label|
          entries = data[key]
          entries.each do |entry|
            value = case entry['type']
            when 'string' then "string #{quoted_constraint(entry['value'])} (encoding #{entry['encoding']})"
            when 'regexp' then "pattern #{quoted_constraint(entry['value'])} (#{regexp_flags(entry['options'])}; options #{entry['options']}, source encoding #{entry['encoding']}, pattern encoding #{entry['regexp_encoding']})"
            else 'opaque value'
            end
            parts << "#{label}: #{entry['key']} = #{value}"
          end
        end
        parts << 'Other constraint present; details unavailable' if data['opaque'] == 'present'
        parts << 'Other constraints unknown' unless ['present', 'none observed'].include?(data['opaque'])
        parts << 'Some conditions unknown' unless data['status'] == 'observed'
        parts.empty? ? 'No conditions observed' : parts.join('; ')
      end

      def plain?(value, klass)
        Object.instance_method(:instance_of?).bind_call(value, klass)
      end

      def constraint_string_valid?(value)
        plain?(value, String) && value.bytesize <= MAX_CONSTRAINT_FAMILY_BYTES &&
          value.valid_encoding? && [Encoding::UTF_8, Encoding::US_ASCII].include?(value.encoding)
      end

      def constraint_encoding_valid?(value)
        constraint_string_valid?(value) && Encoding.find(value)&.name == value
      rescue ArgumentError
        false
      end

      def constraint_metadata_valid?(data)
        return false unless plain?(data, Hash) && data.size == 4
        return false unless data.keys.all? { |key| plain?(key, String) && %w[status request segments opaque].include?(key) }
        return false unless plain?(data['status'], String) && %w[observed unknown].include?(data['status'])
        return false unless plain?(data['opaque'], String) && ['present', 'none observed', 'unknown'].include?(data['opaque'])

        constraint_entries_valid?(data['request']) && constraint_entries_valid?(data['segments'])
      end

      def constraint_entries_valid?(entries)
        return false unless plain?(entries, Array) && entries.length <= MAX_CONSTRAINT_ENTRIES

        bytes = 2
        entries.each_with_index do |entry, index|
          return false unless plain?(entry, Hash) && entry.size <= 6 && constraint_string_valid?(entry['type'])
          fields = CONSTRAINT_FIELDS[entry['type']]
          return false unless fields && entry.size == fields.length && entry.keys.all? { |key| plain?(key, String) && fields.include?(key) }
          return false unless constraint_string_valid?(entry['key'])
          unless entry['type'] == 'opaque'
            return false unless constraint_string_valid?(entry['value']) && constraint_encoding_valid?(entry['encoding'])
          end
          if entry['type'] == 'regexp'
            return false unless constraint_encoding_valid?(entry['regexp_encoding'])
            options = entry['options']
            return false unless plain?(options, Integer) && options.between?(0, 0xffff_ffff)
          end
          bytes += JSON.generate(entry).bytesize + (index.zero? ? 0 : 1)
          return false if bytes > MAX_CONSTRAINT_FAMILY_BYTES
        end
        true
      rescue EncodingError, JSON::GeneratorError
        false
      end

      def quoted_constraint(value)
        return 'unknown value' unless value.is_a?(String)

        # JSON escapes C0 controls; make DEL, C1 and line separators visible too.
        JSON.generate(value).gsub(/[\u007f-\u009f\u2028\u2029]/) { |character| format('\\u%04x', character.ord) }
      end

      def regexp_flags(options)
        return 'unknown flags' unless options.is_a?(Integer) && options >= 0

        flags = REGEXP_FLAGS.filter_map { |bit, label| label unless (options & bit).zero? }
        flags << 'unknown option bits' unless (options & ~REGEXP_FLAGS.keys.reduce(0, :|)).zero?
        flags.empty? ? 'no flags' : flags.join(', ')
      end

      def table(label, headings, rows)
        "<div class=\"table-wrap\" role=\"region\" aria-label=\"#{h(label)}\" tabindex=\"0\"><table class=\"tbl\"><thead><tr>" +
          headings.map { |heading| "<th scope=\"col\">#{h(heading)}</th>" }.join +
          "</tr></thead><tbody>#{rows}</tbody></table></div>"
      end
    end
  end
end
