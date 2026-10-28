# frozen_string_literal: true

# Adapted from Woods Map Highlighter, copyright (c) 2026 Leah Armstrong.
# Original MIT notice: LICENSE.woods-map.txt. Exact provenance: docs/REUSE.md.
require 'rouge'
require 'erb'

module Thistle
  module Map
    # Lossless syntax colours; only escaped source and fixed CSS classes become HTML.
    # References remain in the separate Links view until Thistle verifies spans.
    module Highlighter
      LEXERS = {
        'ruby' => Rouge::Lexers::Ruby, 'erb' => Rouge::Lexers::ERB,
        'haml' => Rouge::Lexers::Haml, 'slim' => Rouge::Lexers::Slim,
        'yaml' => Rouge::Lexers::YAML, 'js' => Rouge::Lexers::Javascript,
        'sql' => Rouge::Lexers::SQL
      }.freeze
      CLASSES = [
        ['Comment', 'cm'], ['Keyword', 'k'], ['Name.Function', 'fn'], ['Name.Class', 'const'],
        ['Name.Constant', 'const'], ['Name.Namespace', 'const'], ['Name.Variable', 'var'],
        ['Name.Decorator', 'fn'], ['Name.Builtin', 'fn'], ['Literal.String', 'str'],
        ['Literal.Number', 'const'], ['Operator', 'op'], ['Punctuation', 'op']
      ].freeze
      EXTENSIONS = {
        '.rb' => 'ruby', '.erb' => 'erb', '.haml' => 'haml', '.slim' => 'slim',
        '.yml' => 'yaml', '.yaml' => 'yaml', '.js' => 'js', '.sql' => 'sql'
      }.freeze

      module_function

      def lines(source, language: 'ruby')
        token_lines(source, language).map do |tokens|
          tokens.map do |css, value|
            escaped = ERB::Util.html_escape(value).gsub("\r", '&#13;')
            css ? "<span class=\"#{css}\">#{escaped}</span>" : escaped
          end.join
        end
      end

      def token_lines(source, language)
        out = [[]]
        syntax_tokens(source, language).each do |css, value|
          value.split("\n", -1).each_with_index do |part, index|
            out << [] if index.positive?
            out.last << [css, part] unless part.empty?
          end
        end
        out.pop if out.size > 1 && out.last.empty? && source.end_with?("\n")
        out
      end

      def syntax_tokens(source, language)
        lexer = LEXERS[language.to_s]
        return [[nil, source]] unless lexer

        tokens = lexer.lex(source).map { |token, value| [class_for(token), value] }
        tokens.map(&:last).join == source ? tokens : [[nil, source]]
      rescue StandardError
        # A lexer failure removes colour, never source or escaping.
        [[nil, source]]
      end

      def class_for(token)
        name = token.qualname
        CLASSES.find { |prefix, _| name == prefix || name.start_with?("#{prefix}.") }&.last
      end

      def language_for(file_path)
        EXTENSIONS.fetch(File.extname(file_path.to_s), 'text')
      end
    end
  end
end
