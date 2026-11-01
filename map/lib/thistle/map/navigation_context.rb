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
      JOB_MAIL_FAMILIES = %w[overview registrations declarations policy handoff template_references].freeze
      MAX_FIELDS = 9
      MAX_CURSOR_BYTES = 512
      NEIGHBORHOOD_ROUTE = %r{\A/model-neighborhood/(edges|columns|database|candidates)/(incoming|outgoing)/(all|association|reference)\z}.freeze
      MODEL_ROUTE = %r{\A/models/(?<model>[0-9a-f]{64})(?:/from/(?<family>contributions|methods)/(?<return_cursor>first|(?:[0-9a-f]{2}){1,512}))?(?:/at/(?<file>[0-9a-f]{64})/(?<line>[1-9][0-9]{0,4}))?(?<page>/.*)\z}.freeze
      MODEL_PAGES = %w[/source /links /check /comprehension/contributions /comprehension/methods /brief/columns /brief/associations /brief/registry_candidates /model-callbacks].freeze
      attr_reader :search_omitted, :model_id, :source_position, :reading_family, :reading_cursor

      def initialize(generation:, mount: '', params: {}, selection: nil, model_id: nil, source_position: nil, reading_family: 'contributions', reading_cursor: nil)
        raise Investigation::Invalid, 'Invalid model reading identity.' if model_id && !Investigation::DIGEST.match?(model_id)
        @model_id = model_id
        @source_position = source_position
        validate_position!(source_position) if source_position
        @reading_family, @reading_cursor = reading_family, reading_cursor
        raise Investigation::Invalid, 'Invalid model reading family.' unless COMPREHENSION_FAMILIES.include?(reading_family)
        self.class.validate_cursor!(reading_cursor, generation: generation, scope: ['source_comprehension', model_id, reading_family]) if reading_cursor
        @generation, @mount, @selection = generation, mount, selection
        @current = params.slice('id', 'file', 'path', 'direction', 'page', 'cursor', 'candidate', 'action')
        @search = params.slice(*SEARCH_FIELDS)
        @search_query = URI.encode_www_form(@search).freeze
        initial_state = state(selection)
        @state = URI.encode_www_form(initial_state).freeze
        @state_fields = initial_state.size
        @search_omitted = false
      end

      def url(path, extra = {}, selection: @selection, source_position: @source_position, **destination)
        validate_position!(source_position) if source_position
        if path.start_with?('/model-neighborhood/') && !NEIGHBORHOOD_ROUTE.match?(path)
          raise Investigation::Invalid, 'Unknown model neighborhood route.'
        end
        if path.start_with?('/job-mail/') && !JOB_MAIL_FAMILIES.include?(path.delete_prefix('/job-mail/'))
          raise Investigation::Invalid, 'Unknown job/mail route.'
        end
        if path.start_with?('/comprehension/') && !%w[/comprehension/contributions /comprehension/methods].include?(path)
          raise Investigation::Invalid, 'Unknown source comprehension route.'
        end
        if path.start_with?('/passage/') && !%w[/passage/sequence /passage/export].include?(path)
          raise Investigation::Invalid, 'Unknown passage route.'
        end
        extra = extra.merge(destination) unless destination.empty?
        controls = @current.merge(extra)
        if extra.key?('id') && extra['id'] != @current['id']
          %w[direction page cursor candidate action].each { |key| controls.delete(key) unless extra.key?(key) }
        end
        controls.delete('cursor') if extra.key?('action') && extra['action'] != @current['action'] && !extra.key?('cursor')
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
                      when '/route-actions' then controls.slice('id', 'cursor')
                      when '/passage/sequence', '/passage/export' then controls.slice('id', 'action', 'cursor')
                       when NEIGHBORHOOD_ROUTE
                         fields = path.include?('/candidates/') ? %w[id candidate cursor] : %w[id cursor]
                         controls.slice(*fields)
                      when %r{\A/brief/(?:columns|associations|registry_candidates)\z} then controls.slice('id', 'cursor')
                      when '/comprehension/contributions', '/comprehension/methods' then controls.slice('id', 'cursor')
                      when %r{\A/job-mail/(?:overview|registrations|declarations|policy|handoff|template_references)\z} then controls.slice('id', 'cursor')
                      when '/references/incoming', '/references/outgoing' then controls.slice('id', 'cursor', 'candidate')
                      when '/check', '/model-callbacks' then controls.slice('id')
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

        prefix = @model_id && self.class.model_page?(path) ? "/models/#{@model_id}" : ''
        family, cursor = @reading_family, @reading_cursor
        if COMPREHENSION_FAMILIES.any? { |name| path == "/comprehension/#{name}" } && destination['id'] == @model_id
          family, cursor = path.delete_prefix('/comprehension/'), destination['cursor']
        end
        if !prefix.empty? && (family != 'contributions' || cursor)
          token = cursor ? cursor.unpack1('H*') : 'first'
          prefix += "/from/#{family}/#{token}"
        end
        prefix += "/at/#{source_position[0]}/#{source_position[1]}" if !prefix.empty? && source_position
        "#{@mount}#{prefix}#{path}?#{query}"
      end

      def reading_url
        url("/comprehension/#{@reading_family}", 'id' => @model_id, 'cursor' => @reading_cursor)
      end

      def self.model_page?(path)
        MODEL_PAGES.include?(path) || NEIGHBORHOOD_ROUTE.match?(path) || %w[/references/incoming /references/outgoing].include?(path)
      end

      # Bound a repeated row href without constructing URLs or consulting saved
      # facts. Row destinations need at most 96 encoded control bytes; next-page
      # cursors are covered by the presenter's separate non-row reserve.
      def reference_url_bytes
        query = [Investigation::MAX_QUERY_BYTES, @state.bytesize + @search_query.bytesize + 96].min
        context = @model_id ? 8 + 64 : 0
        context += 7 + @reading_family.bytesize + 1 + (@reading_cursor ? @reading_cursor.bytesize * 2 : 5) if @model_id && (@reading_family != 'contributions' || @reading_cursor)
        context += 4 + 64 + 1 + 5 if @model_id && @source_position
        @mount.bytesize * 6 + context + 32 + query + MAX_FIELDS * 4
      end

      # Route names carry family/direction so continuation still fits nine fields.
      def self.continuation(path, params)
        if path == '/model-callbacks'
          unless (params.keys - (%w[generation id selection] + SEARCH_FIELDS)).empty? &&
              %w[generation id].all? { |key| Investigation::DIGEST.match?(params[key].to_s) }
            raise Investigation::Invalid, 'Registered callbacks require an exact saved generation and registry.'
          end
          return { model_callbacks: true }
        end
        return nil unless path == '/route-actions' || path.start_with?('/brief/', '/references/', '/comprehension/', '/job-mail/', '/passage/', '/model-neighborhood/')
        if path.start_with?('/model-neighborhood/')
          match = NEIGHBORHOOD_ROUTE.match(path)
          unless match && (params.keys - (%w[generation id selection cursor candidate] + SEARCH_FIELDS)).empty? &&
              %w[generation id].all? { |key| Investigation::DIGEST.match?(params[key].to_s) }
            raise Investigation::Invalid, 'Model neighborhood requires exact saved generation, model and destination fields.'
          end
          family, direction, type = match.captures
          if %w[columns database].include?(family) && [direction, type] != %w[outgoing all]
            raise Investigation::Invalid, 'Schema families require outgoing/all scope.'
          end
          candidate = params['candidate']
          if (family == 'candidates') != !candidate.nil? ||
              (family == 'candidates' && (direction != 'outgoing' || !/\A[ar]:(?:0|[1-9][0-9]{0,5})\z/.match?(candidate) ||
                type == 'reference' && candidate.start_with?('a:')))
            raise Investigation::Invalid, 'Invalid model neighborhood candidate scope.'
          end
          scope = ['model_neighborhood', params['id'], family, direction, type, candidate]
          validate_cursor!(params['cursor'], generation: params['generation'], scope: scope) if params.key?('cursor')
          return { neighborhood: { family: family, direction: direction, type: type, candidate: candidate } }
        end
        if path.start_with?('/passage/')
          family = path.delete_prefix('/passage/')
          unless %w[sequence export].include?(family) && (params.keys - (%w[generation id action selection cursor] + SEARCH_FIELDS)).empty? &&
              %w[generation id].all? { |key| Investigation::DIGEST.match?(params[key].to_s) } &&
              (!params.key?('action') || Investigation::DIGEST.match?(params['action'].to_s))
            raise Investigation::Invalid, 'Passage requires exact saved generation, route, optional action and destination fields.'
          end
          validate_cursor!(params['cursor'], generation: params['generation'], scope: ['passage',params['id'],params['action'],family]) if params.key?('cursor')
          return { passage: family }
        end
        if path == '/route-actions'
          unless (params.keys - (%w[generation id selection cursor] + SEARCH_FIELDS)).empty? &&
              Investigation::DIGEST.match?(params['generation'].to_s) && Investigation::DIGEST.match?(params['id'].to_s)
            raise Investigation::Invalid, 'Route actions requires a saved generation, route ID and strict destination fields.'
          end
          validate_cursor!(params['cursor'], generation: params['generation'], scope: ['route_actions',params['id']]) if params.key?('cursor')
          return { route_actions: true }
        end
        if path.start_with?('/job-mail/')
          family = path.delete_prefix('/job-mail/')
          unless JOB_MAIL_FAMILIES.include?(family) && (params.keys - (%w[generation id selection cursor] + SEARCH_FIELDS)).empty?
            raise Investigation::Invalid, 'Unknown job/mail scope or query field.'
          end
          unless Investigation::DIGEST.match?(params['generation'].to_s) && Investigation::DIGEST.match?(params['id'].to_s)
            raise Investigation::Invalid, 'Job/mail requires a saved generation and fact ID.'
          end
          validate_cursor!(params['cursor'], generation: params['generation'], scope: ['job_mail', params['id'], family]) if params.key?('cursor')
          return { job_mail: family }
        end
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

      def validate_position!(position)
        unless position.is_a?(Array) && position.length == 2 && Investigation::DIGEST.match?(position[0].to_s) &&
            position[1].is_a?(Integer) && position[1].between?(1, 10_000)
          raise Investigation::Invalid, 'Invalid model reading source position.'
        end
      end

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
