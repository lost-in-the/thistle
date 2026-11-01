# frozen_string_literal: true

require 'digest'
require_relative 'source_comprehension_presenter'

module Thistle
  module Map
    # Display admission only; Core has already selected contributions. Reserve
    # pinned manifest bytes BEFORE Source; lines are checked on bounded content.
    class SourceComprehensionSources
      attr_reader :sources, :states

      def initialize(reader:, generation:)
        @reader, @generation = reader, generation
        @sources, @states = {}, {}
      end

      def call(contributions)
        raise Thistle::InvalidSnapshot, 'Comprehension Reader changed generation' unless @reader.generation == @generation
        raise Thistle::InvalidSnapshot, 'Too many source contributions' unless contributions.is_a?(Array) && contributions.length <= 16
        files = @reader.manifest.fetch('files')
        by_path = {}
        paths = contributions.map { |row| row.fetch('fact')['path'] }.compact.uniq
        # One manifest pass over already pinned metadata, not a fact inventory or
        # eager source read. Retain only this page's selected file identities.
        files.each do |file|
          next unless paths.include?(file.fetch('path'))
          raise Thistle::InvalidSnapshot, 'Duplicate source manifest path' if by_path.key?(file['path'])
          by_path[file['path']] = file
        end
        bytes = lines = 0
        visited = {}
        contributions.each do |row|
          fact = row.fetch('fact')
          id, path = fact.values_at('id', 'path')
          if path.nil? || fact['location'].nil?
            @states[id] = { 'status' => 'unavailable', 'reason' => 'No physical source span was captured.' }
            next
          end
          if visited.key?(path)
            previous = visited.fetch(path)
            @states[id] = previous['status'] == 'admitted' ? { 'status' => 'shared_file', 'reason' => 'Captured file already shown on this page.' } : previous
            next
          end
          file = by_path[path]
          raise Thistle::InvalidSnapshot, 'Selected source is absent from pinned manifest' unless file
          size = file.fetch('bytes')
          sha = file.fetch('sha256')
          unless size.is_a?(Integer) && size >= 0 && sha.is_a?(String) && sha.match?(/\A[0-9a-f]{64}\z/)
            raise Thistle::InvalidSnapshot, 'Invalid source manifest admission metadata'
          end
          if bytes >= SourceComprehensionPresenter::MAX_SOURCE_BYTES || bytes + size > SourceComprehensionPresenter::MAX_SOURCE_BYTES || lines >= SourceComprehensionPresenter::MAX_LINES
            @states[id] = visited[path] = { 'status' => 'not_admitted', 'reason' => 'Remaining source byte or display-line allowance is spent; exact Source remains available.' }
            next
          end
          bytes += size
          begin
            source = @reader.source(id)
            unless source.is_a?(Hash) && source['content'].is_a?(String) && source['generation'] == @generation && source.dig('fact', 'id') == id && source.dig('fact', 'path') == path &&
                source.dig('fact', 'location') == fact['location'] && source['sha256'] == sha &&
                source.fetch('content').bytesize == size && Digest::SHA256.hexdigest(source['content']) == sha
              raise Thistle::InvalidSnapshot, 'Captured source disagrees with admitted file identity'
            end
            # Manifests have no line count. Validate the entire bounded response
            # before any highlighter/HTML work; never render a successful prefix.
            content = source.fetch('content')
            display_lines = content.count("\n") + (content.end_with?("\n") ? 0 : 1)
            if lines + display_lines > SourceComprehensionPresenter::MAX_LINES
              @states[id] = visited[path] = { 'status' => 'not_admitted', 'reason' => 'Whole captured file exceeds the remaining 2000 display lines; exact Source remains available. Byte reservation retained.' }
              next
            end
            lines += display_lines
            @sources[id] = source
            @states[id] = visited[path] = { 'status' => 'admitted' }
          rescue Thistle::LimitExceeded
            @states[id] = visited[path] = { 'status' => 'not_admitted', 'reason' => 'Reader source budget refused this reserved file; no retry.' }
          end
        end
        self
      end
    end
  end
end
