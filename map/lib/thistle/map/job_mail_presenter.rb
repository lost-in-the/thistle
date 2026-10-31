# frozen_string_literal: true

require 'erb'
require 'json'
require_relative 'navigation_context'

module Thistle
  module Map
    # Presentation of Rust/public Reader answers only. Root NavigationContext
    # owns generation/selection/query state and all route authority.
    class JobMailPresenter
      MAX_BYTES = 65_536
      MAX_ITEMS = 16
      LABELS = { 'overview' => 'overview', 'registrations' => 'registrations', 'declarations' => 'declarations',
        'policy' => 'policy', 'handoff' => 'handoff', 'template_references' => 'template references' }.freeze
      EVIDENCE_LABELS = { 'policy_declaration' => 'Declared policy', 'mailer_action_candidate' => 'Potential mailer action',
        'delivery_request_candidate' => 'Potential delivery request', 'template_selection' => 'Template selection evidence',
        'instance_variable' => 'Instance variable reference', 'helper_candidate' => 'Potential helper', 'local_or_helper_candidate' => 'Local or helper candidate', 'call_or_helper_candidate' => 'Call or helper candidate', 'partial_candidate' => 'Potential partial' }.freeze

      # Display-contract admission, not semantic selection. Native owns rows,
      # candidates and cursor positions; this validates typed saved witnesses.
      def self.page_limit(navigation)
        # At most five witness/followup hrefs per row; leave half the existing
        # body budget for escaped evidence/coverage. Only display admission:
        # Native still selects rows and produces every continuation position.
        [[(MAX_BYTES / 2) / (navigation.reference_url_bytes * 5), 1].max, 8].min
      end

      def self.validate!(answer, generation:, id:, family:, cursor: nil, limit: 8)
        raise Thistle::InvalidSnapshot, 'Invalid job/mail envelope' unless answer.instance_of?(Hash)
        raise Thistle::LimitExceeded, 'Job/mail response exceeds display admission' if JSON.generate(answer).bytesize > 32768
        unless answer['version'] == 1 && answer['generation'] == generation && answer['family'] == family &&
            NavigationContext::JOB_MAIL_FAMILIES.include?(family) && answer['provenance'] == 'saved_evidence' &&
            answer['coverage'].instance_of?(Hash) && answer['unknowns'].instance_of?(Hash) && answer['cost'].instance_of?(Hash) &&
            answer['semantics'].instance_of?(String) && [true,false].include?(answer['page_complete']) &&
            %w[coherence binding execution delivery].all? { |key| answer['unknowns'][key] == 'unknown' }
          raise Thistle::InvalidSnapshot, 'Job/mail envelope mismatch'
        end
        validate_identity!(answer.fetch('root'), generation: generation, id: id)
        items = answer.fetch('items')
        raise Thistle::InvalidSnapshot, 'Invalid job/mail page items' unless items.instance_of?(Array) && items.length <= limit
        expected = { 'overview' => 'family', 'registrations' => 'registration', 'declarations' => 'declaration_candidate',
          'policy' => 'source_evidence', 'handoff' => 'source_evidence', 'template_references' => 'source_evidence' }.fetch(family)
        items.each do |item|
          raise Thistle::InvalidSnapshot, 'Job/mail family row mismatch' unless item.instance_of?(Hash) && item['kind'] == expected
          if item['kind'] == 'family'
            validate_request!(item.fetch('request'), generation: generation, id: id, family: item.fetch('family'))
            raise Thistle::InvalidSnapshot, 'Initial family request has a cursor' unless item.dig('request','cursor').nil?
          elsif item['kind'] == 'registration'
            validate_identity!(item.fetch('root'), generation: generation, id: id)
            raise Thistle::InvalidSnapshot, 'Invalid job/mail registration row' unless item['registration'].instance_of?(Hash)
          else
            if item['kind'] == 'source_evidence'
              validate_identity!(item.fetch('root'), generation: generation, id: id)
              raise Thistle::InvalidSnapshot, 'Invalid source evidence row' unless item['evidence'].instance_of?(Hash) && Investigation::DIGEST.match?(item['sha256'].to_s)
              kinds = { 'policy' => %w[policy_declaration], 'handoff' => %w[mailer_action_candidate delivery_request_candidate template_selection],
                'template_references' => %w[instance_variable helper_candidate local_or_helper_candidate call_or_helper_candidate partial_candidate] }.fetch(family)
              raise Thistle::InvalidSnapshot, 'Unsupported source evidence type' unless kinds.include?(item.dig('evidence','kind'))
              validate_span!(item.fetch('evidence').fetch('span'))
            end
            unless item['candidate_matches'].instance_of?(Integer) && item['candidate_matches'] >= 0 &&
                %w[ambiguous unique_label_binding_unknown no_recorded_match_binding_or_capture_unknown unsupported_selection_unknown].include?(item['candidate_status'])
              raise Thistle::InvalidSnapshot, 'Invalid saved candidate metadata'
            end
            if item['candidate']
              candidate = item.fetch('candidate')
              validate_identity!(candidate, generation: generation)
              validate_request!(item.fetch('request'), generation: generation, id: candidate.fetch('id'), family: 'overview')
              raise Thistle::InvalidSnapshot, 'Candidate overview has a cursor' unless item.dig('request','cursor').nil?
            elsif item['request']
              raise Thistle::InvalidSnapshot, 'Job/mail request lacks its typed candidate'
            end
          end
        end
        next_cursor, request = answer.values_at('next_cursor','continuation')
        if answer['page_complete']
          raise Thistle::InvalidSnapshot, 'Complete job/mail page has continuation' if next_cursor || request
        else
          validate_request!(request, generation: generation, id: id, family: family)
          unless next_cursor.instance_of?(String) && request['cursor'] == next_cursor && next_cursor != cursor
            raise Thistle::InvalidSnapshot, 'Job/mail continuation made no progress or mismatched cursor'
          end
        end
        answer
      rescue KeyError, TypeError, JSON::GeneratorError, JSON::NestingError, Investigation::Invalid => error
        raise Thistle::InvalidSnapshot, "Invalid job/mail projection (#{error.class})"
      end

      def self.validate_identity!(identity, generation:, id: nil)
        unless identity.instance_of?(Hash) && (identity.keys - %w[generation id kind name evidence path span]).empty? &&
            identity['generation'] == generation && Investigation::DIGEST.match?(identity['id'].to_s) && (!id || identity['id'] == id) &&
            %w[rails_job_mail class module method file].include?(identity['kind']) && %w[static runtime].include?(identity['evidence']) &&
            identity['name'].instance_of?(String) && identity['name'].bytesize <= 4096 &&
            (identity['path'].nil? || identity['path'].instance_of?(String))
          raise Thistle::InvalidSnapshot, 'Job/mail typed identity mismatch'
        end
        validate_span!(identity['span']) if identity['span']
      end

      def self.validate_span!(span)
        unless span.instance_of?(Hash) && span.keys.sort == %w[end_byte end_line start_byte start_line] &&
            span.values.all? { |n| n.instance_of?(Integer) && n >= 0 } && span['start_line'].positive? &&
            span['end_line'] >= span['start_line'] && span['end_byte'] >= span['start_byte']
          raise Thistle::InvalidSnapshot, 'Invalid job/mail physical span'
        end
      end

      def self.validate_request!(request, generation:, id:, family:)
        unless request.instance_of?(Hash) && request.keys.sort == %w[cursor family generation id operation] &&
            request['operation'] == 'job_mail' && request['generation'] == generation && request['id'] == id &&
            request['family'] == family && NavigationContext::JOB_MAIL_FAMILIES.include?(family)
          raise Thistle::InvalidSnapshot, 'Job/mail descriptor mismatch'
        end
        NavigationContext.validate_cursor!(request['cursor'], generation: generation, scope: ['job_mail',id,family]) if request['cursor']
      end

      def initialize(generation:, navigation:, projection: nil)
        @generation, @navigation, @projection = generation, navigation, projection
      end

      def render(answer)
        raise Thistle::InvalidSnapshot, 'Job/mail answer generation mismatch' unless answer['generation'] == @generation
        raise Thistle::LimitExceeded, 'Job/mail answer exceeds the display budget' if JSON.generate(answer).bytesize > MAX_BYTES
        raise Thistle::InvalidSnapshot, 'Unsupported job/mail answer version' unless answer['version'] == 1
        root = answer.fetch('root')
        check_identity(root)
        items = answer.fetch('items')
        raise Thistle::InvalidSnapshot, 'Job/mail page exceeds item limit' if items.length > MAX_ITEMS
        body = +'<section aria-label="Job, mailer and template evidence"><h2>Job, mailer and template evidence</h2>'
        body << "<p>#{h(root.fetch('name'))} · #{h(answer.fetch('family'))}</p>"
        body << notice(answer.fetch('semantics'))
        body << source_links(root)
        items.each { |item| body << render_item(item) }
        body << notice('No rows returned in this family page. Check coverage and unknowns before inferring absence.') if items.empty?
        body << '<h3>Coverage and unresolved facts</h3>' << details(answer.fetch('coverage'))
        body << details(answer.fetch('unknowns'))
        body << request_link(answer['continuation'], 'Continue this evidence family') if answer['continuation']
        body << notice('This page has a continuation; visible rows do not cover the whole eligible family.') unless answer['page_complete']
        body << '</section>'
        raise Thistle::LimitExceeded, 'Rendered job/mail answer exceeds the display budget' if body.bytesize > MAX_BYTES
        body
      end

      private

      def render_item(item)
        body = +'<article>'
        case item.fetch('kind')
        when 'family'
          body << "<h3>#{h(LABELS.fetch(item.fetch('family')))}</h3>"
          body << request_link(item.fetch('request'), "Inspect #{LABELS.fetch(item.fetch('family'))}")
        when 'registration'
          body << "<h3>Registered position #{h(item.fetch('position'))}</h3>"
          row = item.fetch('registration')
          body << "<p>Exception label: #{h(row['exception'] || 'Unknown')}</p>"
          body << details(row.fetch('handler'))
          body << "<p>Shared registry row with superclass: #{h(row['shared_with_superclass'].nil? ? 'Unknown' : row['shared_with_superclass'])}. Declaration association: unknown.</p>"
        when 'declaration_candidate'
          body << "<h3>#{h(item.fetch('role'))}: #{h(item.fetch('label'))}</h3>"
          body << candidate(item)
        when 'source_evidence'
          evidence = item.fetch('evidence')
          body << "<h3>#{h(EVIDENCE_LABELS.fetch(evidence.fetch('kind')))}</h3>"
          body << details(evidence.reject { |key, _| key == 'span' })
          body << "<p>Saved source SHA-256: <code>#{h(item.fetch('sha256'))}</code></p>"
          body << source_links(item.fetch('root'), evidence['span'])
          body << candidate(item)
        else
          raise Thistle::InvalidSnapshot, 'Unknown job/mail row type'
        end
        body << '</article>'
      end

      def candidate(item)
        body = "<p>#{h(item.fetch('candidate_status'))} · #{h(item.fetch('candidate_matches'))} saved candidates. Binding, invocation and delivery unknown.</p>"
        if (identity = item['candidate'])
          check_identity(identity)
          body << "<p>#{h(identity.fetch('kind'))}: #{h(identity.fetch('name'))}</p>"
          body << source_links(identity)
          body << request_link(item.fetch('request'), 'Inspect this saved candidate')
        end
        body
      end

      def check_identity(identity)
        raise Thistle::InvalidSnapshot, 'Job/mail candidate generation mismatch' unless identity['generation'] == @generation
        raise Thistle::InvalidSnapshot, 'Job/mail candidate identity missing' unless identity['id'].is_a?(String) && identity['kind'].is_a?(String)
      end

      def source_links(identity, span = nil)
        check_identity(identity)
        return '' unless identity['path'] && identity['span']
        line = (span || identity['span'])['start_line']
        return notice('Supporting source line exceeds the existing Source display limit.') if line.is_a?(Integer) && line > 10_000
        return '' unless line.is_a?(Integer) && line.positive?
        source = @navigation.url('/source', { 'id' => identity.fetch('id') })
        links = @navigation.url('/links', { 'id' => identity.fetch('id'), 'direction' => 'outgoing' })
        "<p><a href=\"#{h(source)}#L#{line}\">Supporting captured source, line #{line}</a> · <a href=\"#{h(links)}\">Outgoing saved links</a></p>"
      end

      def request_link(request, label)
        raise Thistle::InvalidSnapshot, 'Job/mail request generation mismatch' unless request['generation'] == @generation && request['operation'] == 'job_mail'
        # Root supplies the projection route once wired. A missing route is
        # visible, never replaced with guessed URLs or hand-built state.
        return notice("#{label}: projection route not integrated. Reader request family: #{request['family']}.") unless @projection
        "<p><a href=\"#{h(@projection.call(request))}\">#{h(label)}</a></p>"
      end

      def details(value)
        case value
        when Hash
          '<dl>' + value.map { |key, item| "<dt>#{h(key)}</dt><dd>#{details(item)}</dd>" }.join + '</dl>'
        when Array
          '<ul>' + value.map { |item| "<li>#{details(item)}</li>" }.join + '</ul>'
        when NilClass then 'Unknown'
        else h(value)
        end
      end

      def h(value) = ERB::Util.html_escape(String.new(value.to_s))
      def notice(value) = "<p class=\"notice ui\">#{h(value)}</p>"
    end
  end
end
