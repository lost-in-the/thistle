# frozen_string_literal: true

module Thistle
  module MCP
    module Tools
      FAMILIES = %w[columns associations registry_candidates].freeze
      DESCRIPTIONS = {
        'thistle_find' => 'Find literal saved source or allowlisted metadata. Coverage and lower-bound totals matter; no semantic search or runtime binding.',
        'thistle_model_brief' => 'Read a saved model Brief, or continue a declared family. Registered, source-potential and executed behavior are distinct.',
        'thistle_links' => 'Follow saved incoming/outgoing references and ALL candidate pages using exact returned cursors and candidate_link ordinals. Label match is not dispatch.',
        'thistle_source' => 'Read one complete admitted captured file by fact ID or SHA256 of its recorded path. No live files or ranges; large files refuse.',
        'thistle_check' => 'Check integrity of this saved generation once per session. This does not check current source or runtime freshness.'
      }.freeze
      KEYS = {
        'thistle_find' => %w[generation query limit kind path_prefix domain],
        'thistle_model_brief' => %w[generation id limit family cursor],
        'thistle_links' => %w[generation id direction limit cursor candidate_link],
        'thistle_source' => %w[generation id file],
        'thistle_check' => %w[generation]
      }.freeze

      def self.schema(name)
        properties = { 'generation' => { 'type' => 'string', 'pattern' => '^[0-9a-f]{64}$' } }
        KEYS.fetch(name).each do |key|
          properties[key] ||= case key
          when 'id', 'file' then { 'type' => 'string', 'pattern' => '^[0-9a-f]{64}$' }
          when 'limit' then { 'type' => 'integer', 'minimum' => 1, 'maximum' => name == 'thistle_find' ? 16 : 8 }
          when 'candidate_link' then { 'type' => 'integer', 'minimum' => 0, 'maximum' => 0xffff_ffff }
          when 'family' then { 'type' => 'string', 'enum' => FAMILIES }
          when 'direction' then { 'type' => 'string', 'enum' => %w[incoming outgoing] }
          when 'domain' then { 'type' => 'string', 'enum' => %w[all source metadata] }
          when 'cursor' then { 'type' => 'string', 'minLength' => 1, 'maxLength' => Limits::CURSOR_BYTES }
          else { 'type' => 'string', 'minLength' => 1, 'maxLength' => key == 'query' ? 256 : 4096 }
          end
        end
        required = ['generation']
        required << 'query' if name == 'thistle_find'
        required << 'id' if %w[thistle_model_brief thistle_links].include?(name)
        schema = { 'type' => 'object', 'properties' => properties, 'required' => required, 'additionalProperties' => false }
        if name == 'thistle_source'
          schema['oneOf'] = [{ 'required' => ['id'], 'not' => { 'required' => ['file'] } },
            { 'required' => ['file'], 'not' => { 'required' => ['id'] } }]
        end
        schema
      end

      # SDK API binding only; session and tests do not require the optional SDK.
      def self.for_session(session)
        DESCRIPTIONS.map do |name, description|
          ::MCP::Tool.define(name: name, description: description, input_schema: schema(name),
            annotations: { read_only_hint: true, destructive_hint: false, open_world_hint: false, idempotent_hint: false }) do |server_context: nil, **arguments|
            # Cancellation arriving during a native call cannot be read by the
            # SDK's single-thread stdio loop. Do not promise preemption here.
            answer = session.call(name, arguments.transform_keys(&:to_s))
            ::MCP::Tool::Response.new([{ type: 'text', text: answer.fetch(:json) }],
              structured_content: answer.fetch(:data), error: answer.fetch(:error))
          end
        end
      end
    end
  end
end
