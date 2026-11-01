# frozen_string_literal: true

require 'erb'
require 'json'
require 'digest'
require 'uri'
require_relative 'highlighter'
require_relative 'model_presenter'
require_relative 'callback_presenter'
require_relative 'find_presenter'
require_relative 'references_presenter'
require_relative 'constant_occurrence'
require_relative 'investigation_presenter'
require_relative 'investigation_evidence'
require_relative 'source_comprehension_sources'
require_relative 'job_mail_presenter'
require_relative 'route_actions_presenter'
require_relative 'passage_presenter'
require_relative 'model_neighborhood_presenter'
require_relative 'model_reading'
require_relative 'model_reading_presenter'

module Thistle
  module Map
    # Adapts Woods Map's source-view and fact-tile structure to Thistle's reader.
    # Everything from the capture is escaped before entering markup.
    class View
      class Limit < StandardError; end

      PAGE_SIZE = 50
      MAX_SOURCE_BYTES = ConstantOccurrence::WEB_SOURCE_BYTES
      MAX_SOURCE_LINES = ConstantOccurrence::WEB_SOURCE_LINES
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

      def initialize(reader:, mount:, params:, selection: nil, path: '/', model_id: nil, source_position: nil, reading_family: 'contributions', reading_cursor: nil)
        @reader = reader
        @mount = mount
        @params = params
        @generation = reader.generation
        @selection = selection || Investigation.from_params(params.merge('generation' => @generation))
        raise Thistle::InvalidSnapshot, 'Investigation generation mismatch' unless @selection.generation == @generation
        @current_path = path
        @model_id = model_id
        @navigation = NavigationContext.new(generation: @generation, mount: mount, params: params, selection: @selection, model_id: model_id,
          source_position: source_position, reading_family: reading_family, reading_cursor: reading_cursor)
      end

      def find
        query = @params.fetch('q', '')
        if !query.strip.empty? && @reader.respond_to?(:search_evidence)
          result = @reader.search_evidence(query, limit: PAGE_SIZE, kind: @params['kind'].to_s.empty? ? nil : @params['kind'], path: @params['prefix'].to_s.empty? ? nil : @params['prefix'], domain: @params['domain'])
          body = FindPresenter.new(generation: @generation, mount: @mount, search: @params, selection: @selection, navigation: @navigation).render(result) do |match|
            constraint_summary(@reader.fact(match.fetch('fact_id'))) if match['origin'] == 'metadata' && match['kind'] == 'route'
          end
          return layout('Find', body)
        end
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
        return model_reading_page if @model_id && @params['id'] == @model_id
        ownership_available = @reader.manifest.fetch('coverage', []).any? { |family| family['family'] == 'source_ownership' }
        if !@model_id && ownership_available && @reader.respond_to?(:source_comprehension) && @reader.respond_to?(:fact_identity)
          compact = @reader.fact_identity(@params.fetch('id'))
          unless compact['generation'] == @generation && compact.dig('fact', 'id') == @params['id'] && JSON.generate(compact).bytesize <= 32768
            raise Thistle::InvalidSnapshot, 'Source compact identity mismatch'
          end
          if compact.dig('fact', 'kind') == 'rails_model'
            @model_id = @params.fetch('id')
            @navigation = NavigationContext.new(generation: @generation, mount: @mount, params: @params, selection: @selection, model_id: @model_id)
            return model_reading_page
          end
        end
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
        comprehension = fact['kind'] == 'class' && @reader.respond_to?(:source_comprehension)
        body = "<h1 class=\"t1\">#{h(fact.fetch('name'))}</h1>"
        body << "<p class=\"ui\">#{h(fact['path'])}:#{h(from)} · physical captured source</p>" if @model_id
        body += comprehension_navigation(fact.fetch('id')) if comprehension && !@model_id
        body += fact_tiles(fact) unless comprehension || @model_id
        body += "<p class=\"ui\">Captured file. Highlighted rows mark the selected declaration when a source span is available.</p>" \
          "<p class=\"digest\">Source SHA-256: #{h(result.fetch('sha256'))}</p>" \
          "<div class=\"cvwrap\" role=\"region\" aria-label=\"Source of #{h(fact.fetch('name'))}\" tabindex=\"0\">" \
          "<div class=\"cv codeview\">#{rows}</div></div>"
        body += fact_tiles(fact) if comprehension && !@model_id
        @return_source = [fact['path'], fact.dig('location', 'start_line')] if @model_id
        layout('Source', body, fact: fact)
      rescue Thistle::Error => error
        raise unless error.code == 'source_unavailable'

        if @model_id
          raise Limit, 'Source recovery requires the compact identity Reader API.' unless @reader.respond_to?(:fact_identity)
          compact = @reader.fact_identity(@params.fetch('id'))
          unless compact['generation'] == @generation && compact.dig('fact', 'id') == @params['id']
            raise Thistle::InvalidSnapshot, 'Source recovery identity mismatch'
          end
          raise Limit, 'Source recovery identity exceeds its 32 KiB display budget.' if JSON.generate(compact).bytesize > 32768
          fact = compact.fetch('fact')
          if fact['kind'] == 'rails_model'
            body = "<h1>#{h(fact.fetch('name'))}</h1><p>No physical Source was captured for this identity; runtime binding remains unknown.</p>"
            own = NavigationContext.new(generation: @generation, mount: @mount, params: @params, selection: @selection, model_id: fact.fetch('id'))
            body << "<p><a href=\"#{h(own.url('/source', 'id' => fact.fetch('id')))}\">Read #{h(fact.fetch('name'))} in its own model context</a></p>"
            return layout('Source', body, fact: fact)
          end
        end

        if @reader.manifest.fetch('coverage', []).any? { |row| row['family'] == 'rails_job_mail' }
          raise Limit, 'Saved job/mail Source navigation requires the compact identity Reader API.' unless @reader.respond_to?(:fact_identity)
          compact ||= @reader.fact_identity(@params.fetch('id'))
          unless compact['generation'] == @generation && compact.dig('fact', 'id') == @params['id'] && JSON.generate(compact).bytesize <= 32768
            raise Thistle::InvalidSnapshot, 'Job/mail compact identity mismatch'
          end
          if compact.dig('fact', 'kind') == 'rails_job_mail'
            fact = compact.fetch('fact')
            body = "<h1 class=\"t1\">#{h(fact.fetch('name'))}</h1>" + job_mail_navigation(fact)
            body << '<p class="notice ui">Saved job/mail investigation is unavailable with this Reader.</p>' unless @reader.respond_to?(:job_mail)
            body << '<p class="notice ui">Saved registry identity only; no file or line was captured. Inspect registrations and source candidates explicitly. No job or mail delivery was observed.</p>'
            return layout('Source', body, fact: fact)
          end
        end
        fact = @reader.fact(@params.fetch('id'))
        raise error unless fact['id'] == @params['id'] && fact['path'].nil? && fact['location'].nil?

        body = "<h1 class=\"t1\">#{h(fact.fetch('name'))}</h1>" + fact_tiles(fact)
        body += '<p class="notice ui">No file or line was captured for this fact. Links and Check show the evidence that is available.</p>'
        layout('Source', body, fact: fact)
      end

      def source_comprehension_page(family)
        return model_reading_page(family) if @model_id && @params['id'] == @model_id
        unless NavigationContext::COMPREHENSION_FAMILIES.include?(family) && @reader.respond_to?(:source_comprehension)
          raise Limit, 'Saved source comprehension is unavailable with this Reader.'
        end
        id = @params.fetch('id')
        result = @reader.source_comprehension(id, family: family, cursor: @params['cursor'], limit: 8, max_bytes: 32768)
        root = result.fetch('model')
        unless result['version'] == 1 && result['generation'] == @generation && result['family'] == family &&
            result['composition'] == 'identified_contributions' && result['source_runtime_coherence'] == 'unknown' &&
            root['id'] == id && %w[class rails_model].include?(root['kind']) && result.fetch('contributions').length <= 8
          raise Thistle::InvalidSnapshot, 'Source comprehension envelope mismatch'
        end
        raise Limit, 'Source comprehension response exceeds its byte budget.' if JSON.generate(result).bytesize > 32768
        result.fetch('contributions').each do |row|
          fact = row.fetch('fact')
          unless Investigation::DIGEST.match?(fact.fetch('id')) && %w[source callers].all? { |name| row.fetch(name)['generation'] == @generation && row.fetch(name)['id'] == fact['id'] }
            raise Thistle::InvalidSnapshot, 'Source comprehension witness identity mismatch'
          end
          unless row.dig('source', 'operation') == 'source' && row.dig('callers', 'operation') == 'references' && row.dig('callers', 'direction') == 'incoming'
            raise Thistle::InvalidSnapshot, 'Source comprehension witness operation mismatch'
          end
        end
        continuation_url = lambda do |selector|
          unless selector['operation'] == 'source_comprehension' && selector['generation'] == @generation && selector['id'] == id && selector['family'] == family
            raise Thistle::InvalidSnapshot, 'Source comprehension continuation identity mismatch'
          end
          cursor = selector.fetch('cursor')
          NavigationContext.validate_cursor!(cursor, generation: @generation, scope: ['source_comprehension', id, family])
          raise Thistle::InvalidSnapshot, 'Source comprehension continuation made no progress' if cursor == @params['cursor']
          url("/comprehension/#{family}", 'id' => id, 'cursor' => cursor)
        end
        # Validate continuation before Source I/O, then reuse the same authority
        # adapter in presentation. No Ruby position arithmetic or fallback route.
        continuation_url.call(result['continuation']) if result['continuation']
        admission = SourceComprehensionSources.new(reader: @reader, generation: @generation).call(result.fetch('contributions'))
        body = "<h1 class=\"t1\">#{h(root.fetch('name'))}</h1>" + comprehension_navigation(id)
        body << model_neighborhood_navigation(root) if root['kind'] == 'rails_model'
        body << SourceComprehensionPresenter.new(projection: result, sources: admission.sources, source_states: admission.states,
          navigation: @navigation, highlighter: Highlighter.method(:lines), continuation_url: continuation_url).render
        # Supporting families remain explicit progressive actions. Do not query
        # every model/callback/reference family merely to open a reading page.
        body << '<details><summary>Recorded declarations and reference context</summary><p>Registration, saved source, binding and execution are separate evidence.</p>'
        if root['kind'] == 'rails_model'
          { 'columns' => 'Recorded columns', 'associations' => 'Recorded associations', 'registry_candidates' => 'Registered callback candidates' }.each do |name, label|
            body << "<p><a href=\"#{h(url("/brief/#{name}", 'id' => id, 'cursor' => nil))}\">#{h(label)}</a></p>"
          end
        end
        body << "<p><a href=\"#{h(url('/links', 'id' => id, 'direction' => 'incoming'))}\">Incoming references / callers</a> · "
        body << "<a href=\"#{h(url('/links', 'id' => id, 'direction' => 'outgoing'))}\">Links and recorded callback/schema context</a></p>"
        result.fetch('contributions').each { |row| body << job_mail_navigation(row.fetch('fact')) }
        body << '</details>'
        content = layout('Source', body, fact: root)
        raise Limit, 'Source comprehension page exceeds its output budget.' if content.bytesize > SourceComprehensionPresenter::MAX_BODY_BYTES + 65536
        content
      rescue SourceComprehensionPresenter::DisplayLimit, ModelReading::DisplayLimit => error
        raise Limit, "#{error.message} Open exact Source or narrow the evidence page; no source was substituted."
      rescue SourceComprehensionPresenter::InvalidProjection => error
        raise Thistle::InvalidSnapshot, error.message
      end

      def model_reading_page(family = nil)
        raise Limit, 'Saved model reading is unavailable with this Reader.' unless @reader.respond_to?(:source_comprehension)
        cursor = family ? @params['cursor'] : @navigation.reading_cursor
        family ||= @navigation.reading_family
        reading = ModelReading.new(reader: @reader, id: @model_id, generation: @generation, family: family, cursor: cursor)
        @reading_title = reading.projection.dig('model', 'name')
        body = ModelReadingPresenter.new(reading: reading, navigation: @navigation, highlighter: Highlighter.method(:lines)).render
        content = layout('Source', body, fact: reading.projection.fetch('model'))
        raise Limit, 'Model reading exceeds its total display budget.' if content.bytesize > SourceComprehensionPresenter::MAX_BODY_BYTES + 65536
        content
      rescue SourceComprehensionPresenter::DisplayLimit, ModelReading::DisplayLimit => error
        raise Limit, "#{error.message} Open exact Source or narrow the evidence page; no source was substituted."
      rescue SourceComprehensionPresenter::InvalidProjection => error
        raise Thistle::InvalidSnapshot, error.message
      end

      # One explicit registry, selected by the user from Core's candidates. The
      # existing callback_effects projection contains registered metadata as well
      # as qualified source evidence. No Ruby callback/name resolution occurs.
      def model_callbacks_page(limit: 8)
        raise Limit, 'Registered callback evidence is unavailable with this Reader.' unless @reader.respond_to?(:callback_effects)
        id = @params.fetch('id')
        answer = @reader.callback_effects(id, limit: limit)
        unless answer['version'] == 1 && answer['generation'] == @generation && answer['registry_id'] == id &&
            answer['coherence'] == 'unknown' && answer['execution'] == 'unknown' && answer['callbacks'].is_a?(Array)
          raise Thistle::InvalidSnapshot, 'Registered callback projection mismatch'
        end
        bytes = limit == 8 ? 32768 : CallbackPresenter::MAX_BYTES
        if answer.fetch('callbacks').length > limit || JSON.generate(answer).bytesize > bytes
          raise Limit, 'Registered callbacks exceed this page response budget. Return to the registry choices for Full registered callbacks (up to 200), or use the Reader interface.'
        end
        answer.fetch('callbacks').each do |row|
          raise Thistle::InvalidSnapshot, 'Callback registry witness mismatch' unless row['registry_id'] == id && row['registry_provenance'] == 'registered_metadata'
        end
        body = +"<h1>#{h(answer['model'] || 'Anonymous model')}: registered save callbacks</h1>"
        body << '<p>Registered chain positions are not execution chronology. Conditions, execution and source binding remain unknown.</p>'
        body << "<p>Showing at most #{limit} registered entries; this is a bounded view, not an unlimited chain.</p>"
        if limit == 8
          body << "<p><a href=\"#{h(url('/model-callbacks/full', 'id' => id))}\">Full registered callbacks (up to 200)</a></p>"
        end
        # The reusable presenter reads only this typed answer. No Reader/source
        # adapter is supplied, so condition hints cannot fan out into source I/O.
        body << CallbackPresenter.new(generation: @generation, navigation: @navigation).render_projection(answer, registered: true)
        body << "<details><summary>Registry identity, coverage and limits</summary><pre class=\"check-data\">#{h(JSON.pretty_generate(answer.reject { |key, _| key == 'callbacks' }))}</pre></details>"
        bounded_evidence_page('Registered callbacks', body, fact: nil)
      rescue Thistle::LimitExceeded => error
        raise Limit, "Registered callback resource limit: #{error.message}. No other evidence was substituted; use the Reader interface for recovery."
      end

      def model_neighborhood_page(family:, direction:, type:, candidate: nil)
        raise Limit, 'Saved model neighborhood is unavailable with this Reader.' unless @reader.respond_to?(:model_neighborhood)

        limit, max_bytes = ModelNeighborhoodPresenter.admission(@navigation, family: family, direction: direction)
        result = @reader.model_neighborhood(@params.fetch('id'), family: family, direction: direction,
          type: type, candidate: candidate, cursor: @params['cursor'], limit: limit, max_bytes: max_bytes)
        presenter = ModelNeighborhoodPresenter.new(result, navigation: @navigation, generation: @generation,
          id: @params.fetch('id'), family: family, direction: direction, type: type, candidate: candidate,
          cursor: @params['cursor'], limit: limit, max_bytes: max_bytes)
        content = layout('Model neighborhood', presenter.render, fact: result.fetch('root'))
        raise Limit, 'Model neighborhood page exceeds its display budget.' if content.bytesize > ModelNeighborhoodPresenter::MAX_BODY_BYTES

        content
      rescue ModelNeighborhoodPresenter::DisplayLimit => error
        raise Limit, "Model neighborhood display limit: #{error.message} Use a smaller page or narrow search/collection context."
      rescue Thistle::LimitExceeded => error
        raise Limit, "Model neighborhood limit: #{error.message}"
      end

      def model_neighborhood_navigation(fact)
        return '' unless fact['kind'] == 'rails_model' && @reader.respond_to?(:model_neighborhood)

        '<nav aria-label="Saved model schema and neighborhood"><p>' +
          { 'edges' => 'Model neighborhood', 'columns' => 'Columns', 'database' => 'Database facts' }.map do |family, label|
            "<a href=\"#{h(url("/model-neighborhood/#{family}/outgoing/all", 'id' => fact.fetch('id'), 'cursor' => nil))}\">#{label}</a>"
          end.join(' · ') + '</p></nav>'
      end

      def investigation
        presenter = InvestigationPresenter.new(selection: @selection, mount: @mount, navigation: @navigation)
        evidence = InvestigationEvidence.new(reader: @reader, selection: @selection)
        body = presenter.render { |id| evidence.fetch(id) }
        content = layout('Investigation', body, fact: nil)
        raise Investigation::Limit, 'Investigation page exceeds its total output budget; no partial page was returned.' if content.bytesize > InvestigationPresenter::MAX_PAGE_BYTES

        content
      end

      def passage_page(family)
        raise Limit, 'Saved request Passage is unavailable with this Reader.' unless @reader.respond_to?(:passage)
        id = @params.fetch('id')
        limit = PassagePresenter.page_limit(@navigation)
        max_bytes = PassagePresenter.request_bytes(@navigation, family: family, action: @params['action'])
        answer = @reader.passage(id, action: @params['action'], family: family,
          limit: limit, cursor: @params['cursor'], max_bytes: max_bytes)
        PassagePresenter.validate!(answer, generation: @generation, id: id, action: @params['action'],
          family: family, cursor: @params['cursor'], limit: limit, max_bytes: max_bytes)
        body = "<h1 class=\"t1\">#{h(answer.fetch('root').fetch('name'))}</h1>"
        body << PassagePresenter.new(navigation: @navigation).render(answer)
        bounded_evidence_page('Potential request Passage', body, fact: answer.fetch('root'))
      rescue Thistle::InvalidInput => error
        raise unless error.message == 'Unknown native operation'
        raise Limit, 'Saved request Passage is unavailable with this native Reader.'
      end

      def route_actions_page
        raise Limit, 'Saved route action candidates are unavailable with this Reader.' unless @reader.respond_to?(:route_actions)
        id = @params.fetch('id')
        limit = RouteActionsPresenter.page_limit(@navigation)
        answer = @reader.route_actions(id, limit: limit, cursor: @params['cursor'], max_bytes: 32768)
        RouteActionsPresenter.validate!(answer, generation: @generation, id: id, cursor: @params['cursor'], limit: limit)
        body = "<h1 class=\"t1\">#{h(answer.fetch('root').fetch('name'))}</h1>"
        body << RouteActionsPresenter.new(navigation: @navigation).render(answer)
        bounded_evidence_page('Route action candidates', body, fact: answer.fetch('root'))
      rescue Thistle::InvalidInput => error
        raise unless error.message == 'Unknown native operation'
        raise Limit, 'Saved route action candidates are unavailable with this native Reader.'
      end

      def job_mail_page(family)
        unless NavigationContext::JOB_MAIL_FAMILIES.include?(family) && @reader.respond_to?(:job_mail)
          raise Limit, 'Saved job/mail evidence is unavailable with this Reader.'
        end
        id = @params.fetch('id')
        limit = family == 'overview' ? 8 : JobMailPresenter.page_limit(@navigation)
        result = @reader.job_mail(id, family: family, cursor: @params['cursor'], limit: limit, max_bytes: 32768)
        JobMailPresenter.validate!(result, generation: @generation, id: id, family: family, cursor: @params['cursor'], limit: limit)
        projection = ->(descriptor) { url("/job-mail/#{descriptor.fetch('family')}", 'id' => descriptor.fetch('id'), 'cursor' => descriptor['cursor']) }
        body = "<h1 class=\"t1\">#{h(result.fetch('root').fetch('name'))}</h1>"
        body << JobMailPresenter.new(generation: @generation, navigation: @navigation, projection: projection).render(result)
        bounded_evidence_page('Job, mailer and template evidence', body, fact: result.fetch('root'))
      rescue Thistle::InvalidInput => error
        raise unless error.message == 'Unknown native operation'
        raise Limit, 'Saved job/mail evidence is unavailable with this native Reader.'
      end

      # Independent, single-Reader-operation pages: no fact/source expansion or
      # automatic fan-out through other families while continuing an answer.
      def brief_page(family)
        raise Limit, 'Model family continuation is unavailable with this Reader; no other evidence was substituted.' unless @reader.respond_to?(:model_brief)
        id = @params.fetch('id')
        result = @reader.model_brief(id, family: family, cursor: @params['cursor'], limit: 8, max_bytes: 32768)
        unless result['version'] == 1 && result['generation'] == @generation && result['family'] == family &&
            result.dig('root', 'id') == id && result.dig('root', 'kind') == 'rails_model' &&
            result.dig('result', 'generation') == @generation && result.dig('result', 'fact_id') == id
          raise Thistle::InvalidSnapshot, 'Model family page identity mismatch'
        end
        raise Limit, 'Model family page exceeds its row budget.' if result.fetch('result').fetch('items').length > 8
        raise Limit, 'Model family response exceeds its byte budget.' if JSON.generate(result).bytesize > 32768
        label = { 'columns' => 'Recorded columns', 'associations' => 'Recorded associations', 'registry_candidates' => 'Registered callback candidates' }.fetch(family)
        body = @model_id ? "<h1 class=\"t1\">#{h(result.dig('root', 'name'))}: #{h(label)}</h1>" : "<h1 class=\"t1\">Saved model family: #{h(family)}</h1><p>#{brief_identity(result.fetch('root'))}</p>"
        body << "<p class=\"notice ui\">#{h(result.fetch('uncertainty'))}</p>"
        body << "<p class=\"notice ui\">Capture partial or unknown: #{h(result.fetch('capture_partial_or_unknown'))}. Empty or omitted evidence does not establish absence.</p>"
        body << "<details><summary>Page scope</summary><p>This page starts at saved position #{h(result.fetch('offset'))}; at most eight items.</p></details>"
        body << brief_family_content(family, family.tr('_', ' '), result.fetch('result'))
        if (cursor = result['next_cursor'])
          NavigationContext.validate_cursor!(cursor, generation: @generation, scope: ['model_brief', id, family])
          raise Thistle::InvalidSnapshot, 'Family continuation made no progress' if cursor == @params['cursor']
          body << "<p><a href=\"#{h(url("/brief/#{family}", 'id' => id, 'cursor' => cursor))}\">Next #{h(family.tr('_', ' '))} page</a></p>"
        end
        body << "<details><summary>Saved family coverage and work budgets</summary><pre class=\"check-data\">#{h(JSON.pretty_generate(result.reject { |key, _| key == 'result' }))}</pre></details>"
        bounded_evidence_page('Model family', body, fact: result.fetch('root'))
      end

      def references_page(scope)
        raise Limit, 'Reference continuation is unavailable with this Reader; no other evidence was substituted.' unless @reader.respond_to?(:references)
        limit = ReferencesPresenter.page_limit(@navigation, maximum: 8, candidate: !scope[:candidate].nil?)
        options = { direction: scope.fetch(:direction), cursor: @params['cursor'], limit: limit }
        options[:candidate_link] = scope[:candidate] if scope[:candidate]
        result = @reader.references(@params.fetch('id'), **options)
        unless result['generation'] == @generation && result.dig('anchor', 'id') == @params['id'] &&
            (scope[:candidate] ? result['candidate_link'] == scope[:candidate] : result['direction'] == scope[:direction])
          raise Thistle::InvalidSnapshot, 'Reference continuation identity mismatch'
        end
        rows = scope[:candidate] ? result.fetch('candidates') : result.fetch('relationships')
        raise Limit, 'Reference continuation exceeds its requested row budget.' if rows.length > limit
        raise Limit, 'Reference continuation exceeds the Reader response budget.' if JSON.generate(result).bytesize > 2_097_152
        raise Thistle::InvalidSnapshot, 'Reference continuation made no progress' if result['next_cursor'] && result['next_cursor'] == @params['cursor']
        body = +"<h1 class=\"t1\">Saved reference continuation</h1><p>At most #{limit} rows from this saved evidence scope. No source or full fact was expanded by this page.</p>"
        body << ReferencesPresenter.new(generation: @generation, mount: @mount, schema_version: @reader.manifest['schema_version'],
          files: @reader.manifest['files'], navigation: @navigation).render(result)
        bounded_evidence_page('References', body, fact: result.fetch('anchor'))
      end

      def source_file
        result = @reader.source_file(@params.fetch('path'))
        file = result.fetch('file')
        unless result['generation'] == @generation && file['path'] == @params['path']
          raise Thistle::InvalidSnapshot, 'File Source identity does not match this view'
        end
        content = result.fetch('content')
        if content.bytesize > MAX_SOURCE_BYTES || content.count("\n") > MAX_SOURCE_LINES
          raise Limit, 'This source exceeds web display limits. Use thistle source-file PATH --store STORE --generation ID.'
        end
        unless content.bytesize == file['bytes'] && result['sha256'] == file['sha256'] && Digest::SHA256.hexdigest(content) == file['sha256']
          raise Thistle::InvalidSnapshot, 'File Source digest does not match captured bytes'
        end
        rows = Highlighter.lines(content, language: Highlighter.language_for(file['path'])).each_with_index.map do |line, index|
          number = index + 1
          "<div class=\"source-row\" id=\"L#{number}\"><a class=\"ln\" href=\"#L#{number}\" aria-label=\"Line #{number}\">#{number}</a><code class=\"src\">#{line}</code></div>"
        end.join
        body = "<h1 class=\"t1\">#{h(file['path'])}</h1><p class=\"notice ui\">Captured file evidence. No declaration owner or runtime binding is inferred.</p>" \
          "<p class=\"digest\">Source SHA-256: #{h(file['sha256'])}</p><div class=\"cvwrap\" role=\"region\" aria-label=\"Captured file source\" tabindex=\"0\"><div class=\"cv codeview\">#{rows}</div></div>"
        @return_source = [file['path'], 1] if @model_id
        layout('Source', body, fact: nil)
      end

      def links
        return references_page(direction: @params.fetch('direction', 'outgoing'), candidate: nil) if @model_id
        id = @params.fetch('id')
        direction = @params.fetch('direction', 'outgoing')
        reference_limit = ReferencesPresenter.page_limit(@navigation, maximum: 50)
        references_limited = false
        references = begin
          @reader.references(id, direction: direction, limit: reference_limit) if @reader.respond_to?(:references)
        rescue Thistle::LimitExceeded
          references_limited = true
          nil
        end
        if references
          unless plain?(references, Hash) && references['generation'] == @generation &&
              plain?(references['anchor'], Hash) && references['anchor']['id'] == id &&
              references['direction'] == direction && plain?(references['relationships'], Array)
            raise Thistle::InvalidSnapshot, 'References do not match the saved anchor or relationship envelope'
          end
          raise Limit, 'References exceed the requested row budget.' if references['relationships'].length > reference_limit
        end
        # Incoming navigation needs identity only. Reader#fact expands the entire
        # outgoing link tree, which must not accompany the bounded incoming query.
        fact = if direction == 'incoming'
                 references && references.fetch('anchor')
               else
                 @reader.fact(id)
               end
        links = direction == 'incoming' ? [] : @reader.links(fact.fetch('id'))
        page = @params.fetch('page', '1').to_i
        pages = [(links.length.to_f / PAGE_SIZE).ceil, 1].max
        raise Limit, 'This links page does not exist.' if page > pages

        body = fact ? "<h1 class=\"t1\">Links for #{h(fact.fetch('name'))}</h1>" + fact_tiles(fact, details: direction != 'incoming') : '<h1 class="t1">Incoming references</h1>'
        body += "<p><a href=\"#{h(url('/links', 'direction' => 'outgoing'))}\">Outgoing references</a> · <a href=\"#{h(url('/links', 'direction' => 'incoming'))}\">Incoming references</a></p>"
        body += if references
                  ReferencesPresenter.new(generation: @generation, mount: @mount,
                    schema_version: @reader.manifest['schema_version'], files: @reader.manifest['files'], navigation: @navigation).render(references)
                elsif references_limited
                  '<p class="notice ui">Reference selection reached resource limits; no reference result was returned.</p>'
                else
                  '<p class="notice ui">Recorded-reference navigation is unavailable with this Reader.</p>'
                end
        body += '<p class="notice ui">Unresolved links are captured labels. They do not prove a runtime call or a resolved target.</p>'
        if direction == 'incoming'
          # Incoming results are already selected and bounded by the native reader.
        elsif links.empty?
          body += '<p class="ui">No links were captured for this fact. This does not prove it has no dependencies.</p>'
        else
          visible = links.slice((page - 1) * PAGE_SIZE, PAGE_SIZE)
          occurrences = ConstantOccurrence.new(generation: @generation, mount: @mount, schema_version: @reader.manifest['schema_version'])
          structured = visible.any? do |link|
            plain?(link, Hash) && plain?(link['attributes'], Hash) &&
              (link['attributes'].key?('thistle_call') || occurrences.available?(link, origin: fact))
          end
          file = call_file(fact) if structured
          source_info = call_source_info(fact, file) if file && file['bytes'] <= MAX_SOURCE_BYTES
          rows = visible.map do |link|
            detail = call_detail(link, fact, file, source_info)
            detail += occurrences.render(link, origin: fact, source_bytes: file && file['bytes'],
              source_info: source_info, verify_source: true) { |origin_id| url('/source', 'id' => origin_id) }
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
        @model_id ? layout('Check', body, fact: nil) : layout('Check', body)
      end

      private

      def comprehension_navigation(id)
        '<nav aria-label="Model reading views">' +
          "<a href=\"#{h(url('/comprehension/contributions', 'id' => id, 'cursor' => nil))}\">As-written contributions</a> · " +
          "<a href=\"#{h(url('/comprehension/methods', 'id' => id, 'cursor' => nil))}\">Methods and owners</a></nav>"
      end

      # Progressive typed entry links only. No job_mail/Source/reference query is
      # made to decide whether a source anchor exposes a supported syntax family.
      def job_mail_navigation(fact)
        return '' unless @reader.respond_to?(:job_mail)
        families = case fact['kind']
                   when 'rails_job_mail' then { 'overview' => 'Investigate saved job or mailer', 'registrations' => 'Inspect registrations', 'declarations' => 'Inspect declarations' }
                   when 'class', 'module' then { 'policy' => 'Inspect policy' }
                   when 'method' then { 'handoff' => 'Inspect handoff' }
                   when 'file' then fact['path'].to_s.end_with?('.erb') ? { 'template_references' => 'Inspect template references' } : {}
                   else {}
                   end
        return '' if families.empty?
        '<nav aria-label="Job, mailer and template investigation">' + families.map do |family, label|
          "<a href=\"#{h(url("/job-mail/#{family}", 'id' => fact.fetch('id'), 'cursor' => nil))}\">#{h(label)}</a>"
        end.join(' · ') + '</nav>'
      end

      def bounded_evidence_page(title, body, fact:)
        raise Limit, 'Evidence exceeds the rendered content budget; no partial page was returned.' if body.bytesize > InvestigationPresenter::MAX_OUTPUT_BYTES
        page = layout(title, body, fact: fact)
        raise Limit, 'Evidence exceeds the total page budget; no partial page was returned.' if page.bytesize > InvestigationPresenter::MAX_PAGE_BYTES
        page
      end

      # Custom readers remain trusted adapters; display checks also validate positions.
      def call_detail(link, fact, file, source_info)
        return '' unless link['relation'] == 'calls'
        attrs = link['attributes']
        data = plain?(attrs, Hash) ? attrs['thistle_call'] : nil
        return '' if data.nil?
        fallback = '<br>Receiver details unavailable'
        data = decoded_call(data)
        return fallback unless call_object?(data, %w[call_location receiver receiver_location safe_navigation version]) &&
          plain?(data['version'], Integer) && data['version'] == 1 && link['resolution'] == 'unresolved' &&
          [true, false].include?(data['safe_navigation']) && fact['evidence'] == 'static' && file
        file_bytes = file['bytes']
        receiver = data['receiver']
        return fallback unless call_object?(receiver, %w[kind name omitted_limit]) && [true, false].include?(receiver['omitted_limit'])
        kind, name, omitted = receiver.values_at('kind', 'name', 'omitted_limit')
        return fallback unless plain?(kind, String)
        named = %w[constant local instance_variable].include?(kind)
        return fallback unless %w[implicit self constant local instance_variable call literal expression].include?(kind)
        return fallback unless named ? (omitted ? name.nil? : constraint_string_valid?(name) && !name.empty? && name.bytesize <= 256) : (name.nil? && !omitted)
        call_loc = data['call_location']
        # Heredoc descendants need not lie within a declaration's Prism span.
        # The native reader validates same-file locations; custom readers must
        # still supply bounded locations within their pinned file metadata.
        return fallback unless valid_call_location?(call_loc, file_bytes)
        receiver_loc = data['receiver_location']
        return fallback unless kind == 'implicit' ? (receiver_loc.nil? && !data['safe_navigation']) : valid_call_location?(receiver_loc, file_bytes)
        labels = { 'implicit' => 'implicit receiver', 'self' => 'self', 'constant' => 'constant', 'local' => 'local',
          'instance_variable' => 'instance variable', 'call' => 'call result — unknown',
          'literal' => 'literal syntax — value not resolved', 'expression' => 'expression — unknown' }
        label = labels.fetch(kind)
        label += omitted ? ' — name omitted (limit)' : " #{name}" if named
        label += ' · safe navigation' if data['safe_navigation']
        if file_bytes > MAX_SOURCE_BYTES || (source_info && source_info[:over_limit])
          command = "thistle source #{fact.fetch('id')} --store STORE --generation #{@generation}"
          return "<br>#{h(label)} · Source exceeds web display limits. For call line #{call_loc['start_line']}, " \
            "use <code>#{h(command)}</code>. Replace STORE with your capture store."
        end
        return fallback unless source_info && valid_source_location?(call_loc, source_info) &&
          (receiver_loc.nil? || valid_source_location?(receiver_loc, source_info)) &&
          call_loc['start_line'] <= source_info[:rendered_lines]
        grouped = %w[implicit self].include?(kind) || (named && !omitted)
        anchor = "#{url('/source', 'id' => fact.fetch('id'))}#L#{call_loc['start_line']}"
        "<br>#{h(label)} · <a href=\"#{h(anchor)}\">#{grouped ? 'Representative source' : 'Source'}</a>"
      end

      # Decode only the current displayed link, and only in explicit schema 2 or 3.
      # The usual v1 validation below remains the single display boundary.
      def decoded_call(data)
        return data unless plain?(data, Hash) && plain?(data['version'], Integer) && data['version'] == 2
        manifest = @reader.manifest
        return nil unless plain?(manifest, Hash) && plain?(manifest['schema_version'], Integer) && [2, 3].include?(manifest['schema_version'])
        # Schema 3 preserves extended objects; inspect only the known fields.
        # Schema 2 retains its exact-wrapper contract. Unknown fields stay opaque.
        return nil if manifest['schema_version'] == 2 && !call_object?(data, %w[version data])
        tuple = data['data']
        return nil unless plain?(tuple, Array) && tuple.length == 6
        kind, name, omitted, safe, call_tuple, receiver_tuple = tuple
        call_location = tuple_location(call_tuple)
        receiver_is_null = plain?(receiver_tuple, NilClass)
        receiver_location = receiver_is_null ? nil : tuple_location(receiver_tuple)
        return nil unless call_location && (receiver_is_null || receiver_location)
        { 'version' => 1, 'safe_navigation' => safe, 'call_location' => call_location,
          'receiver_location' => receiver_location,
          'receiver' => { 'kind' => kind, 'name' => name, 'omitted_limit' => omitted } }
      end

      def tuple_location(tuple)
        return nil unless plain?(tuple, Array) && tuple.length == 4
        start_byte, end_byte, start_line, end_line = tuple
        { 'start_byte' => start_byte, 'end_byte' => end_byte,
          'start_line' => start_line, 'end_line' => end_line }
      end

      def call_object?(value, fields)
        plain?(value, Hash) && value.size == fields.length &&
          value.keys.all? { |key| plain?(key, String) && fields.include?(key) }
      end

      def call_file(fact)
        path = fact['path']
        return nil unless constraint_string_valid?(path) && path.bytesize <= 4_096
        manifest = @reader.manifest
        return nil unless plain?(manifest, Hash)
        files = manifest['files']
        return nil unless plain?(files, Array) && files.length <= 10_000
        file = files.find { |entry| plain?(entry, Hash) && plain?(entry['path'], String) && entry['path'] == path }
        bytes = file && file['bytes']
        file if plain?(bytes, Integer) && bytes >= 0 && bytes <= 4_194_304
      end

      # One bounded source read and newline index per structured Links page.
      def call_source_info(fact, file)
        result = @reader.source(fact.fetch('id'))
        return nil unless plain?(result, Hash) && result['generation'] == @generation && result['fact'] == fact
        content = result['content']
        return nil unless plain?(content, String) && content.bytesize == file['bytes'] && content.bytesize <= MAX_SOURCE_BYTES && content.encoding == Encoding::UTF_8 && content.valid_encoding?
        digest = result['sha256']
        return nil unless plain?(digest, String) && digest == file['sha256'] && Digest::SHA256.hexdigest(content) == digest
        offsets = []
        content.each_byte.with_index do |byte, index|
          next unless byte == 10
          return { over_limit: true } if offsets.length == MAX_SOURCE_LINES
          offsets << index
        end
        { content: content, offsets: offsets, rendered_lines: offsets.length + (content.end_with?("\n") ? 0 : 1) }
      rescue Thistle::Error
        nil
      end

      def valid_source_location?(location, info)
        offsets = info[:offsets]
        %w[start end].all? do |edge|
          byte = location["#{edge}_byte"]
          line = offsets.bsearch_index { |offset| offset >= byte } || offsets.length
          location["#{edge}_line"] == line + 1
        end
      end

      def valid_call_location?(location, file_bytes)
        return false unless call_object?(location, %w[start_byte end_byte start_line end_line])
        a, b, c, d = location.values_at('start_byte', 'end_byte', 'start_line', 'end_line')
        [a, b, c, d].all? { |n| plain?(n, Integer) && n >= 0 && n <= 4_194_304 } &&
          a <= b && b <= file_bytes && c > 0 && c <= d && d <= file_bytes + 1
      end

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end

      def investigation_control(id)
        if @selection.ids.include?(id)
          "<a href=\"#{h(@navigation.url(@current_path, selection: @selection.remove(id)))}\">Remove from investigation</a>"
        elsif @selection.ids.length == Investigation::MAX_SELECTIONS
          '<span class="disabled">Collection full (24). Open Investigation to remove a selection before collecting another.</span>'
        else
          "<a href=\"#{h(@navigation.url(@current_path, selection: @selection.add(id)))}\">Collect in investigation</a>"
        end
      end

      def url(path, extra = {})
        @navigation.url(path, extra)
      end

      def layout(title, body, fact: :from_params)
        selected = fact == :from_params ? (@params['id'] && @reader.fact(@params['id'])) : fact
        file_source = @params['path'] && title == 'Source'
        source_link = selected ? nav_link('Source', '/source', title, 's', selected['id']) : '<span class="disabled">Source <small>Choose a result</small></span>'
        source_link = nav_link('Source', '/source', title, 's') if file_source
        links_link = selected ? nav_link('Links', '/links', title, 'g', selected['id']) : '<span class="disabled">Links <small>Choose a result</small></span>'
        if @model_id && !selected
          source_link = nav_link('Source', '/source', title, 's', @model_id)
          links_link = nav_link('Links', '/links', title, 'g', @model_id)
        end
        brand_url = url('/')
        navigation = nav_link('Find', '/', title, 'f') + source_link + links_link + nav_link('Check', '/check', title, nil)
        navigation += "<a href=\"#{h(url('/investigation'))}\"#{' aria-current="page"' if title == 'Investigation'}>Investigation (#{@selection.ids.length})</a>"
        if selected
          navigation += investigation_control(selected.fetch('id'))
        end
        context_notice = @navigation.search_omitted ? '<p class="notice ui">Search context exceeds the navigation link budget. Narrow the query or filters in the Find form to retain them in links; Back returns to the previous page.</p>' : ''
        model_return = ''
        if @model_id
          target = @navigation.reading_url
          if @navigation.source_position
            target += "#reading-file-#{@navigation.source_position[0]}-L#{@navigation.source_position[1]}"
          elsif @return_source && @return_source[0] && @return_source[1]
            target += "#reading-file-#{Digest::SHA256.hexdigest(@return_source[0])}-L#{@return_source[1]}"
          end
          label = @reading_title ? "Return to #{@reading_title} reading" : 'Return to model reading'
          model_return = "<p class=\"ui model-return\"><a href=\"#{h(target)}\">#{h(label)}</a></p>"
        end
        <<~HTML
          <!doctype html>
          <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{h(title)} · Thistle Map</title>
          <link rel="stylesheet" href="#{h(@mount)}/assets/woods-map-tokens.css">
          <link rel="stylesheet" href="#{h(@mount)}/assets/map.css">
          <script src="#{h(@mount)}/assets/map.js" defer></script></head>
          <body><a class="skip" href="#main">Skip to evidence</a><div class="wm thistle-workbench#{@model_id ? ' model-context' : ''}" id="workbench" tabindex="-1">
          <header class="app-header"><a class="brand" href="#{h(brand_url)}">Thistle <span>Map</span></a>
          <form method="get" action="#{h(@mount)}/" class="find-form"><label for="find-query">Find code</label>
          <input type="search" name="q" id="find-query" value="#{h(@params.fetch('q', ''))}" maxlength="256" placeholder="Literal source, name or metadata" autocomplete="off">
          #{@model_id ? model_search_filters : ''}
          <label for="find-domain">Domain</label><select name="domain" id="find-domain">#{%w[all source metadata].map { |value| "<option value=\"#{value}\"#{' selected' if @params.fetch('domain', 'all') == value}>#{value}</option>" }.join}</select>
          <label for="find-kind">Kind</label><input name="kind" id="find-kind" value="#{h(@params['kind'])}" placeholder="Any kind">
          <label for="find-prefix">Path prefix</label><input name="prefix" id="find-prefix" value="#{h(@params['prefix'])}" placeholder="Any captured path">
          #{@model_id ? '</details>' : ''}<input type="hidden" name="generation" value="#{h(@generation)}">#{@selection.ids.empty? ? '' : "<input type=\"hidden\" name=\"selection\" value=\"#{h(@selection.ids.join(','))}\">"}<button class="btn primary" type="submit">Find</button></form></header>
          <nav aria-label="Evidence views">#{navigation}</nav>
          <main id="main" tabindex="-1"><p class="capture ui">Saved capture <code>#{h(@generation[0, 12])}</code> · live freshness not checked</p>
          #{context_notice}
          #{model_return}
          #{body}</main>
          <footer><label class="shortcut-setting ui" hidden><input id="letter-shortcuts" type="checkbox"> Use letter shortcuts</label>
          <p class="ui" id="shortcut-help">Optional: F Find, S Source, G Links, J/K results. Keys act only within this workbench and never while entering text.</p>
          <noscript><p class="ui">Letter shortcuts require JavaScript. All evidence views work through the visible links and form.</p></noscript>
          <p class="ui">Private implementation preview · incomplete product coverage</p></footer></div></body></html>
        HTML
      end

      def model_search_filters
        active = %w[domain kind prefix].filter_map do |key|
          value = @params[key]
          "#{key}: #{value}" if value && !value.empty? && !(key == 'domain' && value == 'all')
        end
        label = active.empty? ? 'Search filters' : "Search filters — #{active.join(' · ')}"
        "<details class=\"model-find\"><summary>#{h(label)}</summary>"
      end

      def nav_link(label, path, active, key, id = nil)
        attrs = label == active ? ' aria-current="page"' : ''
        attrs += " data-shortcut=\"#{key}\"" if key
        "<a href=\"#{h(url(path, id ? { 'id' => id } : {}))}\"#{attrs}>#{label}</a>"
      end

      def route_actions_navigation(fact)
        return '' unless fact['kind'] == 'route' && @reader.respond_to?(:route_actions)
        links = "<p><a href=\"#{h(url('/route-actions', 'id'=>fact.fetch('id')))}\">Inspect controller/action candidates</a></p>"
        links << "<p><a href=\"#{h(url('/passage/sequence', 'id'=>fact.fetch('id')))}\">Inspect potential request Passage</a></p>" if @reader.respond_to?(:passage)
        links
      end

      def fact_tiles(fact, details: true)
        tiles = [
          ['Identity', [['Kind', fact['kind']], ['Evidence', fact['evidence']]]],
          ['Source', [['File', fact['path'] || 'Unavailable'], ['Line', fact.dig('location', 'start_line') || 'Unavailable']]]
        ]
        if details && fact['kind'] == 'route'
          tiles << ['Route conditions', [['Observed conditions', constraint_summary(fact)],
            ['Meaning', 'Route presence does not prove a request will match.']]]
        end
        identity = '<div class="facts">' + tiles.map do |eyebrow, rows|
          klass = eyebrow == 'Route conditions' ? ' class="route-conditions"' : ''
          "<div#{klass}><span class=\"eyebrow\">#{h(eyebrow)}</span><dl>" +
            rows.map { |label, value| "<dt>#{h(label)}</dt><dd>#{h(value)}</dd>" }.join + '</dl></div>'
        end.join + '</div>'
        identity += job_mail_navigation(fact)
        identity += route_actions_navigation(fact)
        identity += model_neighborhood_navigation(fact)
        return identity + '<p class="notice ui">Detailed fact evidence was not loaded for this incoming view. Open Source or Outgoing references to inspect it.</p>' unless details

        identity + model_brief(fact) + ModelPresenter.render(fact) +
          CallbackPresenter.new(generation: @generation, reader: @reader, mount: @mount, navigation: @navigation).render(fact)
      end

      # Rust selects every item and its evidence. Map only renders the bounded
      # summary on the already pinned Reader; incoming identity-only views skip it.
      def model_brief(fact)
        return '' unless fact['kind'] == 'rails_model'
        heading = '<section aria-label="Saved model investigation"><h2>Saved model investigation</h2>'
        unless @reader.respond_to?(:model_brief)
          return heading + '<p class="notice ui">Model brief unavailable with this Reader. Possible relationships and effects remain unknown.</p></section>'
        end
        raise Thistle::InvalidSnapshot, 'Model brief Reader generation mismatch' unless @reader.generation == @generation

        result = @reader.model_brief(fact.fetch('id'), limit: 8, max_bytes: 32768)
        unless result['version'] == 1 && result['generation'] == @generation && result.dig('root', 'id') == fact['id'] &&
            result.dig('root', 'kind') == 'rails_model' &&
            result.fetch('families').values.all? { |family| family['generation'] == @generation }
          raise Thistle::InvalidSnapshot, 'Model brief identity does not match this view'
        end
        body = heading + "<p class=\"notice ui\">#{h(result.fetch('uncertainty'))}</p>"
        body << '<p>Recorded declarations, registered callbacks and source-supported potential are separate evidence. Execution, conditions, runtime/source coherence and model-to-registry binding remain unknown. Columns are recorded declarations; no live database was consulted by this view.</p>'
        coverage = result.fetch('coverage')
        body << "<p>Capture partial or unknown: #{h(brief_value(coverage['capture_partial_or_unknown']))}. Coverage families not projected: #{h(brief_value(coverage['families_not_projected']))}.</p>"
        body << "<p>Brief limit: #{h(result.dig('limits', 'items_per_family'))} items per family; returned #{h(result.dig('usage', 'returned_items'))} items. Empty or shortened results do not establish absence.</p>"
        labels = { 'columns' => 'Recorded columns', 'associations' => 'Recorded associations',
          'registry_candidates' => 'Callback registry label candidates', 'callbacks' => 'Registered callbacks and potential requests',
          'outgoing' => 'Outgoing recorded relationships', 'incoming' => 'Incoming recorded relationships' }
        labels.each do |name, label|
          family = result.fetch('families').fetch(name)
          body << brief_family_content(name, label, family)
        end
        body << "<details><summary>Brief capture coverage and request budgets</summary><pre class=\"check-data\">#{h(JSON.pretty_generate(result.reject { |key, _| key == 'families' }))}</pre></details>"
        body + '</section>'
      rescue Thistle::LimitExceeded
        heading + '<p class="notice ui">Model brief reached resource limits; no brief was returned. Relationships and potential effects remain unknown.</p></section>'
      rescue Thistle::InvalidInput => error
        raise unless error.message == 'Unknown native operation'
        heading + '<p class="notice ui">Native model brief API unavailable. Relationships and potential effects remain unknown.</p></section>'
      end

      def brief_family_content(name, label, family)
        body = +''
        body << "<section aria-label=\"#{h(label)}\"><h3>#{h(label)}</h3>"
        body << "<p>Status: #{h(family.fetch('status'))} · #{h(family.fetch('reason'))}. Provenance: #{h(family.fetch('provenance'))}. "
        body << "Known omitted: #{h(brief_value(family['known_omitted']))}; unsearched: #{h(brief_value(family['unsearched']))}; output truncated: #{h(brief_value(family.fetch('output_truncated', false)))}.</p>"
        items = family.fetch('items')
        if items.empty?
          body << '<p>No items returned in this brief family. Check status, capture coverage and omissions before inferring absence.</p>'
        elsif name == 'columns' || name == 'associations'
          fields = name == 'columns' ? %w[name type null] : %w[name macro target polymorphic status]
          rows = items.map { |item| '<tr>' + fields.map { |key| "<td>#{h(brief_value(item[key]))}</td>" }.join + '</tr>' }.join
          headings = name == 'columns' ? ['Name', 'Recorded type', 'Allows null'] : ['Name', 'Macro', 'Target label', 'Polymorphic', 'Binding evidence']
          body << table(label, headings, rows)
        else
          items.each do |item|
            body << case name
                    when 'registry_candidates' then "<p>#{brief_identity(item)}</p>"
                    when 'callbacks' then brief_callback(item)
                    else brief_relationship(item)
                    end
          end
        end
        body << brief_followup(family['followup'])
        # Preserve component scan completeness, unknown counts, binding and
        # continuation/cost metadata without interpreting them as new semantics.
        metadata = family.reject { |key, _| key == 'items' }
        body << "<details><summary>#{h(label)} coverage and limits</summary><pre class=\"check-data\">#{h(JSON.pretty_generate(metadata))}</pre></details></section>"
        body
      end

      def brief_value(value)
        value.nil? ? 'Unknown' : value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value.to_s
      end

      def brief_identity(identity)
        id = identity.fetch('id')
        raise Thistle::InvalidSnapshot, 'Invalid brief evidence ID' unless /\A[0-9a-f]{64}\z/.match?(id)
        if @model_id && identity['kind'] == 'rails_save_callbacks'
          return "<a href=\"#{h(url('/model-callbacks', 'id' => id))}\">#{h(identity.fetch('name'))}: registered callback evidence</a> · " \
            "<a href=\"#{h(url('/model-callbacks/full', 'id' => id))}\">Full registered callbacks (up to 200)</a> · saved registry candidate; model binding unknown"
        end
        "#{h(identity.fetch('name'))} #{h([identity['kind'], identity['evidence']].compact.join('; '))} · " \
          "<a href=\"#{h(url('/source', 'id' => id))}\">Source for #{h(identity.fetch('name'))}</a> · " \
          "<a href=\"#{h(url('/links', 'id' => id, 'direction' => 'outgoing'))}\">Links for #{h(identity.fetch('name'))}</a>"
      end

      def brief_relationship(item)
        link = item.fetch('link')
        body = "<article><h4>#{h(link['relation'])}: #{h(link['target'])}</h4><p>#{brief_identity(item.fetch('origin'))}</p>"
        body << "<p>#{h(item.fetch('match_basis'))} · resolution: #{h(link['resolution'])}. Candidate matches: #{h(brief_value(item['candidate_matches']))}; candidate search complete: #{h(brief_value(item['candidate_search_complete']))}; detail omitted: #{h(brief_value(item['detail_omitted']))}. Labels do not establish runtime binding.</p>"
        item.fetch('candidates').each { |candidate| body << "<p>Label candidate: #{brief_identity(candidate)}</p>" }
        body + brief_item_details('Saved relationship evidence', item) + '</article>'
      end

      def brief_callback(item)
        analysis = item.fetch('explanation')
        body = "<article><h4>Registered position #{h(item.fetch('position'))} · #{h(item['kind'])}</h4>"
        body << "<p>Registry evidence: #{h(item.fetch('registry_provenance'))}; inherited: #{h(brief_value(item['inherited']))}. Position is not execution order.</p>"
        body << "<p>Filter: #{h(brief_value(item['filter']))}. Conditions (not evaluated): if #{h(brief_value(item['if']))}; unless #{h(brief_value(item['unless']))}.</p>"
        body << "<p>Source explanation: #{h(analysis.fetch('status'))} · #{h(analysis.fetch('reason'))}; binding: #{h(analysis.fetch('binding'))}; links search complete: #{h(brief_value(analysis['links_search_complete']))}.</p>"
        if analysis['method']
          body << "<p>Captured declaration: #{brief_identity(analysis.fetch('method'))}</p>"
        end
        analysis.fetch('effects').each do |effect|
          body << "<p>Source-supported potential request: <code>#{h(effect.fetch('operation'))}</code> · #{h(effect.fetch('provenance'))}. Invocation and delivery unknown.</p>"
          body << "<pre><code>#{h(effect.fetch('source_excerpt'))}</code></pre>"
          body << '<p>Supporting excerpt shortened; exact saved span remains recorded.</p>' if effect['excerpt_truncated']
          source, span = analysis.fetch('source'), effect.fetch('call_span')
          body << "<p>Saved file: #{h(source.fetch('path'))}; SHA-256: #{h(source.fetch('sha256'))}; call bytes [#{h(span.fetch('start_byte'))}, #{h(span.fetch('end_byte'))}).</p>"
          if source.fetch('bytes') <= MAX_SOURCE_BYTES && source.fetch('lines') <= MAX_SOURCE_LINES && span.fetch('start_line') <= MAX_SOURCE_LINES
            anchor = url('/source', 'id' => analysis.fetch('method').fetch('id')) + "#L#{Integer(span.fetch('start_line'))}"
            body << "<p><a href=\"#{h(anchor)}\">Supporting captured source at line #{h(span.fetch('start_line'))} (coherence unknown)</a></p>"
          else
            command = "thistle source #{analysis.fetch('method').fetch('id')} --store STORE --generation #{@generation}"
            body << "<p>Supporting source exceeds the web display budget. Use <code>#{h(command)}</code> for the complete captured file; replace STORE with your saved store.</p>"
          end
        end
        body << "<p>Known potential effects omitted: #{h(brief_value(analysis['known_effects_omitted']))}; effects non-exhaustive: #{h(brief_value(analysis['effects_non_exhaustive']))}.</p>"
        body + brief_item_details('Saved callback evidence', item) + '</article>'
      end

      def brief_item_details(label, item)
        "<details><summary>#{h(label)}</summary><pre class=\"check-data\">#{h(JSON.pretty_generate(item))}</pre></details>"
      end

      def brief_followup(followup)
        return '' unless followup
        raise Thistle::InvalidSnapshot, 'Model brief follow-up generation mismatch' unless followup['generation'] == @generation
        operation, id = followup.values_at('operation', 'id')
        raise Thistle::InvalidSnapshot, 'Invalid brief follow-up ID' unless /\A[0-9a-f]{64}\z/.match?(id)
        case operation
        when 'references'
          direction = followup.fetch('direction')
          raise Thistle::InvalidSnapshot, 'Invalid reference direction' unless %w[incoming outgoing].include?(direction)
          "<p><a href=\"#{h(url("/references/#{direction}", 'id' => id, 'cursor' => followup['cursor']))}\">Inspect #{h(direction)} references, up to eight per page</a></p>"
        when 'callback_effects'
          "<p><a href=\"#{h(url('/links', 'id' => id, 'direction' => 'outgoing'))}\">Inspect registered callback evidence in Links</a></p>"
        when 'model_brief'
          family = followup.fetch('family')
          raise Thistle::InvalidSnapshot, 'Invalid model family' unless NavigationContext::FAMILIES.include?(family)
          "<p><a href=\"#{h(url("/brief/#{family}", 'id' => id, 'cursor' => followup['cursor']))}\">Browse all saved #{h(family.tr('_', ' '))}, eight per page</a></p>"
        else ''
        end
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
