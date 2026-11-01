# frozen_string_literal: true

require 'erb'
require 'json'
require_relative 'route_actions_presenter'

module Thistle
  module Map
    # Only typed Rust evidence. No Reader, semantic resolver or private URL policy.
    class PassagePresenter
      MAX_BODY_BYTES = 65_536

      def self.page_limit(navigation)
        [[(MAX_BODY_BYTES / 3) / (navigation.reference_url_bytes * 4), 1].max, 8].min
      end

      def self.validate!(answer, generation:, id:, action:, family:, cursor: nil, limit: 8)
        unless answer.instance_of?(Hash) && JSON.generate(answer).bytesize <= 32768 && answer['version'] == 1 &&
            answer['generation'] == generation && answer['family'] == family && %w[sequence export].include?(family) &&
            answer['semantics'].instance_of?(String) && answer['coverage'].instance_of?(Hash) &&
            [true,false].include?(answer.dig('coverage','page_complete')) && answer.dig('coverage','execution') == 'unavailable' &&
            answer['offset'].instance_of?(Integer) && answer['offset'] >= 0 &&
            answer['items'].instance_of?(Array) && answer['items'].length <= limit
          raise Thistle::InvalidSnapshot, 'Passage envelope mismatch'
        end
        RouteActionsPresenter.identity!(answer.fetch('root'), generation: generation, kind: 'route', id: id)
        # The nested route component has its own exact bounded contract. Its root
        # was moved to the top-level by Rust, so restore only that compact value.
        route = answer.fetch('route').merge('root' => answer.fetch('root'))
        RouteActionsPresenter.validate!(route, generation: generation, id: id, limit: 16)
        if action
          RouteActionsPresenter.identity!(answer.fetch('selected_action'), generation: generation, kind: 'method', id: action)
          raise Thistle::InvalidSnapshot, 'Passage selection mismatch' unless answer['selection_status'] == 'selected_syntax_binding_unknown'
        elsif answer['selected_action'] || answer['selection_status'] != 'choose_saved_action' || !answer['items'].empty?
          raise Thistle::InvalidSnapshot, 'Unselected passage asserted a sequence'
        end
        answer.fetch('items').each_with_index do |row, index|
          unless row.instance_of?(Hash) && %w[controller_filter source_operation].include?(row['kind']) &&
              row['ordinal'] == answer['offset'] + index && row['binding'] == 'unknown'
            raise Thistle::InvalidSnapshot, 'Invalid selected-action Passage row'
          end
          if row['kind'] == 'source_operation'
            raise Thistle::InvalidSnapshot, 'Operation belongs to another action' unless row['witness'] == answer['selected_action']
            evidence = row.fetch('evidence')
            unless evidence.instance_of?(Hash) && %w[save_operation async_boundary mail_boundary constant_call_boundary boundary].include?(evidence['kind']) &&
                evidence['operation'].instance_of?(String) && evidence['reason'].instance_of?(String) && evidence['condition'] == 'unknown'
              raise Thistle::InvalidSnapshot, 'Invalid Passage source operation'
            end
            span = evidence['span']
            selected = answer.fetch('selected_action').fetch('span')
            unless span.instance_of?(Hash) && span.keys.sort == %w[end_byte end_line start_byte start_line] &&
                span.values.all? { |v| v.instance_of?(Integer) } && selected &&
                span['start_byte'] >= selected['start_byte'] && span['end_byte'] <= selected['end_byte'] && span['end_byte'] >= span['start_byte'] &&
                span['start_line'] >= selected['start_line'] && span['end_line'] <= selected['end_line'] && span['end_line'] >= span['start_line']
              raise Thistle::InvalidSnapshot, 'Operation span escapes selected action'
            end
            if row.key?('save_contribution')
              unless evidence['kind'] == 'save_operation' && %w[create create!].include?(evidence['operation']) &&
                  evidence['receiver'].instance_of?(String) && evidence['receiver'].start_with?('::') &&
                  row['save_contribution'].instance_of?(Hash) &&
                  %w[qualified_target_unavailable potential_save_callback_contribution].include?(row.dig('save_contribution','status'))
                raise Thistle::InvalidSnapshot, 'Save contribution lacks selected-action operation witness'
              end
              if row.dig('save_contribution','status') == 'potential_save_callback_contribution'
                unless row['model_candidates'] == 1 && row['callback_registry_candidates'] == 1 &&
                    row.dig('save_contribution','model_binding') == 'unknown' && row.dig('save_contribution','callbacks').instance_of?(Array)
                  raise Thistle::InvalidSnapshot, 'Unqualified save callback contribution'
                end
                generic_identity!(row.fetch('model'), generation, 'rails_model')
                generic_identity!(row.dig('save_contribution','registry'), generation, 'rails_save_callbacks')
                row.dig('save_contribution','callbacks').each do |callback|
                  raise Thistle::InvalidSnapshot, 'Invalid Passage callback' unless callback.instance_of?(Hash)
                  if callback['witness']
                    RouteActionsPresenter.identity!(callback['witness'], generation: generation, kind: 'method')
                    unless callback.dig('explanation','binding') == 'descriptor_matched_captured_declaration' &&
                        callback.dig('explanation','method','id') == callback.dig('witness','id')
                      raise Thistle::InvalidSnapshot, 'Callback witness mismatch'
                    end
                  end
                end
              end
            elsif evidence['kind'] == 'save_operation'
              raise Thistle::InvalidSnapshot, 'Missing save qualification state'
            end
            if row['followup']
              candidate = row.fetch('related_candidate')
              RouteActionsPresenter.identity!(candidate, generation: generation, kind: 'method')
              unless row['candidate_matches'] == 1 && row['boundary'].instance_of?(String) &&
                  row['followup'] == {'operation'=>'job_mail','generation'=>generation,'id'=>candidate['id'],'family'=>'handoff'} &&
                  %w[async_boundary constant_call_boundary].include?(evidence['kind'])
                raise Thistle::InvalidSnapshot, 'Invalid Passage boundary followup'
              end
            end
          else
            unless Investigation::DIGEST.match?(row['registry_id'].to_s) && row['registration'].instance_of?(Hash) &&
                %w[excluded_by_recorded_action_condition opaque_conditions_unknown action_applicable_conditions_not_executed].include?(row['applicability']) && row['order'].instance_of?(String)
              raise Thistle::InvalidSnapshot, 'Invalid registered filter row'
            end
            RouteActionsPresenter.identity!(row['witness'], generation: generation, kind: 'method') if row['witness']
          end
        end
        if answer.dig('coverage','page_complete')
          raise Thistle::InvalidSnapshot, 'Complete passage has continuation' if answer['next_cursor'] || answer['continuation']
        else
          expected = {'operation'=>'passage','generation'=>generation,'id'=>id,'action'=>action,'family'=>family,'cursor'=>answer['next_cursor']}
          returned = action ? answer['items'].length : route.fetch('candidates').length
          unless returned.positive? && answer['next_cursor'] != cursor && answer['continuation'] == expected
            raise Thistle::InvalidSnapshot, 'Passage continuation made no progress'
          end
          NavigationContext.validate_cursor!(answer['next_cursor'], generation: generation, scope: ['passage',id,action,family])
          unless JSON.parse(answer['next_cursor']).last(2) == [answer['offset'] + returned,0]
            raise Thistle::InvalidSnapshot, 'Passage continuation skipped rows'
          end
        end
        if family == 'export'
          expected = "#{answer['semantics']}\nGeneration: #{generation}\nSelected action: #{action || 'none'}\n#{JSON.generate(answer['items'])}\n"
          raise Thistle::InvalidSnapshot, 'Passage export meaning differs from selected rows' unless answer['report'] == expected
        end
        answer
      rescue KeyError, TypeError, NoMethodError, JSON::GeneratorError, JSON::NestingError, Investigation::Invalid => error
        raise Thistle::InvalidSnapshot, "Invalid Passage projection (#{error.class})"
      end

      def self.generic_identity!(fact, generation, kind)
        unless fact.instance_of?(Hash) && fact.keys.sort == %w[evidence generation id kind name path span] &&
            fact['generation'] == generation && fact['kind'] == kind && fact['evidence'] == 'runtime' &&
            Investigation::DIGEST.match?(fact['id'].to_s) && fact['name'].instance_of?(String) && fact['name'].bytesize <= 4096 &&
            fact['path'].nil? && fact['span'].nil?
          raise Thistle::InvalidSnapshot, 'Invalid Passage runtime witness'
        end
      end

      def initialize(navigation:)
        @navigation = navigation
      end

      def render(answer)
        body = +'<section aria-label="Potential request Passage"><h2>Potential request Passage</h2>'
        body << "<p class=\"notice ui\">#{h(answer.fetch('semantics'))}</p>"
        root = answer.fetch('root').fetch('id')
        action = answer.dig('selected_action','id')
        body << "<p>#{h(answer.fetch('selection_status'))}. #{h(RouteActionsPresenter::STATUSES.fetch(answer.dig('route','status')))}</p>"
        if action
          body << witness(answer.fetch('selected_action'), 'Inspect selected action')
        else
          body << '<p>Choose a saved action definition to inspect its own operations. Multiple definitions remain alternatives.</p><ul>'
          answer.fetch('route').fetch('candidates').each do |candidate|
            fact = candidate.fetch('fact')
            href = @navigation.url('/passage/sequence', 'id'=>root, 'action'=>fact.fetch('id'), 'cursor'=>nil)
            body << "<li><a href=\"#{h(href)}\">#{h(fact.fetch('name'))} — #{h(fact['path'])}</a></li>"
          end
          body << '</ul>'
        end
        body << '<ol>'
        answer.fetch('items').each do |row|
          body << '<li>'
          if row['kind'] == 'controller_filter'
            body << "<strong>Registered controller filter #{h(row.fetch('ordinal'))}</strong> <p>#{h(row.fetch('applicability'))}. #{h(row.fetch('order'))}</p>"
            body << witness(row['witness'], 'Inspect filter definition') if row['witness']
            body << '<p>No exact captured filter definition was matched.</p>' unless row['witness']
            body << "<pre class=\"check-data\">#{h(JSON.pretty_generate(row.fetch('registration')))}</pre>"
          else
            evidence = row.fetch('evidence')
            body << "<strong>#{h(evidence.fetch('operation'))}</strong><p>#{h(evidence.fetch('reason'))}</p>"
            body << witness(row.fetch('witness'), 'Inspect operation in selected action', line: evidence.dig('span','start_line'))
            body << "<pre class=\"check-data\">#{h(evidence['syntax'])}</pre>" if evidence['syntax']
            if row['save_contribution']
              contribution = row.fetch('save_contribution')
              body << "<p>#{h(contribution.fetch('status'))}; model binding and callback execution unknown.</p>"
              if row['model']
                href = @navigation.url('/source','id'=>row.fetch('model').fetch('id'))
                body << "<p><a href=\"#{h(href)}\">Inspect recorded model evidence</a></p>"
              end
              # Callback explanation retains its exact saved definition/effect
              # spans. It is explicitly conditional contribution, never a trace.
              body << "<pre class=\"check-data\">#{h(JSON.pretty_generate(contribution))}</pre>"
              contribution.fetch('callbacks', []).each do |callback|
                body << witness(callback['witness'], 'Inspect potential model callback definition') if callback['witness']
              end
            end
            if row['followup']
              body << "<p>#{h(row.fetch('boundary'))}</p>"
              body << witness(row.fetch('related_candidate'), 'Inspect related method syntax')
              href = @navigation.url('/job-mail/handoff', 'id'=>row.fetch('followup').fetch('id'))
              body << "<p><a href=\"#{h(href)}\">Inspect potential mail/template handoff beyond this boundary</a></p>"
            end
          end
          body << '</li>'
        end
        body << '</ol>'
        body << '<p>No admitted steps on this page; coverage below distinguishes unselected, unsupported and unsearched evidence.</p>' if answer.fetch('items').empty?
        if answer['continuation']
          href = @navigation.url("/passage/#{answer.fetch('family')}", 'id'=>root, 'action'=>action, 'cursor'=>answer.fetch('next_cursor'))
          body << "<p><a href=\"#{h(href)}\">#{action ? 'Continue selected-action evidence' : 'Continue saved action choices'}</a></p>"
        end
        href = @navigation.url('/passage/export','id'=>root,'action'=>action,'cursor'=>nil)
        body << "<p><a href=\"#{h(href)}\">Export this selected-action investigation</a></p>" unless answer.fetch('family') == 'export'
        body << "<pre class=\"check-data\">#{h(answer.fetch('report'))}</pre>" if answer['report']
        body << "<details><summary>Original route constraints and coverage</summary><pre class=\"check-data\">#{h(JSON.pretty_generate(answer.slice('route','filters','coverage')))}</pre></details></section>"
        raise Investigation::Limit, 'Passage exceeds display budget; use bounded Source or fewer collected links.' if body.bytesize > MAX_BODY_BYTES
        body
      end

      private

      def witness(fact, caption, line: nil)
        return '<p>No saved physical source mapping.</p>' unless fact['path'] && fact['span']
        # The operation span is within the already validated selected declaration.
        # Native supplies it; Map never finds a line from a name or live source.
        line ||= fact.fetch('span').fetch('start_line')
        href = @navigation.url('/source','id'=>fact.fetch('id')) + "#L#{line}"
        "<p>#{h(fact.fetch('name'))} — #{h(fact.fetch('path'))}:#{h(line)} <a href=\"#{h(href)}\">#{h(caption)}</a></p>"
      end

      def h(value) = ERB::Util.html_escape(value.to_s)
    end
  end
end
