# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/thistle/errors'
require_relative '../lib/thistle/map/job_mail_presenter'

class JobMailPresenterTest < Minitest::Test
  GENERATION = 'a' * 64
  class Navigation
    attr_reader :calls
    def initialize = @calls = []
    def url(path, extra = {})
      @calls << [path, extra]
      '/root-owned-witness'
    end
  end

  def identity
    { 'generation' => GENERATION, 'id' => 'b' * 64, 'kind' => 'method', 'name' => 'ReceiptJob#perform',
      'evidence' => 'static', 'path' => 'app/jobs/receipt_job.rb', 'span' => { 'start_line' => 9 } }
  end

  def answer
    { 'version' => 1, 'generation' => GENERATION, 'root' => identity, 'family' => 'handoff',
      'items' => [{ 'kind' => 'source_evidence', 'root' => identity, 'sha256' => 'c' * 64,
        'evidence' => { 'kind' => 'mailer_action_candidate', 'receiver' => '<script>Mailer</script>',
          'span' => { 'start_line' => 10 } }, 'candidate_status' => 'ambiguous', 'candidate_matches' => 2,
        'candidate' => identity, 'request' => request }], 'coverage' => { 'source_scan_complete' => false },
      'unknowns' => { 'execution' => 'unknown', 'delivery' => 'unknown' }, 'continuation' => request,
      'page_complete' => false, 'semantics' => 'Source-potential only; no invocation or delivery observed.' }
  end

  def request
    { 'operation' => 'job_mail', 'generation' => GENERATION, 'id' => 'b' * 64, 'family' => 'handoff', 'cursor' => 'opaque' }
  end

  def test_escaped_evidence_typed_requests_and_root_navigation_without_own_state_policy
    nav = Navigation.new
    requests = []
    presenter = Thistle::Map::JobMailPresenter.new(generation: GENERATION, navigation: nav,
      projection: ->(descriptor) { requests << descriptor; '/root-owned-projection' })
    html = presenter.render(answer)
    assert_includes html, '&lt;script&gt;Mailer&lt;/script&gt;'
    refute_includes html, '<script>'
    assert_includes html, 'ambiguous'
    assert_includes html, 'delivery unknown'
    assert_includes html, 'Continue this evidence family'
    assert_includes html, '/root-owned-witness#L10'
    assert nav.calls.all? { |path, extra| %w[/source /links].include?(path) && (extra.keys - %w[id direction]).empty? }
    assert_equal [request, request], requests
    refute_includes html, 'javascript:'
    refute_includes html, 'onclick'
  end

  def test_missing_projection_is_explicit_and_generation_mismatch_refuses
    presenter = Thistle::Map::JobMailPresenter.new(generation: GENERATION, navigation: Navigation.new)
    assert_includes presenter.render(answer), 'projection route not integrated'
    bad = answer
    bad['items'][0]['candidate']['generation'] = 'd' * 64
    assert_raises(Thistle::InvalidSnapshot) { presenter.render(bad) }
  end
end
