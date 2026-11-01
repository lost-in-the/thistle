# frozen_string_literal: true

# AUTHORED UNRUN: App execution belongs to Root's finite runtime admission,
# even though this focused boundary probe uses pure Reader/highlighter doubles.
if $PROGRAM_NAME == __FILE__
  require 'cgi'
  require 'erb'
  require_relative '../../lib/thistle/errors'
  require_relative '../../test/fixtures/los144_route_actions/source_answers'
  $LOADED_FEATURES << File.expand_path('../lib/thistle/map/highlighter.rb', __dir__)
  module Thistle
    module Map
      module Highlighter
        def self.lines(content, **) = content.lines.map { |line| ERB::Util.html_escape(line.chomp) }
        def self.language_for(*) = 'ruby'
      end
    end
  end
  require_relative '../lib/thistle/map/app'
  class RouteActionsMockReader
    attr_reader :generation, :manifest, :calls, :closed
    def initialize(mode)
      @generation, @mode, @calls = RouteActionsAnswers::GENERATION, mode, []
      @manifest = {'coverage'=>[],'files'=>[],'schema_version'=>3}
    end
    def route_actions(id, **controls)
      @calls << [:route_actions,id,controls]
      raise Thistle::InvalidInput, 'Unknown native operation' if @mode == :unsupported_native
      answer = RouteActionsAnswers.page
      answer['root']['id'] = RouteActionsAnswers::OTHER if @mode == :forged
      answer
    end
    def fact_identity(id)
      @calls << [:fact_identity,id]
      fact = RouteActionsAnswers.identity(id,'route')
      {'generation'=>generation,'fact'=>fact.reject { |key,_| %w[generation span].include?(key) }.merge('location'=>nil)}
    end
    def source(id)
      @calls << [:source,id]
      if id == RouteActionsAnswers::ROUTE
        error = Thistle::Error.new('No saved route location')
        error.instance_variable_set(:@native_code, 'source_unavailable')
        raise error
      end
      fact = RouteActionsAnswers.identity(id)
      {'generation'=>generation,'fact'=>fact.reject { |key,_| %w[generation span].include?(key) }.merge('location'=>fact['span']),
        'content'=>"class OrdersController\n  def index\n    :saved_a\n  end\nend\n",'sha256'=>'e'*64}
    end
    def fact(*) = raise('No expanded fact fallback permitted')
    def close = @closed = true
  end
  a = RouteActionsAnswers
  probes = []
  mode = :normal
  app = Thistle::Map::App.new(store: 'never-opened', reader_factory: ->(*) { reader=RouteActionsMockReader.new(mode); probes << reader; reader })
  env = {'REQUEST_METHOD'=>'GET','HTTP_HOST'=>'localhost','REMOTE_ADDR'=>'127.0.0.1','rack.url_scheme'=>'http','SCRIPT_NAME'=>'/map'}
  fields = {'generation'=>a::GENERATION,'id'=>a::ROUTE,'selection'=>[a::ROUTE,a::METHOD].join(','),'q'=>'orders','domain'=>'metadata','kind'=>'route','prefix'=>'app'}
  request = ->(path, params) { app.call(env.merge('PATH_INFO'=>path,'QUERY_STRING'=>URI.encode_www_form(params))) }
  status, _, body = request.call('/route-actions',fields)
  html = body.join
  a.demand(status == 200 && html.include?('One conventional static candidate'), 'Typed route page failed')
  a.demand(probes.last.calls.map(&:first) == [:route_actions] && probes.last.closed, 'Page expanded facts or failed to close Reader')
  href = CGI.unescapeHTML(html.scan(/href="([^"]+)"/).flatten.find { |value| value.include?('#L2') })
  target = URI.parse(href)
  source_fields = URI.decode_www_form(target.query).to_h
  a.demand(source_fields.values_at('generation','selection','q','id') == [a::GENERATION,fields['selection'],'orders',a::METHOD], 'Source target lost state')
  status, _, source_body = request.call('/source',source_fields)
  a.demand(status == 200 && source_body.join.include?('id="L2"') && source_body.join.include?('source-row selected'), 'Candidate failed to reveal physical saved Source')
  status, _, body = request.call('/source',fields)
  a.demand(status == 200 && body.join.include?('Inspect controller/action candidates'), 'Source-less route lacks compact typed entry')
  a.demand(probes.last.calls.map(&:first) == [:source,:fact_identity], 'Route Source expanded fallback')
  [%w[page 1],%w[direction incoming],%w[file ignored],['cursor',a.cursor(1,a::OTHER)]].each do |key,value|
    count=probes.length
    status, = request.call('/route-actions',fields.merge(key=>value))
    a.demand(status==400 && probes.length==count,'Invalid destination opened Reader')
  end
  mode=:forged
  status, = request.call('/route-actions',fields)
  a.demand(status==422 && probes.last.closed,'Forged root accepted or Reader leaked')
  mode=:unsupported_native
  status, = request.call('/route-actions',fields)
  a.demand(status==422,'Missing native operation inferred a fallback')
  before=probes.length
  status, = app.call(env.merge('PATH_INFO'=>'/route-actions','QUERY_STRING'=>URI.encode_www_form(fields),'REMOTE_ADDR'=>'192.0.2.1'))
  a.demand(status==403 && before==probes.length,'Route bypassed host access control')
  puts 'PASS mocked App typed journey, physical line, compact route entry and pre-Reader/access refusals'
end
