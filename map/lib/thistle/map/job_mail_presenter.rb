# frozen_string_literal: true

require 'erb'
require 'json'

module Thistle
  module Map
    # Presentation of Rust/public Reader answers only. Root NavigationContext
    # owns generation/selection/query state and all route authority.
    class JobMailPresenter
      MAX_BYTES = 65_536
      MAX_ITEMS = 16

      def initialize(generation:, navigation:, projection: nil)
        @generation, @navigation, @projection = generation, navigation, projection
      end

      def render(answer)
        raise Thistle::InvalidSnapshot, 'Job/mail answer generation mismatch' unless answer['generation'] == @generation
        return notice('Job/mail answer exceeds the display budget; request a smaller Reader page.') if JSON.generate(answer).bytesize > MAX_BYTES
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
        return notice('Rendered job/mail answer exceeds the display budget; request a smaller Reader page.') if body.bytesize > MAX_BYTES
        body
      end

      private

      def render_item(item)
        body = +'<article>'
        case item.fetch('kind')
        when 'family'
          body << "<h3>#{h(item.fetch('family'))}</h3>"
          body << request_link(item.fetch('request'), "Inspect #{item.fetch('family')}")
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
          body << "<h3>#{h(evidence.fetch('kind'))}</h3>"
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

      def h(value) = ERB::Util.html_escape(value.to_s)
      def notice(value) = "<p class=\"notice ui\">#{h(value)}</p>"
    end
  end
end
