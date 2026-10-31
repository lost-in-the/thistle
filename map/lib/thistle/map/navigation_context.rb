# frozen_string_literal: true

require 'uri'
require 'json'
require 'digest'
require_relative 'investigation'

module Thistle
  module Map
    # Request-local URL policy. Search and collection state are encoded once;
    # destinations supply only their own identity/controls, never raw forwarding.
    class NavigationContext
      SEARCH_FIELDS = %w[q domain kind prefix].freeze
      FAMILIES = %w[columns associations registry_candidates].freeze
      COMPREHENSION_FAMILIES = %w[contributions methods].freeze
      MAX_FIELDS = 9
      MAX_CURSOR_BYTES = 512
      attr_reader :search_omitted

      def initialize(generation:, mount: '', params: {}, selection: nil)
        @generation, @mount, @selection = generation, mount, selection
        @current = params.slice('id', 'file', 'path', 'direction', 'page', 'cursor', 'candidate')
        @search = params.slice(*SEARCH_FIELDS)
        @search_query = URI.encode_www_form(@search).freeze
        initial_state = state(selection)
        @state = URI.encode_www_form(initial_state).freeze
        @state_fields = initial_state.size
        @search_omitted = false
      end

      def url(path, extra = {}, selection: @selection, **destination)
        if path.start_with?('/comprehension/') && !%w[/comprehension/contributions /comprehension/methods].include?(path)
          raise Investigation::Invalid, 'Unknown source comprehension route.'
        end
        extra = extra.merge(destination) unless destination.empty?
        controls = @current.merge(extra)
        if extra.key?('id') && extra['id'] != @current['id']
          %w[direction page cursor candidate].each { |key| controls.delete(key) unless extra.key?(key) }
        end
        destination = case path
                      when '/source'
                        if extra.key?('file') || extra.key?('path')
                          controls.delete('id')
                        elsif extra['id']
                          controls.delete('file'); controls.delete('path')
                        end
                        if controls['id']
                          controls.slice('id')
                        else
                          file = controls['file'] || (controls['path'] && Digest::SHA256.hexdigest(controls['path']))
                          file ? { 'file' => file } : {}
                        end
                      when '/links' then controls.slice('id', 'direction', 'page')
                      when %r{\A/brief/(?:columns|associations|registry_candidates)\z} then controls.slice('id', 'cursor')
                      when '/comprehension/contributions', '/comprehension/methods' then controls.slice('id', 'cursor')
                      when '/references/incoming', '/references/outgoing' then controls.slice('id', 'cursor', 'candidate')
                      when '/check' then controls.slice('id')
                      else {}
                      end.compact
        # A new anchor/direction starts at the first page unless explicitly set.
        destination.delete('page') if (extra.key?('id') || extra.key?('direction')) && !extra.key?('page')
        destination.delete('cursor') if extra.key?('id') && !extra.key?('cursor')
        destination.delete('candidate') if path == '/references/incoming'
        if selection.equal?(@selection)
          base, state_fields = @state, @state_fields
        else
          changed_state = state(selection)
          base, state_fields = URI.encode_www_form(changed_state), changed_state.size
        end
        mandatory = join(base, URI.encode_www_form(destination))
        count = state_fields + destination.size
        query = join(mandatory, @search_query)
        if query.bytesize > Investigation::MAX_QUERY_BYTES || count + @search.size > MAX_FIELDS
          @search_omitted = true unless @search.empty?
          query = mandatory
        end
        raise Investigation::Limit, 'Navigation exceeds the URL budget; no selections were removed.' if query.bytesize > Investigation::MAX_QUERY_BYTES || count > MAX_FIELDS

        "#{@mount}#{path}?#{query}"
      end

      # Bound a repeated row href without constructing URLs or consulting saved
      # facts. Row destinations need at most 96 encoded control bytes; next-page
      # cursors are covered by the presenter's separate non-row reserve.
      def reference_url_bytes
        query = [Investigation::MAX_QUERY_BYTES, @state.bytesize + @search_query.bytesize + 96].min
        @mount.bytesize * 6 + 32 + query + MAX_FIELDS * 4
      end

      # Route names carry family/direction so continuation still fits nine fields.
      def self.continuation(path, params)
        return nil unless path.start_with?('/brief/', '/references/', '/comprehension/')
        if path.start_with?('/comprehension/')
          family = path.delete_prefix('/comprehension/')
          unless COMPREHENSION_FAMILIES.include?(family) && (params.keys - (%w[generation id selection cursor] + SEARCH_FIELDS)).empty?
            raise Investigation::Invalid, 'Unknown source comprehension scope or query field.'
          end
          unless Investigation::DIGEST.match?(params['generation'].to_s) && Investigation::DIGEST.match?(params['id'].to_s)
            raise Investigation::Invalid, 'Source comprehension requires a saved generation and fact ID.'
          end
          validate_cursor!(params['cursor'], generation: params['generation'], scope: ['source_comprehension', params['id'], family]) if params.key?('cursor')
          return { comprehension: family }
        end
        family = path.delete_prefix('/brief/') if path.start_with?('/brief/')
        direction = path.delete_prefix('/references/') unless family
        valid = family ? FAMILIES.include?(family) : %w[incoming outgoing].include?(direction)
        raise Investigation::Invalid, 'Unknown continuation scope.' unless valid
        allowed = %w[generation id selection cursor] + SEARCH_FIELDS
        allowed << 'candidate' if direction == 'outgoing'
        raise Investigation::Invalid, 'Unknown continuation query field.' unless (params.keys - allowed).empty?
        unless Investigation::DIGEST.match?(params['generation'].to_s) && Investigation::DIGEST.match?(params['id'].to_s)
          raise Investigation::Invalid, 'Continuation requires a saved generation and fact ID.'
        end
        candidate = params['candidate']
        if candidate && !/\A(?:0|[1-9][0-9]{0,6})\z/.match?(candidate)
          raise Investigation::Invalid, 'Invalid candidate relationship position.'
        end
        candidate = candidate.to_i if candidate
        scope = family ? ['model_brief', params['id'], family] : ['references', params['id'], direction == 'incoming', candidate]
        validate_cursor!(params['cursor'], generation: params['generation'], scope: scope) if params.key?('cursor')
        { family: family, direction: direction, candidate: candidate }
      end

      def self.validate_cursor!(cursor, generation:, scope:)
        raise Investigation::Invalid, 'Invalid saved continuation cursor.' unless cursor.instance_of?(String) && cursor.bytesize <= MAX_CURSOR_BYTES
        value = JSON.parse(cursor, max_nesting: 4)
        valid = value.instance_of?(Array) && value.length == 5 && value[0] == 'recorded-v1' && value[1] == generation &&
          value[2] == Digest::SHA256.hexdigest(JSON.generate(scope)) &&
          value.last(2).all? { |n| n.instance_of?(Integer) && n.between?(0, 0xffff_ffff) }
        raise Investigation::Invalid, 'Continuation belongs to another generation or evidence scope.' unless valid
      rescue JSON::ParserError, JSON::NestingError
        raise Investigation::Invalid, 'Malformed saved continuation cursor.'
      end

      private

      def state(selection)
        if selection && (!selection.instance_of?(Investigation) || selection.generation != @generation)
          raise ArgumentError, 'Navigation requires normalized selection from the same generation'
        end
        selection && !selection.ids.empty? ? selection.parameters : { 'generation' => @generation }
      end

      def join(left, right)
        left.empty? ? right : right.empty? ? left : "#{left}&#{right}"
      end
    end
  end
end
