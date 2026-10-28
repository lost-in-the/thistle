# frozen_string_literal: true

require_relative 'test_helper'
require 'rack'
require 'rack/lint'
require 'rack/mock'

class MapRackContractTest < Minitest::Test
  include MapTestSupport

  def test_html_asset_and_denial_responses_obey_rack_contract
    app = Rack::Lint.new(make_app)
    [
      ['/', '127.0.0.1', 200],
      ['/assets/map.js', '127.0.0.1', 200],
      ['/', '192.0.2.1', 403]
    ].each do |path, peer, expected|
      env = Rack::MockRequest.env_for("http://localhost#{path}")
      env['REMOTE_ADDR'] = peer
      env['HTTP_HOST'] = 'localhost'
      status, _, body = app.call(env)
      assert_equal expected, status
      body.each { |part| assert_kind_of String, part }
      body.close if body.respond_to?(:close)
    end
  end
end
