# frozen_string_literal: true

require 'erb'
require 'digest'

module Thistle
  module Map
    # Presentation of the Rust Reader projection only. The injected callable is
    # the shared NavigationContext authority, never a new URL encoder/resolver.
    class SourceComprehensionPresenter
      class InvalidProjection < StandardError; end
      MAX_SOURCE_BYTES = 65_536
      MAX_LINES = 2000
      MAX_BODY_BYTES = 786_432
      LABELS = {
        'as_written_declaration' => 'As written',
        'unknown_incomplete_candidates' => 'Precedence unknown: more candidates remain',
        'ambiguous_definitions' => 'Ambiguous: multiple saved definitions',
        'unknown_duplicate_owner_labels' => 'Precedence unknown: duplicate owner labels',
        'observed_loaded_owner_source_binding_unknown' => 'Observed loaded owner; saved-source binding unknown',
        'alternative_to_observed_loaded_owner' => 'Alternative saved definition; another loaded owner observed',
        'unknown_precedence' => 'Precedence unknown'
      }.freeze

      # navigation.url(path, extras) is the shared context authority. Comprehension
      # continuations require an explicitly supplied Root route adapter.
      # sources are independently admitted Reader.source responses; nil means no
      # source was admitted, never an empty source file. No Reader calls here.
      def initialize(projection:, sources:, navigation:, highlighter:, continuation_url: nil)
        @data, @sources, @navigation, @highlighter = projection, sources, navigation, highlighter
        @continuation_url = continuation_url
      end

      def render
        validate
        @body = +''
        append '<section aria-label="Model source comprehension">'
        append "<h2 class=\"t2\">Read #{h(@data.fetch('owner'))}</h2>"
        append '<p class="notice ui">Identified contributions. Loaded ownership and saved definitions are separate evidence; source/runtime coherence is unknown.</p>'
        append '<p class="ui">Each code block retains its captured path and physical lines. These blocks are not a concatenated effective runtime class.</p>'
        outline
        rendered = {}
        @data.fetch('contributions').each do |contribution|
          fact = contribution.fetch('fact')
          source = @sources[fact.fetch('id')]
          next if source && rendered[source.fetch('fact').fetch('path')]
          if source
            code(source, contribution)
            rendered[fact.fetch('path')] = true
          else
            append "<p class=\"notice ui\">#{h(fact.fetch('name'))}: source unavailable or not admitted on this page. "
            append link('Open exact Source', contribution.fetch('source')) + '</p>'
          end
        end
        append '<p>No saved definitions returned on this page. This does not prove behavior is absent.</p>' if @data.fetch('contributions').empty?
        @data.fetch('observed_only').each do |method|
          append "<p class=\"notice ui\">#{h(method.fetch('name'))}: observed method; no saved definition candidate. Source unavailable; source/runtime coherence unknown.</p>"
        end
        context
        append '</section>'
        @body
      end

      private

      def validate
        raise InvalidProjection, 'Unknown source comprehension format' unless @data['version'] == 1 && @data['composition'] == 'identified_contributions'
        rows = @data.fetch('contributions')
        raise InvalidProjection, 'Contribution page exceeds allowance' unless rows.is_a?(Array) && rows.length <= 16
        raise InvalidProjection, 'Missing generation' unless @data['generation'].is_a?(String) && @data['generation'].match?(/\A[0-9a-f]{64}\z/)
        bytes = 0
        rows.each do |row|
          raise InvalidProjection, 'Unknown contribution status' unless LABELS.key?(row.fetch('status'))
          %w[source callers].each { |key| validate_selector(row.fetch(key)) }
          fact = row.fetch('fact')
          source = @sources[fact.fetch('id')]
          next unless source
          physical = source.fetch('fact')
          unless source['generation'] == @data['generation'] && %w[id path location].all? { |key| physical[key] == fact[key] }
            raise InvalidProjection, 'Source identity disagrees with contribution'
          end
          content = source.fetch('content')
          raise InvalidProjection, 'Source digest disagrees' unless Digest::SHA256.hexdigest(content) == source.fetch('sha256')
          # Charging duplicate responses conservatively also bounds repeated work.
          bytes += content.bytesize
          raise InvalidProjection, 'Source reading allowance exceeded' if bytes > MAX_SOURCE_BYTES || content.count("\n") > MAX_LINES
        end
      end

      def validate_selector(selector)
        raise InvalidProjection, 'Cross-generation follow-up' unless selector.fetch('generation') == @data['generation']
      end

      def outline
        append '<details open><summary>Owner and method outline</summary><ul class="ui">'
        @data.fetch('contributions').each do |row|
          fact = row.fetch('fact')
          append '<li>' + link(fact.fetch('name'), row.fetch('source'), line: fact.dig('location', 'start_line')) + " — #{h(LABELS.fetch(row.fetch('status')))}"
          append " <span>Observed owner: #{h(row['observed_owner'] || 'Unknown')}</span> "
          append link('Incoming references / callers', row.fetch('callers')) + '</li>'
        end
        append '</ul></details>'
      end

      def code(source, contribution)
        fact = source.fetch('fact')
        append "<h3 class=\"t3\">#{h(fact.fetch('path'))}</h3>"
        append "<p class=\"ui\">Captured file · #{link('Exact Source', contribution.fetch('source'))}</p>"
        append "<div class=\"cvwrap\" role=\"region\" tabindex=\"0\" aria-label=\"Captured source #{h(fact.fetch('path'))}\"><div class=\"cv codeview\">"
        from, to = fact.fetch('location').values_at('start_line', 'end_line')
        @highlighter.call(source.fetch('content'), language: 'ruby').each_with_index do |line, index|
          number = index + 1
          # Line anchors stay scoped to a fact, avoiding collisions across files.
          anchor = "source-#{fact.fetch('id')}-L#{number}"
          selected = from && to && number.between?(from, to)
          append "<div class=\"source-row#{selected ? ' selected' : ''}\" id=\"#{h(anchor)}\"><a class=\"ln\" href=\"##{h(anchor)}\" aria-label=\"Line #{number}\">#{number}</a><code class=\"src\">#{line}</code></div>"
        end
        append '</div></div>'
        append "<p class=\"digest\">Captured source SHA-256: #{h(source.fetch('sha256'))}</p>"
      end

      def context
        append '<details><summary>Ownership, provenance and coverage</summary>'
        append "<p class=\"ui\">#{h(@data.fetch('semantics'))}</p>"
        append "<p>Ownership evidence: #{h(@data.fetch('ownership_status'))}. Saved generation: #{h(@data.fetch('generation'))}.</p>"
        owners = @data['owners'] || []
        append '<ol>'
        owners.each do |owner|
          append "<li>#{h(owner['name'] || 'Anonymous owner')} (#{h(owner.fetch('kind'))})</li>"
        end
        append '</ol>'
        coverage = @data.fetch('coverage')
        append "<p>#{h(coverage.fetch('returned'))} saved candidates shown; #{h(coverage.fetch('candidate_matches_seen'))} matches witnessed. Range complete: #{h(coverage.fetch('range_complete'))}. #{h(coverage.fetch('scope'))}.</p>"
        append '</details>'
        if @data['continuation'] && @continuation_url
          validate_selector(@data['continuation'])
          href = @continuation_url.call(@data['continuation'])
          append "<p class=\"ui\"><a href=\"#{h(href)}\">More saved contributions</a></p>"
        elsif @data['continuation']
          append '<p class="notice ui">More saved contributions remain. This view has no admitted continuation route.</p>'
        end
        # Existing model_brief / callback / reference presenters are composed by
        # View after the code surface. Their facts are never re-derived here.
      end

      def link(label, selector, line: nil)
        operation = selector.fetch('operation')
        href = case operation
        when 'source' then @navigation.url('/source', { 'id' => selector.fetch('id') })
        when 'references' then @navigation.url('/links', { 'id' => selector.fetch('id'), 'direction' => selector.fetch('direction') })
        else raise InvalidProjection, 'Unknown witness route'
        end
        if line
          raise InvalidProjection, 'Invalid physical source line' unless line.is_a?(Integer) && line.positive?
          href += "#L#{line}"
        end
        "<a href=\"#{h(href)}\">#{h(label)}</a>"
      end

      def append(fragment)
        raise InvalidProjection, 'Source comprehension display allowance exceeded' if @body.bytesize + fragment.bytesize > MAX_BODY_BYTES
        @body << fragment
      end

      def h(value) = ERB::Util.html_escape(value.to_s)
    end
  end
end
