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

  def test_grouped_static_and_appended_runtime_diagnostics_keep_exact_totals
    require_relative "../lib/thistle"
    File.write(File.join(@root, "partial.rb"), <<~RUBY)
      describe "harmless source fixture" do
        class First; end
        class Second; end
        class Third; end
      end
    RUBY
    broken_app = Object.new
    def broken_app.routes = raise("private runtime detail")
    capture = Thistle::Capture.new(root: @root, rails: broken_app, limits: { max_diagnostics: 2 }).call
    assert_equal 2, capture.fetch("diagnostics").length
    assert_equal 3, capture.fetch("diagnostics").find { |entry| entry["code"] == "dynamic_scope" }.fetch("occurrences")
    assert_equal "partial", capture.fetch("coverage").find { |entry| entry["family"] == "ruby_declarations" }.fetch("status")
    assert_equal "unavailable", capture.fetch("coverage").find { |entry| entry["family"] == "rails_routes" }.fetch("status")
    store = File.join(@root, "saved-store")
    Thistle::Store.new(store).publish(capture)
    reader = Thistle::Reader.new(store)
    assert_equal({ "groups" => 2, "occurrences" => 4 }, reader.check.fetch("diagnostics"))
  ensure
    reader&.close
  end

  def test_runtime_batch_refuses_evidence_before_accumulating_it
    require_relative "../lib/thistle/rails_capture"
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw { get "/baskets/:id", to: "baskets#show" }
    app = Struct.new(:routes).new(routes)
    assert_raises(Thistle::Capture::LimitError) do
      limits = Thistle::Capture.new(root: @root).call.fetch("producer").fetch("effective_limits").transform_keys(&:to_sym)
      Thistle::RailsCapture.new(app: app, limits: limits, evidence_budget: 32).call
    end
  end

  def test_real_route_conditions_and_opaque_canaries
    require_relative '../lib/thistle/rails_capture'
    skip 'Route conditions are observed only on supported Rails versions' unless
      Thistle::RailsCapture::CONSTRAINT_RAILS_VERSIONS.include?(Rails::VERSION::STRING)
    canary = Object.new
    def canary.matches?(_request) = raise('constraint executed')
    def canary.inspect = raise('constraint inspected')
    def canary.to_s = raise('constraint stringified')
    callable = ->(_) { raise 'lambda executed' }
    routes = ActionDispatch::Routing::RouteSet.new
    pattern = /\A(global-)?api\z/im
    routes.draw do
      get '/orders/:id', to: 'orders#index', constraints: { host: 'example.test', id: /[0-9]+/ }
      get '/orders/:id', to: 'orders#index', constraints: { subdomain: pattern }
      constraints(canary) { get '/opaque', to: 'orders#index' }
      constraints(callable) { get '/lambda', to: 'orders#index' }
    end
    result = Thistle::Capture.new(root: @root, rails: Struct.new(:routes).new(routes)).call
    facts = result.fetch('facts').select { |f| f['kind'] == 'route' }
    assert_equal 4, facts.size
    first, second, object, lambda_fact = facts.map { |f| f.dig('attributes', 'route_constraints') }
    assert_equal 'example.test', first['request'].find { |e| e['key'] == 'host' }['value']
    assert_equal '[0-9]+', first['segments'].find { |e| e['key'] == 'id' }['value']
    regex = second['request'].find { |e| e['key'] == 'subdomain' }
    assert_equal pattern.source, regex['value']
    assert_equal pattern.options, regex['options']
    assert_equal pattern.encoding.name, regex['regexp_encoding']
    assert_equal pattern.source.encoding.name, regex['encoding']
    assert_equal 'present', object['opaque']
    assert_equal 'present', lambda_fact['opaque']
    assert_equal 'partial', result['coverage'].find { |c| c['family'] == 'rails_route_constraints' }['status']
  end

  def test_constraint_family_budget_includes_array_brackets_and_separators
    require_relative '../lib/thistle/rails_capture'
    observer = Thistle::RailsCapture.new(app: nil, limits: {})
    values = { host: '', subdomain: '' }
    overhead = JSON.generate(observer.send(:constraint_entries, values)).bytesize
    values[:host] = 'x' * (8_192 - overhead)
    entries = observer.send(:constraint_entries, values)
    refute_nil entries
    assert_equal 8_192, JSON.generate(entries).bytesize
    values[:host] += 'x'
    assert_nil observer.send(:constraint_entries, values)
  end

  def test_constraint_representation_fails_closed_on_unsupported_and_oversized_values
    require_relative '../lib/thistle/rails_capture'
    observer = Thistle::RailsCapture.new(app: nil, limits: {})
    assert_nil observer.send(:constraint_entries, { host: 'x' * 8193 })
    assert_nil observer.send(:constraint_entries, (0..32).to_h { |i| [i.to_s, 'x'] })
    assert_nil observer.send(:constraint_entries, { host: "\xff".b })
    hostile = Object.new
    def hostile.inspect = raise('inspected')
    def hostile.to_s = raise('stringified')
    assert_equal 'opaque', observer.send(:constraint_entries, { host: hostile }).first['type']
    assert_equal 'unknown', observer.send(:route_constraints, Object.new)['status']
    latin = "caf\xE9".dup.force_encoding('ISO-8859-1')
    entry = observer.send(:constraint_entries, { host: latin }).first
    assert_equal 'café', entry['value']
    assert_equal 'ISO-8859-1', entry['encoding']
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw { get '/x', to: 'orders#index', constraints: { host: 'test' } }
    route = routes.routes.first
    observer.stub(:supported_constraint_version?, false) do
      assert_equal 'unknown', observer.send(:route_constraints, route)['status']
    end
    def route.constraints = raise('sensitive error')
    observed = observer.send(:route_constraints, route)
    assert_equal 'unknown', observed['status']
    refute_includes JSON.generate(observed), 'sensitive error'
  end
end
