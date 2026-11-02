# frozen_string_literal: true

# Direct source-only stdlib check, isolated by invocation. No Native is loaded.
if $PROGRAM_NAME == __FILE__
  require_relative 'fixtures/route_actions/source_answers'
  require_relative '../lib/thistle/errors'
  $LOADED_FEATURES << File.expand_path('../lib/thistle/native.rb', __dir__)
  module Thistle
    module Native
      class << self
        attr_accessor :calls
        def path(value) = value
        def call(request)
          calls << request
          case request.fetch('op')
          when 'open' then {'handle'=>17,'generation'=>'a'*64,'manifest'=>{}}
          when 'close' then nil
          when 'route_actions' then request
          else raise 'Unexpected operation'
          end
        end
      end
    end
  end
  require_relative '../lib/thistle/reader'
  Thistle::Native.calls = []
  reader = Thistle::Reader.new('unopened-mocked-store')
  id = RouteActionsAnswers::ROUTE
  first = reader.route_actions(id)
  RouteActionsAnswers.demand(first == {'op'=>'route_actions','handle'=>17,'id'=>id,'limit'=>8,'cursor'=>nil,'max_bytes'=>32768}, 'Reader changed defaults')
  token = RouteActionsAnswers.cursor
  answer = reader.route_actions(id, limit: 1, cursor: token, max_bytes: 1024)
  RouteActionsAnswers.demand(answer['limit'] == 1 && answer['cursor'] == token && answer['max_bytes'] == 1024, 'Reader derived selection or dropped controls')
  reader.close
  count = Thistle::Native.calls.length
  RouteActionsAnswers.rejects(Thistle::Error) { reader.route_actions(id) }
  RouteActionsAnswers.demand(Thistle::Native.calls.length == count, 'Closed Reader crossed Native')
  puts 'PASS thin Reader defaults, forwarding and closed-handle refusal (mocked Native)'
end
