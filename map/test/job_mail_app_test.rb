# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'json'

# Every route probe is a fresh stdlib process. Reader and highlighter are pure
# doubles; no Native, Rails app, store, server, browser or dependency install.
class JobMailAppTest < Minitest::Test
  PROGRAM = <<~'RUBY'
    require 'json'
    require 'erb'
    require 'digest'
    require 'cgi'
    project, mode = ARGV
    require File.join(project,'lib/thistle/errors')
    $LOADED_FEATURES << File.join(project,'map/lib/thistle/map/highlighter.rb')
    module Thistle
      module Map
        module Highlighter
          def self.lines(content, **) = content.lines.map { |line| ERB::Util.html_escape(line.chomp) }
          def self.language_for(path) = path.end_with?('.erb') ? 'erb' : 'ruby'
        end
      end
    end
    require File.join(project,'map/lib/thistle/map/app')
    G = 'a' * 64
    REGISTRY = 'b' * 64
    METHOD = 'c' * 64
    TEMPLATE = 'd' * 64
    CLASS = 'e' * 64
    CANDIDATE = 'f' * 64
    def demand(value, message)
      raise message unless value
    end
    def continuation(id,family)
      JSON.generate(['recorded-v1',G,Digest::SHA256.hexdigest(JSON.generate(['job_mail',id,family])),1,0])
    end
    class SavedReader
      attr_reader :generation,:manifest,:calls,:closed
      def initialize(mode)
        @generation,@mode,@calls,@closed = G,mode,[],false
        @manifest = { 'schema_version' => 3,'files' => [],'coverage' => [{'family'=>'rails_job_mail','status'=>'partial'}] }
      end
      def identity(id)
        kind = {REGISTRY=>'rails_job_mail',METHOD=>'method',TEMPLATE=>'file',CLASS=>'class',CANDIDATE=>'method'}.fetch(id)
        path = kind == 'rails_job_mail' ? nil : kind == 'file' ? 'app/views/receipt.html.erb' : 'app/jobs/receipt_job.rb'
        { 'generation'=>G,'id'=>id,'kind'=>kind,'name'=>id == CANDIDATE ? '<script>ReceiptMailer#receipt</script>' : kind == 'file' ? 'receipt.html.erb' : 'ReceiptJob',
          'evidence'=>kind == 'rails_job_mail' ? 'runtime' : 'static','path'=>path,
          'span'=>path && {'start_line'=>1,'end_line'=>1,'start_byte'=>0,'end_byte'=>20} }
      end
      def request(id,family,cursor = nil)
        {'operation'=>'job_mail','generation'=>G,'id'=>id,'family'=>family,'cursor'=>cursor}
      end
      def job_mail(id,**options)
        @calls << [:job_mail,id,options]
        raise Thistle::InvalidInput, 'Unknown native operation' if @mode == 'native_unavailable'
        family = options.fetch(:family)
        root = identity(id)
        items = case family
        when 'overview'
          families = root['kind'] == 'rails_job_mail' ? %w[registrations declarations] : root['kind'] == 'file' ? ['template_references'] : ['handoff']
          families.map { |value| {'kind'=>'family','family'=>value,'request'=>request(id,value)} }
        when 'registrations'
          [{'kind'=>'registration','root'=>root,'position'=>0,'registration'=>{'exception'=>'DeliveryTimeout','handler'=>{'kind'=>'proc'},'shared_with_superclass'=>true}}]
        when 'declarations'
          [{'kind'=>'declaration_candidate','role'=>'perform','label'=>'ReceiptJob#perform','candidate_matches'=>2,'candidate_status'=>'ambiguous',
            'candidate'=>identity(METHOD),'request'=>request(METHOD,'overview')}]
        else
          evidence = if family == 'policy'
            {'kind'=>'policy_declaration','operation'=>'retry_on','span'=>root['span']}
          elsif family == 'template_references'
            {'kind'=>'helper_candidate','name'=>'receipt_heading','span'=>root['span']}
          else
            {'kind'=>'mailer_action_candidate','receiver'=>'ReceiptMailer','action'=>'receipt','span'=>root['span']}
          end
          [{'kind'=>'source_evidence','root'=>root,'ordinal'=>0,'sha256'=>'9' * 64,'evidence'=>evidence,
            'candidate_matches'=>2,'candidate_status'=>'ambiguous','candidate'=>identity(CANDIDATE),'request'=>request(CANDIDATE,'overview')}]
        end
        next_cursor = family != 'overview' && options[:cursor].nil? ? continuation(id,family) : nil
        answer = {'version'=>1,'generation'=>G,'root'=>root,'family'=>family,'items'=>items,'provenance'=>'saved_evidence',
          'coverage'=>{'source_scan_complete'=>false,'scope'=>'selected saved evidence only'},'cost'=>{},
          'unknowns'=>{'coherence'=>'unknown','binding'=>'unknown','execution'=>'unknown','delivery'=>'unknown'},
          'page_complete'=>next_cursor.nil?,'next_cursor'=>next_cursor,'continuation'=>next_cursor && request(id,family,next_cursor),
          'semantics'=>'Registration, source potential and execution differ; no invocation or delivery observed.'}
        answer['generation'] = '8' * 64 if @mode == 'bad_generation'
        answer['family'] = 'policy' if @mode == 'bad_family'
        answer['root']['id'] = TEMPLATE if @mode == 'bad_root'
        answer['items'][0]['request']['id'] = TEMPLATE if @mode == 'bad_candidate'
        answer['items'][0]['candidate']['generation'] = '8' * 64 if @mode == 'bad_candidate_generation'
        answer['continuation']['cursor'] = continuation(id,'policy') if @mode == 'bad_cursor'
        answer['semantics'] = 'x' * 32768 if @mode == 'oversized'
        answer
      end
      def fact_identity(id)
        @calls << [:identity,id]
        compact = identity(id).reject { |key,_| %w[generation span].include?(key) }
        compact['location'] = identity(id)['span']
        {'generation'=>G,'fact'=>compact}
      end
      def source(id)
        @calls << [:source,id]
        if id == REGISTRY
          error = Thistle::Error.new('source unavailable')
          error.instance_variable_set(:@native_code,'source_unavailable')
          raise error
        end
        fact = identity(id).reject { |key,_| %w[generation span].include?(key) }
        fact['location'] = identity(id)['span']
        content = id == TEMPLATE ? "<%= raise 'NEVER EVALUATE ERB' %>\n" : "def perform; mail; end\n"
        {'generation'=>G,'fact'=>fact,'content'=>content,'sha256'=>Digest::SHA256.hexdigest(content)}
      end
      def references(id,**options)
        @calls << [:references,id]
        fact = identity(id).reject { |key,_| %w[generation span].include?(key) }
        fact['location'] = identity(id)['span']
        {'generation'=>G,'anchor'=>fact,'direction'=>options.fetch(:direction),'relationships'=>[],'next_cursor'=>nil,
          'coverage'=>{'known_matches'=>0,'known_omitted'=>0,'scan_complete'=>true,'capture_partial'=>true}}
      end
      def fact(*) = raise('Expanded fact fallback used')
      def facts = raise('Whole-generation scan used')
      def source_file(*) = raise('Source fanout used')
      def model_brief(*) = raise('Model fanout used')
      def close = @closed = true
    end
    readers = []
    app = Thistle::Map::App.new(store:'/unused',reader_factory:->(*) do
      reader = SavedReader.new(mode)
      reader.singleton_class.undef_method(:job_mail) if mode == 'reader_unavailable'
      reader.singleton_class.undef_method(:fact_identity) if mode == 'identity_unavailable'
      readers << reader
      reader
    end)
    base = {'REQUEST_METHOD'=>'GET','SCRIPT_NAME'=>'/map','HTTP_HOST'=>'localhost','REMOTE_ADDR'=>'127.0.0.1','rack.url_scheme'=>'http'}
    def get(app,base,path,params)
      status,headers,body = app.call(base.merge('PATH_INFO'=>path,'QUERY_STRING'=>URI.encode_www_form(params)))
      [status,headers,body.each.to_a.join]
    end
    params = {'generation'=>G,'id'=>METHOD,'selection'=>METHOD,'q'=>'receipt','domain'=>'source'}
    if mode == 'routes'
      {'overview'=>REGISTRY,'registrations'=>REGISTRY,'declarations'=>REGISTRY,'policy'=>CLASS,'handoff'=>METHOD,'template_references'=>TEMPLATE}.each do |family,id|
        status,_,html = get(app,base,"/job-mail/#{family}",params.merge('id'=>id))
        demand(status == 200,"#{family} status #{status}:#{html}")
        demand(readers.last.calls.map(&:first) == [:job_mail],'Projection performed fanout')
        demand(readers.last.calls[0][2].values_at(:family,:limit,:max_bytes) == [family,8,32768],'Default query admission changed')
        demand(readers.last.closed,'Reader not closed')
        demand(html.include?('<noscript>') && html.include?('Find') && html.include?('Check'),'Recognizable/no-JS navigation lost')
        demand(!html.include?('<script>ReceiptMailer'),'Candidate label not escaped')
      end
    elsif mode == 'refusals'
      wrong = params.merge('cursor'=>continuation(METHOD,'policy'))
      [wrong,params.merge('cursor'=>'{'),params.merge('page'=>'1'),params.merge('candidate'=>'0'),params.merge('direction'=>'outgoing'),params.reject { |k,_| k == 'generation' }].each do |values|
        demand(get(app,base,'/job-mail/handoff',values)[0] == 400,'Bad scope reached Reader')
      end
      demand(get(app,base,'/job-mail/evaluate',params)[0] == 404,'Unknown route allowed')
      demand(get(app,base.merge('REQUEST_METHOD'=>'POST'),'/job-mail/handoff',params)[0] == 405,'Mutation method allowed')
      demand(get(app,base.merge('REMOTE_ADDR'=>'192.0.2.1'),'/job-mail/handoff',params)[0] == 403,'Access gate weakened')
      demand(readers.empty?,'Refusal opened ReaderFactory')
    elsif mode == 'head'
      status,headers,body = get(app,base.merge('REQUEST_METHOD'=>'HEAD'),'/job-mail/handoff',params)
      demand(status == 200 && body.empty? && headers.fetch('content-length').to_i > 0 && readers.last.closed,'HEAD/close contract changed')
    elsif mode == 'identity_unavailable'
      status,_,_ = get(app,base,'/source',params.merge('id'=>REGISTRY))
      demand(status == 422 && readers.last.closed && readers.last.calls.map(&:first) == [:source],'Compact identity absence expanded a fact')
    elsif mode == 'entry_links'
      {METHOD=>'Inspect handoff',CLASS=>'Inspect policy',TEMPLATE=>'Inspect template references',REGISTRY=>'Inspect registrations'}.each do |id,label|
        status,_,html = get(app,base,'/source',params.merge('id'=>id))
        demand(status == 200 && html.include?(label),"Missing explicit Source entry:#{id}:#{status}")
        demand(readers.last.calls.none? { |c| c[0] == :job_mail },'Source auto-parsed job evidence')
        demand(!html.include?("<%= raise"),'ERB source unescaped') if id == TEMPLATE
      end
      status,_,html = get(app,base,'/links',params.merge('direction'=>'incoming'))
      demand(status == 200 && html.include?('Inspect handoff'),'Incoming Links entry lost')
      demand(readers.last.calls.map(&:first) == [:references],'Incoming identity fallback expanded')
    elsif mode == 'followup' || mode == 'full_collection'
      if mode == 'full_collection'
        ids = [METHOD] + (1..23).map { |n| n.to_s(16).rjust(64,'0') }
        params.merge!('selection'=>ids.join(','),'q'=>'雪' * 80,'prefix'=>'x' * 1500)
      end
      status,_,html = get(app,base,'/job-mail/handoff',params)
      demand(status == 200,"Followup page status#{status}:#{html}")
      hrefs = html.scan(/href="([^"]+)"/).flatten.map { |value| CGI.unescapeHTML(value) }
      candidate = hrefs.map { |value| URI(value) }.find { |uri| uri.path == '/map/job-mail/overview' && URI.decode_www_form(uri.query).to_h['id'] == CANDIDATE }
      demand(candidate,'Typed candidate projection missing')
      values = URI.decode_www_form(candidate.query).to_h
      demand(values.values_at('generation','selection') == [G,params['selection']],'Candidate lost saved collection')
      demand(candidate.query.bytesize <= 4096 && values.length <= 9,'Candidate exceeded URL bounds')
      if mode == 'full_collection'
        demand(html.include?('Search context exceeds the navigation link budget'),'Search-drop notice missing')
        demand(readers.last.calls[0][2][:limit] < 8,'Long hrefs were not admitted before query')
      end
      status,_,_ = get(app,base,candidate.path.delete_prefix('/map'),values)
      demand(status == 200 && readers.last.calls.map(&:first) == [:job_mail],'Candidate invoked another operation')
    else
      status,_,_ = get(app,base,'/job-mail/handoff',params)
      demand(status == 422,"Invalid projection status#{status}")
      expected = mode == 'reader_unavailable' ? [] : [:job_mail]
      demand(readers.last.closed && readers.last.calls.map(&:first) == expected,'Refusal leaked/fanned out')
    end
    demand(!defined?(Rails) && !defined?(Thistle::Native),'Native/framework loaded')
    puts JSON.generate('mode'=>mode,'readers'=>readers.length,'scope'=>'stdlib mocked routes only')
  RUBY

  %w[routes refusals head identity_unavailable entry_links followup full_collection bad_generation bad_family bad_root bad_candidate bad_candidate_generation bad_cursor oversized reader_unavailable native_unavailable].each do |mode|
    define_method("test_#{mode}") do
      out,err,status = Open3.capture3(RbConfig.ruby,'-e',PROGRAM,File.expand_path('../..',__dir__),mode)
      assert status.success?,"#{mode}:#{err}"
      assert_equal mode,JSON.parse(out).fetch('mode')
    end
  end
end
