# frozen_string_literal: true

require 'erb'
require_relative 'investigation'
require_relative 'navigation_context'

module Thistle
  module Map
    # Renders compact saved identities only. Reader selection belongs to Core.
    class InvestigationPresenter
      MAX_OUTPUT_BYTES = 262_144
      MAX_PAGE_BYTES = 327_680

      def initialize(selection:, mount: '', navigation: nil)
        @selection, @mount = selection, mount
        @navigation = navigation || NavigationContext.new(generation: selection.generation, mount: mount, selection: selection)
      end

      def render
        body = +'<h1 class="t1">Investigation</h1>'
        body << "<p>Saved generation <code>#{h(@selection.generation)}</code>. CURRENT is not consulted; live freshness is unknown.</p>"
        body << '<p class="notice ui">Keep this focus URL to reopen the ordered selection. It contains only saved generation and fact IDs, with no access token. The server saves nothing. Opening a link still requires authorized access to this retained capture.</p>'
        body << "<p><a href=\"#{h(@selection.url(@mount))}\">Reopen this investigation</a></p>"
        body << '<p>At most 24 selections; 4096 query bytes, 24 compact identity requests (32 KiB each; 768 KiB total response allowance), 256 KiB investigation content and 320 KiB total page. Reader opening validates the saved capture separately. Resource refusal returns no partial successful collection. Source is loaded only when you follow Source.</p>'
        body << '<p>Saved facts can be partial or unavailable. Selection does not establish execution, binding, complete coverage or present application behavior. Check the saved capture before inferring absence.</p>'
        body << '<p>No facts selected. Find a fact, open Source or Links, then choose Collect in investigation.</p>' if @selection.ids.empty?
        body << '<ol>'
        @selection.ids.each do |id|
          identity = yield(id)
          body << '<li><article>'
          if identity
            body << "<h2 class=\"t2\">#{h(identity.fetch('name'))}</h2><p>#{h(identity.fetch('kind'))} · #{h(identity.fetch('evidence'))} evidence</p>"
            path = identity['path']
            body << "<p>#{h(path || 'No captured file or line')}#{identity.dig('location', 'start_line') ? ":#{h(identity.dig('location', 'start_line'))}" : ''}</p>"
            params = @selection.parameters.merge('id' => id)
            body << "<p><a href=\"#{h(evidence_url('/source', params))}\">Source for #{h(identity.fetch('name'))}</a> · " if path
            body << '<p>' unless path
            body << "<a href=\"#{h(evidence_url('/links', params))}\">Links for #{h(identity.fetch('name'))}</a></p>"
          else
            body << '<h2 class="t2">Missing selection</h2><p>This fact is absent from the selected saved generation. It remains in the focus URL; no replacement or binding was inferred.</p>'
          end
          target = @navigation.url('/investigation', selection: @selection.remove(id))
          body << "<p class=\"digest\">Fact ID <code>#{h(id)}</code></p><p><a href=\"#{h(target)}\">Remove #{h(identity ? identity.fetch('name') : id)} from investigation</a></p>"
          body << '</article></li>'
          raise Investigation::Limit, 'Investigation exceeds its rendered output budget; no partial page was returned.' if body.bytesize > MAX_OUTPUT_BYTES
        end
        body << '</ol>'
        raise Investigation::Limit, 'Investigation exceeds its rendered output budget; no partial page was returned.' if body.bytesize > MAX_OUTPUT_BYTES

        body
      end

      private

      def evidence_url(path, params)
        @navigation.url(path, 'id' => params.fetch('id'))
      end

      def h(value)
        # Saved identity text can legitimately contain controls. Display them
        # literally without refusing the collection or hiding its Remove links.
        ERB::Util.html_escape(value.to_s.gsub(/[[:cntrl:]]/) { |char| format('\\u%04x', char.ord) })
      end
    end
  end
end
