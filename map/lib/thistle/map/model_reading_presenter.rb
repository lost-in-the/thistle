# frozen_string_literal: true

require_relative 'source_comprehension_presenter'

module Thistle
  module Map
    # Organizes typed Core evidence. No Reader, parser, resolver or cache here.
    class ModelReadingPresenter
      def initialize(reading:, navigation:, highlighter:)
        @reading, @navigation, @highlighter = reading, navigation, highlighter
      end

      def render
        data = @reading.projection
        id = data.fetch('model').fetch('id')
        body = +"<section class=\"model-reading\" aria-label=\"Model reading\"><h1 class=\"t1\">#{h(data.fetch('owner'))}</h1>"
        body << '<p class="ui">Saved declarations and observed owners; source binding, conditions and execution remain unknown.</p>'
        body << '<nav aria-label="Evidence for this model">'
        { '/source' => 'Read source', '/model-neighborhood/columns/outgoing/all' => 'Columns',
          '/model-neighborhood/edges/outgoing/association' => 'Associations',
          '/brief/registry_candidates' => 'Registered callbacks' }.each do |path, label|
          body << link(label, path, { 'id' => id })
        end
        body << '</nav>'
        body << position_notice
        body << '<div class="reading-layout"><div class="reading-source">'
        body << SourceComprehensionPresenter.new(projection: data, sources: @reading.admission.sources,
          source_states: @reading.admission.states, navigation: @navigation, highlighter: @highlighter,
          reading: true, continuation_url: method(:continuation)).render
        body << '</div><aside class="reading-outline" aria-label="Contribution and method outline"><h2>Contributions and methods</h2>'
        body << '<p>Each named candidate opens its own physical Source. Multiple candidates remain alternatives.</p><ul>'
        outline(body, data)
        body << '</ul>'
        if @reading.methods && !@reading.methods.equal?(data)
          body << '<h3>Method owners</h3><ul>'
          outline(body, @reading.methods)
          body << '</ul>'
          body << next_link(@reading.methods)
          evidence = @reading.methods.slice('generation', 'ownership_status', 'ownership_evidence_ids', 'owners', 'coverage')
          evidence['facts'] = @reading.methods.fetch('contributions').map { |row| row.fetch('fact') }
          body << "<details><summary>Method outline provenance and coverage</summary><pre class=\"check-data\">#{h(JSON.generate(evidence))}</pre></details>"
        end
        body << link('Browse saved methods', '/comprehension/methods', { 'id' => id, 'cursor' => nil })
        body << '</aside></div></section>'
        raise SourceComprehensionPresenter::InvalidProjection, 'Model reading display budget exceeded' if body.bytesize > SourceComprehensionPresenter::MAX_BODY_BYTES
        body
      end

      private

      def outline(body, data)
        data.fetch('contributions').each do |row|
          fact = row.fetch('fact')
          body << '<li>' + link(fact.fetch('name'), '/source', { 'id' => fact.fetch('id') }, line: fact.dig('location', 'start_line'), path: fact['path'])
          body << "<br>#{h(fact['path'] || 'Physical source unavailable')} · contributed by #{h(row['owner'] || 'Unknown owner')}"
          body << "<br>#{h(SourceComprehensionPresenter::LABELS.fetch(row.fetch('status')))}"
          body << " · observed owner: #{h(row['observed_owner'])}" if row['observed_owner']
          body << '<br>' + link('Recorded callers / incoming references', '/references/incoming', { 'id' => fact.fetch('id') })
          body << '</li>'
        end
        data.fetch('rows', []).each do |row|
          next unless row.fetch('returned', 0).zero?
          body << "<li>#{h(row['method_name'] || row['owner'] || 'Anonymous owner')} · #{h(SourceComprehensionPresenter::ROW_LABELS.fetch(row.fetch('status')))}</li>"
        end
        body << '<li>No saved candidate on this page; absence is unknown.</li>' if data.fetch('contributions').empty? && data.fetch('rows', []).empty?
      end

      def next_link(data)
        return '' unless data['continuation']
        "<p><a href=\"#{h(continuation(data.fetch('continuation')))}\">More saved methods</a></p>"
      end

      def position_notice
        position = @navigation.source_position
        return '' unless position
        file, line = position
        present = @reading.admission.sources.values.any? do |source|
          content = source.fetch('content')
          Digest::SHA256.hexdigest(source.dig('fact', 'path')) == file &&
            line <= content.count("\n") + (content.end_with?("\n") ? 0 : 1)
        end
        return '' if present
        target = @navigation.url('/source', 'file' => file, 'id' => nil) + "#L#{line}"
        "<p class=\"notice ui\" id=\"reading-file-#{file}-L#{line}\">Requested physical position is not displayed on this bounded reading page. " \
          "<a href=\"#{h(target)}\">Open the exact captured file at line #{line}</a>. No other source was substituted.</p>"
      end

      def continuation(selector)
        @navigation.url("/comprehension/#{selector.fetch('family')}", 'id' => selector.fetch('id'), 'cursor' => selector.fetch('cursor'))
      end

      def link(label, route, controls, line: nil, path: nil)
        position = path && line && line <= 10_000 ? [Digest::SHA256.hexdigest(path), line] : nil
        href = position ? @navigation.url(route, controls, source_position: position) : @navigation.url(route, controls)
        if line
          raise SourceComprehensionPresenter::InvalidProjection, 'Invalid physical line' unless line.is_a?(Integer) && line.positive?
          href += "#L#{line}"
        end
        "<a href=\"#{h(href)}\">#{h(label)}</a>"
      end

      def h(value) = ERB::Util.html_escape(value.to_s)
    end
  end
end
