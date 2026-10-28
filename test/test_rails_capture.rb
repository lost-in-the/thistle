# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "logger"
require "stringio"
require "rails"
require "action_controller/railtie"
require_relative "../lib/thistle/capture"

class ThistleRailsCaptureTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("thistle-rails-")
    return unless name == "test_observes_real_booted_rails_routes_without_attaching_stale_source"

    @app = Class.new(Rails::Application).new
    @app.config.root = @root
    @app.config.eager_load = false
    @app.config.secret_key_base = "thistle-private-fixture-secret" * 4
    @app.config.logger = Logger.new(StringIO.new)
    @app.initialize!
    @app.routes.draw do
      get "/baskets/:id", to: "baskets#show", as: :basket
      post "/baskets", to: "baskets#create"
      get "/health", to: ->(_env) { [200, {}, ["ok"]] }
    end
    File.write(File.join(@root, "basket.rb"), "class Basket; def label; :basket; end; end\n")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_observes_real_booted_rails_routes_without_attaching_stale_source
    result = Thistle::Capture.new(root: @root, rails: @app).call
    routes = result["facts"].select { |fact| fact["kind"] == "route" }
    show = routes.find { |fact| fact.dig("attributes", "action") == "show" }
    assert show
    assert_equal "runtime", show["evidence"]
    assert_equal "GET", show["attributes"]["verb"]
    assert_equal "/baskets/:id(.:format)", show["attributes"]["route_path"]
    assert_equal "basket", show["attributes"]["route_name"]
    assert_nil show["path"]
    assert_nil show["location"]
    assert_equal "unknown", show["attributes"]["coherence"]
    assert_includes show["links"], { "relation" => "routes_to", "target" => "baskets#show", "resolution" => "unresolved" }
    assert_equal "complete", result["coverage"].find { |c| c["family"] == "rails_routes" }["status"]
    assert_equal "unavailable", result["coverage"].find { |c| c["family"] == "runtime_source_coherence" }["status"]
    assert result["facts"].any? { |fact| fact["name"] == "Basket#label" && fact["evidence"] == "static" }
  end

  def test_runtime_failure_is_unavailable_not_successful_empty
    broken_app = Object.new
    def broken_app.routes
      raise "sensitive details must not be serialized"
    end
    result = Thistle::Capture.new(root: @root, rails: broken_app).call
    coverage = result["coverage"].find { |c| c["family"] == "rails_routes" }
    assert_equal "unavailable", coverage["status"]
    assert result["diagnostics"].any? { |d| d["code"] == "rails_capture_failed" }
    refute JSON.generate(result).include?("sensitive details")
  end

  def test_static_and_runtime_batches_share_one_link_budget
    File.write(File.join(@root, "example.rb"), "class Example < Base; end\n")
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw { get "/baskets/:id", to: "baskets#show" }
    app = Struct.new(:routes).new(routes)
    error = assert_raises(Thistle::Capture::LimitError) do
      Thistle::Capture.new(root: @root, rails: app, limits: { max_links: 1 }).call
    end
    assert_match(/max_links/, error.message)
  end

  def test_runtime_batch_refuses_evidence_before_accumulating_it
    require_relative "../lib/thistle/rails_capture"
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw { get "/baskets/:id", to: "baskets#show" }
    app = Struct.new(:routes).new(routes)
    assert_raises(Thistle::Capture::LimitError) do
      Thistle::RailsCapture.new(app: app, limits: Thistle::Capture::DEFAULT_LIMITS, evidence_budget: 32).call
    end
  end
end
