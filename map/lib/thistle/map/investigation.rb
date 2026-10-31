# frozen_string_literal: true

require 'uri'

module Thistle
  module Map
    # URL state only: no notes, persistence, source expansion or evidence analysis.
    class Investigation
      class Invalid < StandardError; end
      class Limit < StandardError; end

      MAX_SELECTIONS = 24
      MAX_QUERY_BYTES = 4096
      DIGEST = /\A[0-9a-f]{64}\z/.freeze
      attr_reader :generation, :ids

      def self.from_params(params)
        value = params.fetch('selection', '')
        raise Invalid, 'Invalid investigation selection text.' unless value.instance_of?(String)
        raise Limit, 'Investigation selection exceeds its request budget.' if value.bytesize > MAX_SELECTIONS * 65 - 1
        new(generation: params['generation'], ids: value.empty? ? [] : value.split(',', -1))
      end

      def initialize(generation:, ids: [])
        raise Invalid, 'Investigation requires an explicit saved generation.' unless generation.is_a?(String) && DIGEST.match?(generation)
        raise Invalid, 'Invalid investigation selection list.' unless ids.instance_of?(Array)
        raise Limit, 'Investigation allows at most 24 selections; none were changed.' if ids.length > MAX_SELECTIONS
        raise Invalid, 'Invalid investigation fact identifier.' unless ids.all? { |id| id.is_a?(String) && DIGEST.match?(id) }
        raise Invalid, 'Repeated investigation fact identifier.' unless ids.uniq.length == ids.length

        @generation = generation.dup.freeze
        @ids = ids.map { |id| id.dup.freeze }.freeze
        freeze
      end

      def add(id)
        return self if ids.include?(id)

        self.class.new(generation: generation, ids: ids + [id])
      end

      def remove(id)
        self.class.new(generation: generation, ids: ids.reject { |selected| selected == id })
      end

      def parameters
        { 'generation' => generation, 'selection' => ids.join(',') }
      end

      def url(mount = '')
        "#{mount}/investigation?#{self.class.query(parameters)}"
      end

      def self.query(params)
        query = URI.encode_www_form(params)
        raise Limit, 'Investigation navigation exceeds the URL budget; no selections were removed.' if query.bytesize > MAX_QUERY_BYTES

        query
      end
    end
  end
end
