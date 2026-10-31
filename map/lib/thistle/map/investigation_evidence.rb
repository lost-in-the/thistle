# frozen_string_literal: true

require 'json'
require_relative 'investigation'

module Thistle
  module Map
    # One indexed compact-identity request per selection, never Reader#fact or
    # relationship/source queries. The Reader owns selection and its open cost.
    class InvestigationEvidence
      MAX_RESPONSE_BYTES = 32_768
      MAX_TOTAL_RESPONSE_BYTES = Investigation::MAX_SELECTIONS * MAX_RESPONSE_BYTES
      FIELDS = %w[evidence id kind location name path].freeze
      POSITIONS = %w[end_byte end_line start_byte start_line].freeze

      def initialize(reader:, selection:)
        @reader, @selection = reader, selection
        @calls = 0
        @reserved_bytes = 0
        raise Thistle::InvalidSnapshot, 'Investigation Reader generation mismatch' unless reader.generation == selection.generation
        # An empty focus needs no evidence lookup. Keep it usable from ordinary
        # Find navigation; nonempty collections still require the exact seam.
        unless selection.ids.empty? || reader.respond_to?(:fact_identity)
          raise Investigation::Limit, 'Compact saved fact lookup is unavailable with this Reader. No evidence was substituted.'
        end
      end

      def fetch(id)
        unless @calls < Investigation::MAX_SELECTIONS && @selection.ids[@calls] == id &&
            @reserved_bytes + MAX_RESPONSE_BYTES <= MAX_TOTAL_RESPONSE_BYTES
          raise Investigation::Limit, 'Investigation exhausted its total identity request budget.'
        end
        # Reserve the maximum response before crossing the Reader boundary,
        # including failed/missing lookups. Never refund and retry a failed row.
        @calls += 1
        @reserved_bytes += MAX_RESPONSE_BYTES
        result = @reader.fact_identity(id)
        unless result.instance_of?(Hash) && result.keys.sort == %w[fact generation] && result['generation'] == @selection.generation
          raise Thistle::InvalidSnapshot, 'Investigation identity generation mismatch'
        end
        fact = result['fact']
        validate!(fact, id)
        raise Investigation::Limit, 'Investigation identity exceeds its encoded response budget.' if JSON.generate(result).bytesize > MAX_RESPONSE_BYTES

        fact
      rescue Thistle::NotFound
        nil
      end

      private

      def validate!(fact, id)
        valid = fact.instance_of?(Hash) && fact.keys.sort == FIELDS && fact['id'] == id &&
          %w[id kind name evidence].all? { |field| text?(fact[field]) } &&
          (fact['path'].nil? || text?(fact['path']))
        location = fact['location'] if valid
        valid &&= location.nil? || (location.instance_of?(Hash) && location.keys.sort == POSITIONS &&
          POSITIONS.all? { |key| location[key].instance_of?(Integer) && location[key] >= 0 && location[key] <= 4_194_305 } &&
          location['start_line'].positive? && location['start_line'] <= location['end_line'] && location['start_byte'] <= location['end_byte'])
        raise Thistle::InvalidSnapshot, 'Invalid compact investigation identity' unless valid
      end

      def text?(value)
        value.instance_of?(String) && value.valid_encoding? && value.bytesize <= MAX_RESPONSE_BYTES
      end
    end
  end
end
