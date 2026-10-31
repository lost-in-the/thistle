# frozen_string_literal: true

require 'json'
require 'uri'
require 'cgi'

module MapAnswers
  module_function

  def verify(kind, body, oracle)
    saved, origin = oracle.values_at('saved', 'origin_id')
    raise 'Map generation absent' unless body.include?(saved)
    case kind
    when 'find'
      results = body.scan(/<a\b([^>]*\bdata-result-link\b[^>]*)>/).flatten
      present = results.any? do |attrs|
        href = attrs[/href="([^"]+)"/, 1]
        next false unless href
        query = URI.decode_www_form(URI.parse(CGI.unescapeHTML(href)).query.to_s).to_h
        query['id'] == origin && query['generation'] == saved
      end
      raise 'Known Find identity absent' unless present
    when 'check'
      checks = body.scan(/<pre class="check-data">(.*?)<\/pre>/m).flatten.map { |text| JSON.parse(CGI.unescapeHTML(text)) }
      raise 'Map integrity not verified' unless checks.any? { |row| row['generation'] == saved && row['integrity'] == 'verified' }
    when 'source'
      raise 'Pinned Source identity/hash/lines absent' unless body.include?(origin) && body.include?('Inspection#sites') && body.include?(oracle.fetch('source_sha256')) &&
        oracle.fetch('site_lines').all? { |line| body.include?("id=\"L#{line}\"") }
    when 'links', 'incoming'
      hrefs = body.scan(/href="([^"]+)"/).flatten.map { |href| URI.parse(CGI.unescapeHTML(href)) }
      valid_sites = oracle.fetch('site_lines').all? do |line|
        hrefs.any? do |href|
          query = URI.decode_www_form(href.query.to_s).to_h
          href.fragment == "L#{line}" && query['id'] == origin && query['generation'] == saved
        end
      end
      raise 'F05 HTTP identities/count differ' unless body.scan('class="constant-site"').length == oracle.fetch('site_count') && valid_sites
      %w[argument value].each { |role| raise 'F05 role absent' unless body.include?("Role: #{role}") }
    else
      raise 'Unknown Map answer family'
    end
    true
  end
end
