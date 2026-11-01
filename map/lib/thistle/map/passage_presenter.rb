# frozen_string_literal: true

require 'erb'
require 'json'
require_relative 'route_actions_presenter'

module Thistle
  module Map
    # Only typed Rust evidence. No Reader, semantic resolver or private URL policy.
    class PassagePresenter
      MAX_BODY_BYTES = 65_536
      SELECTION_LABELS = {'choose_saved_action'=>'Choose a saved action definition',
        'selected_syntax_binding_unknown'=>'Selected saved action syntax; runtime binding unknown'}.freeze
      APPLICABILITY_LABELS = {'excluded_by_recorded_action_condition'=>'Excluded for this action by recorded action conditions',
        'opaque_conditions_unknown'=>'Action applicability has opaque conditions',
        'action_applicable_conditions_not_executed'=>'Recorded action conditions permit this filter; conditions were not executed'}.freeze
      CONTRIBUTION_LABELS = {'qualified_target_unavailable'=>'Save syntax found; unique recorded model and callback evidence unavailable',
        'potential_save_callback_contribution'=>'Potential registered save callback contribution'}.freeze

      def self.page_limit(navigation)
        [[(MAX_BODY_BYTES / 3) / (navigation.reference_url_bytes * 7), 1].max, 8].min
      end

      def self.request_bytes(navigation, family: 'sequence', action: nil)
        if family == 'export' && action
          # Export renders the report, not the duplicate items or their row links.
          # Reserve the selected Source link, continuation and one spare control.
          # The final HTML cap still refuses exceptional escaping inflation.
          hrefs = 3 * navigation.reference_url_bytes
          return [[MAX_BODY_BYTES - hrefs - 8192, 1024].max, 32768].min
        end
        # Four compact callback links + action/model/registry per row, plus page
        # controls. Reserve markup and escaped DTO/report space separately.
        hrefs = (page_limit(navigation) * 7 + 4) * navigation.reference_url_bytes
        [[(MAX_BODY_BYTES - hrefs - 8192) * 2 / 5, 1024].max, 32768].min
      end

      def self.validate!(answer, generation:, id:, action:, family:, cursor: nil, limit: 8, max_bytes: 32768)
        unless max_bytes.instance_of?(Integer) && max_bytes.between?(1024,32768) &&
            answer.instance_of?(Hash) && JSON.generate(answer).bytesize <= max_bytes && answer['version'] == 1 &&
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
                evidence['operation'].instance_of?(String) && evidence['reason'].instance_of?(String) &&
                %w[inside_branch_syntax no_enclosing_branch_syntax].include?(evidence['condition'])
              raise Thistle::InvalidSnapshot, 'Invalid Passage source operation'
            end
            span = evidence['span']
            selected = answer.fetch('selected_action').fetch('span')
            span_within!(span, selected)
            if evidence['condition'] == 'inside_branch_syntax'
              branch = evidence['branch']
              unless branch.instance_of?(Hash) && branch.keys.sort == %w[kind span] &&
                  %w[if unless case when in and or or_write and_write safe_navigation while until for rescue ensure begin_rescue].include?(branch['kind'])
                raise Thistle::InvalidSnapshot, 'Missing enclosing branch syntax'
              end
              span_within!(branch['span'], selected)
              unless branch['span']['start_byte'] <= span['start_byte'] && branch['span']['end_byte'] >= span['end_byte']
                raise Thistle::InvalidSnapshot, 'Branch does not enclose operation'
              end
            elsif evidence.key?('branch')
              raise Thistle::InvalidSnapshot, 'Unenclosed operation invented a branch'
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
                  unless callback.instance_of?(Hash) && callback.keys.sort == %w[binding callback_id conditions effects filter inherited kind position reason registry_id registry_provenance status witness] &&
                      callback['registry_id'] == row.dig('save_contribution','registry','id') &&
                      callback['position'].instance_of?(Integer) && callback['position'] >= 0 &&
                      callback['callback_id'] == "#{callback['registry_id']}:#{callback['position']}" &&
                      callback['registry_provenance'] == 'registered_metadata' && callback['filter'].instance_of?(Hash) &&
                      callback['conditions'].instance_of?(Hash) && callback['binding'].instance_of?(String) &&
                      callback['effects'].instance_of?(Hash) && callback.dig('effects','returned_count').instance_of?(Integer) &&
                      callback.dig('effects','returned_count') >= 0 && callback.dig('effects','details') == 'not_projected' &&
                      callback.dig('effects','returned_count') <= 8 &&
                      callback.dig('effects','unit') == 'representative_potential_perform_later_call_groups' &&
                      [true,false].include?(callback.dig('effects','search_complete')) &&
                      (callback['effects'].keys - %w[returned_count unit search_complete details non_exhaustive known_omitted]).empty? &&
                      callback.dig('effects','non_exhaustive') == true && !callback.key?('explanation') &&
                      (callback['filter'].keys - %w[kind name owner]).empty? &&
                      %w[method proc opaque unavailable].include?(callback['filter']['kind']) &&
                      (callback['kind'].nil? || %w[before after around].include?(callback['kind'])) &&
                      (callback['inherited'].nil? || [true,false].include?(callback['inherited']))
                    raise Thistle::InvalidSnapshot, 'Invalid compact Passage callback'
                  end
                  %w[if unless].each { |slot| condition_summary!(callback['conditions'][slot]) }
                  if callback['witness']
                    RouteActionsPresenter.identity!(callback['witness'], generation: generation, kind: 'method')
                    unless callback['binding'] == 'descriptor_matched_captured_declaration'
                      raise Thistle::InvalidSnapshot, 'Callback witness mismatch'
                    end
                  end
                end
                contribution = row.fetch('save_contribution')
                unless contribution['summary_limit'] == 4 && contribution['callbacks'].length <= 4 &&
                    contribution['summaries_omitted'].instance_of?(Integer) && contribution['summaries_omitted'] >= 0 &&
                    contribution['component_callbacks_returned'] == contribution['callbacks'].length + contribution['summaries_omitted'] &&
                    contribution['coverage'].instance_of?(Hash) &&
                    contribution['effect_absence'] == 'No supported match does not prove that no effect is possible.'
                  raise Thistle::InvalidSnapshot, 'Invalid callback summary omissions'
                end
              end
            elsif evidence['kind'] == 'save_operation'
              raise Thistle::InvalidSnapshot, 'Missing save qualification state'
            end
            if row['followup']
              candidate = row.fetch('related_candidate')
              RouteActionsPresenter.identity!(candidate, generation: generation, kind: 'method')
              unless row['candidate_matches'] == 1 && row['boundary'].instance_of?(String) &&
                  row['receiver_framework_role'] == 'unknown' &&
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
        if action
          filters, coverage = answer.values_at('filters','coverage')
          unless filters.instance_of?(Hash) && filters['registry_candidates'].instance_of?(Integer) && filters['registry_candidates'] >= 0 &&
              %w[not_captured ambiguous_registry_candidates captured unavailable].include?(filters['status']) && filters['binding'] == 'unknown' &&
              %w[selected_body_syntax bounded_partial unknown].include?(coverage['analysis_status']) &&
              [true,false].include?(coverage['source_scan_complete'])
            raise Thistle::InvalidSnapshot, 'Missing local Passage coverage states'
          end
          valid = case filters['status']
                  when 'not_captured' then filters['registry_candidates'].zero?
                  when 'ambiguous_registry_candidates' then filters['registry_candidates'] > 1
                  else filters['registry_candidates'] == 1
                  end
          raise Thistle::InvalidSnapshot, 'Contradictory filter registry count' unless valid
          if coverage['source_scan_complete']
            raise Thistle::InvalidSnapshot, 'Complete source scan has unsearched remainder' unless coverage['analysis_status'] == 'selected_body_syntax' && !coverage.key?('unsearched')
          elsif !coverage['unsearched'].instance_of?(String)
            raise Thistle::InvalidSnapshot, 'Incomplete source scan omitted its boundary'
          end
          if coverage['analysis_status'] == 'bounded_partial'
            span_within!(coverage['stop_region'], answer.fetch('selected_action').fetch('span'))
            raise Thistle::InvalidSnapshot, 'Invalid first-unvisited region' unless coverage['unsearched_from_byte'] == coverage.dig('stop_region','start_byte')
          elsif coverage['analysis_status'] == 'unknown' && !coverage['reason'].instance_of?(String)
            raise Thistle::InvalidSnapshot, 'Unknown source omitted its reason'
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
          prefix = "#{answer['semantics']}\nGeneration: #{generation}\nSelected action: #{action || 'none'}\n"
          report = answer['report']
          unless report.instance_of?(String) && report.start_with?(prefix) && JSON.parse(report.delete_prefix(prefix)) == answer['items']
            raise Thistle::InvalidSnapshot, 'Passage export meaning differs from selected rows'
          end
        end
        answer
      rescue KeyError, TypeError, NoMethodError, JSON::ParserError, JSON::GeneratorError, JSON::NestingError, Investigation::Invalid => error
        raise Thistle::InvalidSnapshot, "Invalid Passage projection (#{error.class})"
      end

      def self.span_within!(span, selected)
        unless span.instance_of?(Hash) && span.keys.sort == %w[end_byte end_line start_byte start_line] && selected &&
            span.values.all? { |v| v.instance_of?(Integer) } &&
            span['start_byte'] >= selected['start_byte'] && span['end_byte'] <= selected['end_byte'] && span['end_byte'] >= span['start_byte'] &&
            span['start_line'] >= selected['start_line'] && span['end_line'] <= selected['end_line'] && span['end_line'] >= span['start_line']
          raise Thistle::InvalidSnapshot, 'Passage region escapes selected action'
        end
      end

      def self.condition_summary!(condition)
        unless condition.instance_of?(Hash) && condition['evaluation'] == 'unknown' &&
            %w[recorded unavailable].include?(condition['status'])
          raise Thistle::InvalidSnapshot, 'Invalid callback condition summary'
        end
        if condition['status'] == 'recorded'
          unless condition.keys.sort == %w[count evaluation kinds status] && condition['kinds'].instance_of?(Hash) &&
              condition['count'].instance_of?(Integer) && condition['count'] >= 0 &&
              condition['kinds'].values.all? { |n| n.instance_of?(Integer) && n.positive? } &&
              (condition['kinds'].keys - %w[method proc opaque unavailable]).empty? &&
              condition['count'] == condition['kinds'].values.sum
            raise Thistle::InvalidSnapshot, 'Invalid recorded condition counts'
          end
        elsif condition.keys.sort != %w[evaluation status]
          raise Thistle::InvalidSnapshot, 'Unavailable conditions invented metadata'
        end
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
        body << "<p>#{h(SELECTION_LABELS.fetch(answer.fetch('selection_status')))}. #{h(RouteActionsPresenter::STATUSES.fetch(answer.dig('route','status')))}</p>"
        if action
          body << witness(answer.fetch('selected_action'), 'Inspect selected action')
          body << local_status(answer)
        else
          body << '<p>Choose a saved action definition to inspect its own operations. Multiple definitions remain alternatives.</p><ul>'
          answer.fetch('route').fetch('candidates').each do |candidate|
            fact = candidate.fetch('fact')
            href = @navigation.url('/passage/sequence', 'id'=>root, 'action'=>fact.fetch('id'), 'cursor'=>nil)
            body << "<li><a href=\"#{h(href)}\">#{h(fact.fetch('name'))} — #{h(fact['path'])}</a></li>"
          end
          body << '</ul>'
        end
        if answer.fetch('family') == 'export'
          body << "<pre class=\"check-data\">#{h(answer.fetch('report'))}</pre>"
        else
          body << '<ol>'
          answer.fetch('items').each do |row|
          body << '<li>'
          if row['kind'] == 'controller_filter'
            descriptor = row.fetch('registration').fetch('filter')
            body << "<strong>Registered filter: #{h(descriptor['name'] || descriptor.fetch('kind'))}</strong><p>Observed owner: #{h(descriptor['owner'] || 'unavailable')}. #{h(APPLICABILITY_LABELS.fetch(row.fetch('applicability')))}. #{h(row.fetch('order'))}</p>"
            body << witness(row['witness'], 'Inspect filter definition') if row['witness']
            body << '<p>No exact captured filter definition was matched.</p>' unless row['witness']
            body << "<pre class=\"check-data\">#{h(JSON.generate(row.fetch('registration')))}</pre>"
          else
            evidence = row.fetch('evidence')
            body << "<strong>#{h(evidence.fetch('operation'))}</strong><p>#{h(evidence.fetch('reason'))}</p>"
            if evidence['branch']
              kind = evidence.dig('branch','kind')
              label = {'or_write'=>'short-circuit ||= assignment', 'and_write'=>'short-circuit &&= assignment',
                'safe_navigation'=>'safe-navigation (&.) call'}.fetch(kind, kind.tr('_', ' '))
              body << "<p>Inside #{h(label)} branch syntax at saved line #{h(evidence.dig('branch','span','start_line'))}; predicate truth and execution unknown.</p>"
            else
              body << '<p>No enclosing branch syntax in the scanned body; execution remains unknown.</p>'
            end
            body << witness(row.fetch('witness'), 'Inspect operation in selected action', line: evidence.dig('span','start_line'))
            body << "<pre class=\"check-data\">#{h(evidence['syntax'])}</pre>" if evidence['syntax']
            if row['save_contribution']
              contribution = row.fetch('save_contribution')
              body << "<p>#{h(CONTRIBUTION_LABELS.fetch(contribution.fetch('status')))}; model binding and callback execution unknown.</p>"
              if row['model']
                href = @navigation.url('/source','id'=>row.fetch('model').fetch('id'))
                body << "<p><a href=\"#{h(href)}\">Inspect recorded model evidence</a></p>"
              end
              if contribution['registry']
                href = @navigation.url('/source','id'=>contribution.fetch('registry').fetch('id'))
                body << "<p><a href=\"#{h(href)}\">Inspect full recorded callback evidence</a></p>"
                body << "<p>Callback summaries omitted: #{h(contribution.fetch('summaries_omitted'))}. Component coverage: #{h(JSON.generate(contribution.fetch('coverage')))}</p>"
                body << "<p>#{h(contribution.fetch('effect_absence'))}</p>"
              end
              contribution.fetch('callbacks', []).each do |callback|
                filter = callback.fetch('filter')
                body << "<p>Registered callback #{h(filter['name'] || filter.fetch('kind'))}; observed owner #{h(filter['owner'] || 'unavailable')}.</p>"
                body << "<p>Representative potential perform_later call groups: #{h(callback.dig('effects','returned_count'))}; capped at 8, non-exhaustive. This is not a count of invocations.</p>"
                body << "<pre class=\"check-data\">#{h(JSON.generate(callback.slice('conditions','binding','status','reason','effects','inherited')))}</pre>"
                body << witness(callback['witness'], 'Inspect potential model callback definition') if callback['witness']
              end
            end
            if row['followup']
              body << "<p>#{h(row.fetch('boundary'))}</p>"
              body << witness(row.fetch('related_candidate'), 'Inspect related method syntax')
              href = @navigation.url('/job-mail/handoff', 'id'=>row.fetch('followup').fetch('id'))
              body << "<p>Framework role and binding unknown. <a href=\"#{h(href)}\">Inspect related method source evidence beyond this boundary</a></p>"
            end
          end
          body << '</li>'
        end
        body << '</ol>'
        body << '<p>No admitted steps on this page; coverage below distinguishes unselected, unsupported and unsearched evidence.</p>' if answer.fetch('items').empty?
        end
        if answer['continuation']
          href = @navigation.url("/passage/#{answer.fetch('family')}", 'id'=>root, 'action'=>action, 'cursor'=>answer.fetch('next_cursor'))
          body << "<p><a href=\"#{h(href)}\">#{action ? 'Continue selected-action evidence' : 'Continue saved action choices'}</a></p>"
        end
        if action && answer.fetch('family') != 'export'
          href = @navigation.url('/passage/export','id'=>root,'action'=>action,'cursor'=>nil)
          body << "<p><a href=\"#{h(href)}\">Export this selected-action investigation</a></p>"
        end
        body << "<details><summary>Original route constraints and coverage</summary><pre class=\"check-data\">#{h(JSON.generate(answer.slice('route','filters','coverage')))}</pre></details></section>"
        raise Investigation::Limit, 'Passage exceeds display budget; use bounded Source or fewer collected links.' if body.bytesize > MAX_BODY_BYTES
        body
      end

      private

      def local_status(answer)
        filters = answer.fetch('filters')
        label = {'captured'=>'Captured filter registry label candidate', 'not_captured'=>'Controller filters were not captured for this action owner',
          'unavailable'=>'Controller filter registry was supplied but could not be observed', 'ambiguous_registry_candidates'=>'Multiple filter registries; no registry selected'}.fetch(filters.fetch('status'))
        coverage = answer.fetch('coverage')
        scan = if coverage['source_scan_complete']
                 'Selected action source scan complete within the supported syntax; execution unknown.'
               elsif coverage['analysis_status'] == 'bounded_partial'
                 "Selected action source scan partial; unsearched work begins at saved byte #{coverage.fetch('unsearched_from_byte')}."
               else
                 "Selected action source scan unknown: #{coverage.fetch('reason').tr('_', ' ')}. Source operations remain unsearched."
               end
        "<div class=\"notice ui\"><p>#{h(label)} (#{h(filters.fetch('registry_candidates'))} recorded candidates); binding unknown.</p><p>#{h(scan)}</p></div>"
      end

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
