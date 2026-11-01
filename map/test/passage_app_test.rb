# frozen_string_literal: true

# Isolated mocked App boundary: no framework/native/store/server/browser.
# Correction batch: AUTHORED UNRUN locally; Root owns all App execution.
if $PROGRAM_NAME == __FILE__
require_relative 'passage_presenter_test'
require 'cgi'
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

class PassageAppTest < Minitest::Test
  class Reader
    attr_reader :generation,:manifest,:calls,:closed
    def initialize(mode)
      @mode,@generation,@manifest,@calls = mode,PassageAnswers::GENERATION,{'files'=>[],'coverage'=>[],'schema_version'=>3},[]
    end
    def passage(id, **args)
      @calls << [id,args]
      raise Thistle::Busy,'busy' if @mode == :busy
      answer = PassageAnswers.page(save:args[:action] == PassageAnswers::ACTION,selected:!!args[:action],family:args[:family])
      if args[:action] == PassageAnswers::OTHER
        answer['selected_action']['id'] = args[:action]
      end
      answer
    end
    def close = @closed = true
  end
  def setup
    @readers = []
    @mode = :normal
    @app = Thistle::Map::App.new(store:'mock-only',reader_factory:->(*) {Reader.new(@mode).tap { |r| @readers << r }})
  end
  def request(extra={},method:'GET',path:'/passage/sequence',host:'localhost')
    @app.call({'REQUEST_METHOD'=>method,'PATH_INFO'=>path,'QUERY_STRING'=>URI.encode_www_form({'generation'=>PassageAnswers::GENERATION,'id'=>PassageAnswers::ROUTE,'action'=>PassageAnswers::ACTION}.merge(extra)),
      'HTTP_HOST'=>host,'REMOTE_ADDR'=>'127.0.0.1','SCRIPT_NAME'=>''})
  end
  def test_one_operation_close_head_and_busy_boundary
    status,headers,body = request
    assert_equal 200,status
    assert_includes body.join,'Save syntax found; unique recorded model'
    assert_equal 1,@readers.last.calls.length
    assert_operator @readers.last.calls.first.last.fetch(:max_bytes),:<,32768
    assert @readers.last.closed
    assert headers.fetch('content-security-policy').include?("default-src 'none'")
    status,_,body = request(method:'HEAD')
    assert_equal 200,status
    assert_empty body
    assert @readers.last.closed
    @mode = :busy
    status,headers,_ = request
    assert_equal 503,status
    assert_equal '1',headers['retry-after']
    assert @readers.last.closed
  end
  def test_scope_access_and_methods_refuse_before_reader_factory
    require_relative 'passage_navigation_test'
    token = PassageNavigationTest.new('unused').cursor
    [{'action'=>PassageAnswers::OTHER,'cursor'=>token},{'page'=>'1'},{'action'=>'invalid'},{'generation'=>nil}].each do |extra|
      assert_equal 400,request(extra).first
    end
    assert_equal 403,request(host:'foreign.invalid').first
    assert_equal 405,request(method:'POST').first
    assert_empty @readers
  end
end
end
