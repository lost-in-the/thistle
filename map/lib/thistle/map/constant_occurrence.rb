# frozen_string_literal: true

require 'erb'
require 'uri'

module Thistle
  module Map
    # Displays the Reader's schema-3 occurrence assertion, never a new binding.
    # Reference pages use their bounded identities/metadata without loading Source
    # or expanding origin facts. Outgoing Links can reuse their one Source read.
    class ConstantOccurrence
      MAX_SYNTAX_BYTES = 1_024
      MAX_FILE_BYTES = 4_194_304
      WEB_SOURCE_BYTES = 262_144
      WEB_SOURCE_LINES = 10_000
      FIELDS = %w[version syntax rooted lexical_scope role location].freeze
      LOCATION_FIELDS = %w[start_byte end_byte start_line end_line].freeze
      ROLES = %w[argument predicate rescue_class value].freeze
      UNAVAILABLE = '<p class="ui">Constant site details unavailable or exceed display limits.</p>'

      def initialize(generation:, mount:, schema_version:)
        @generation, @mount, @schema_version = generation, mount, schema_version
      end

      def available?(link, origin:)
        plain?(link, Hash) && link['relation'] == 'references_constant' && !metadata(link, origin).nil?
      end

      def render(link, origin:, detail_omitted: false, source_bytes: nil, source_info: nil, verify_source: false, line_budget_unknown: false)
        return '' unless plain?(link, Hash) && link['relation'] == 'references_constant'

        data = metadata(link, origin)
        return UNAVAILABLE if detail_omitted || !data

        a, b, first, last = data.fetch('location')
        return UNAVAILABLE if source_bytes && b > source_bytes
        over_limit = first > WEB_SOURCE_LINES || (source_bytes && source_bytes > WEB_SOURCE_BYTES) || source_info&.fetch(:over_limit, false)
        if verify_source && !over_limit
          return UNAVAILABLE unless source_info && source_matches?(data, source_info)
        end
        line = first == last ? "Line #{first}" : "Lines #{first}–#{last}"
        body = +"<div class=\"constant-site\"><p class=\"ui\">Recorded constant site · #{line} · Role: #{h(data['role'])} · Bytes #{a}–#{b}. Binding unknown.</p>"
        body << "<pre class=\"check-data\" aria-label=\"Recorded constant syntax\"><code>#{h(data['syntax'])}</code></pre>"
        if over_limit || line_budget_unknown
          command = "thistle source #{origin.fetch('id')} --store STORE --generation #{@generation}"
          reason = over_limit ? 'Source exceeds web display limits.' : 'Source line count is unavailable in this summary; web display limits are unverified.'
          body << "<p class=\"ui\">#{reason} For recorded line #{first}, use <code>#{h(command)}</code>. Replace STORE with your capture store.</p>"
        else
          href = block_given? ? yield(origin.fetch('id')) : source_url(origin.fetch('id'))
          body << "<p><a href=\"#{h(href + "#L#{first}")}\">Captured Source line #{first}</a></p>"
        end
        body << '</div>'
      end

      private

      def plain?(value, type)
        Object.instance_method(:instance_of?).bind_call(value, type)
      end

      def text?(value, limit)
        plain?(value, String) && !value.empty? && value.bytesize <= limit &&
          [Encoding::UTF_8, Encoding::US_ASCII].include?(value.encoding) && value.valid_encoding?
      end

      def tuple?(value)
        return false unless plain?(value, Array) && value.length == 4 &&
          value.all? { |n| plain?(n, Integer) && n >= 0 && n <= MAX_FILE_BYTES + 1 }

        a, b, first, last = value
        a < b && b <= MAX_FILE_BYTES && first > 0 && first <= last && last <= b + 1
      end

      def metadata(link, origin)
        return nil unless plain?(@schema_version, Integer) && @schema_version == 3 && plain?(origin, Hash) && origin['evidence'] == 'static' &&
          link['resolution'] == 'unresolved' && text?(origin['path'], 4_096) &&
          text?(origin['id'], 64) && /\A[0-9a-f]{64}\z/.match?(origin['id'])
        attributes = link['attributes']
        return nil if plain?(attributes, Hash) && attributes.key?('thistle_call')
        data = plain?(attributes, Hash) ? attributes['thistle_constant'] : nil
        return nil unless plain?(data, Hash) && data.size == FIELDS.length && FIELDS.all? { |key| data.key?(key) } &&
          plain?(data['version'], Integer) && data['version'] == 1 && text?(data['syntax'], MAX_SYNTAX_BYTES) &&
          plain?(data['role'], String) && ROLES.include?(data['role']) && tuple?(data['location']) &&
          (plain?(data['rooted'], TrueClass) || plain?(data['rooted'], FalseClass)) &&
          (plain?(data['lexical_scope'], NilClass) || text?(data['lexical_scope'], 4_096)) && text?(link['target'], 256)
        a, b, first, last = data['location']
        return nil unless b - a == data['syntax'].bytesize && data['rooted'] == data['syntax'].start_with?('::') &&
          data['rooted'] == link['target'].start_with?('::')
        span = origin['location']
        return nil unless plain?(span, Hash) && LOCATION_FIELDS.all? { |key| span.key?(key) }
        owner = span.values_at(*LOCATION_FIELDS)
        return nil unless tuple?(owner) && a >= owner[0] && b <= owner[1] && first >= owner[2] && last <= owner[3]

        data
      end

      def source_matches?(data, info)
        a, b, first, last = data['location']
        return false unless info[:content].byteslice(a, b - a) == data['syntax'] && first <= info[:rendered_lines]

        [[a, first], [b, last]].all? do |byte, line|
          line == (info[:offsets].bsearch_index { |offset| offset >= byte } || info[:offsets].length) + 1
        end
      end

      def source_url(id)
        "#{@mount}/source?#{URI.encode_www_form('generation' => @generation, 'id' => id)}"
      end

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end
    end
  end
end
