# frozen_string_literal: true

require_relative 'test_helper'
require 'cgi/escape'

class MapHighlighterTest < Minitest::Test
  def test_highlighting_preserves_unicode_crlf_source_and_escapes_markup
    source = "# café & <img src=x>\r\nclass Bird\r\n  def song = '🐦'\r\nend\r\n"
    rows = Thistle::Map::Highlighter.lines(source)
    plain = rows.map { |row| CGI.unescapeHTML(row.gsub(/<[^>]+>/, '')) }.join("\n") + "\n"
    assert_equal source, plain
    refute_includes rows.join, '<img'
    assert_includes rows.join, '&#13;'
  end

  def test_unknown_language_is_escaped_without_guessing_ruby
    assert_equal 'text', Thistle::Map::Highlighter.language_for('notes.txt')
    assert_equal ['&lt;script&gt;'], Thistle::Map::Highlighter.lines('<script>', language: 'text')
  end
end

