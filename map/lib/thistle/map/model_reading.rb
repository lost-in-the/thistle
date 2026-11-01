# frozen_string_literal: true

require 'json'
require_relative 'navigation_context'
require_relative 'source_comprehension_sources'

module Thistle
  module Map
    # Request-local composition of existing typed answers, never source analysis.
    class ModelReading
      attr_reader :projection, :methods, :admission

      def initialize(reader:, id:, generation:, family: 'contributions', cursor: nil)
        @reader, @id, @generation = reader, id, generation
        @projection = query(family, cursor)
        # The opening outline is useful without eager schema/callback/reference
        # work. Continuations query only their selected family, not both again.
        @methods = family == 'methods' ? @projection : (cursor.nil? ? query('methods', nil) : nil)
        @admission = SourceComprehensionSources.new(reader: reader, generation: generation).call(@projection.fetch('contributions'))
      end

      private

      def query(family, cursor)
        answer = @reader.source_comprehension(@id, family: family, cursor: cursor, limit: 8, max_bytes: 32768)
        unless @reader.generation == @generation && answer['version'] == 1 && answer['generation'] == @generation &&
            answer['family'] == family && answer['composition'] == 'identified_contributions' &&
            answer['source_runtime_coherence'] == 'unknown' && answer.dig('model', 'id') == @id &&
            answer.dig('model', 'kind') == 'rails_model' && answer['contributions'].is_a?(Array) &&
            answer['contributions'].length <= 8 && answer.fetch('rows', []).is_a?(Array) &&
            answer.fetch('rows', []).length <= 8 && JSON.generate(answer).bytesize <= 32768
          raise Thistle::InvalidSnapshot, 'Model reading projection mismatch'
        end
        answer.fetch('rows', []).each do |row|
          unless row.is_a?(Hash) && SourceComprehensionPresenter::ROW_LABELS.key?(row['status']) &&
              row['returned'].is_a?(Integer) && row['returned'].between?(0, 8)
            raise Thistle::InvalidSnapshot, 'Model reading outline mismatch'
          end
        end
        answer.fetch('contributions').each do |row|
          fact = row.fetch('fact')
          unless Investigation::DIGEST.match?(fact.fetch('id')) &&
              %w[source callers].all? { |key| row.fetch(key).values_at('id', 'generation') == [fact['id'], @generation] } &&
              row.dig('source', 'operation') == 'source' && row.dig('callers', 'operation') == 'references' &&
              row.dig('callers', 'direction') == 'incoming' && SourceComprehensionPresenter::LABELS.key?(row.fetch('status'))
            raise Thistle::InvalidSnapshot, 'Model reading witness mismatch'
          end
        end
        if (next_page = answer['continuation'])
          unless next_page.values_at('operation', 'generation', 'id', 'family') == ['source_comprehension', @generation, @id, family]
            raise Thistle::InvalidSnapshot, 'Model reading continuation mismatch'
          end
          NavigationContext.validate_cursor!(next_page.fetch('cursor'), generation: @generation, scope: ['source_comprehension', @id, family])
          raise Thistle::InvalidSnapshot, 'Model reading continuation stalled' if next_page['cursor'] == cursor
        end
        answer
      end
    end
  end
end
