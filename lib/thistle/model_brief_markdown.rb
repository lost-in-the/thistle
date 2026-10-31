# frozen_string_literal: true

require_relative "errors"

module Thistle
  # Presentation of one Rust-selected summary. Never follows references or pages.
  class ModelBriefMarkdown
    MAX_BYTES = 65_536
    FAMILIES = %w[columns associations registry_candidates callbacks outgoing incoming].freeze
    FAMILY_FIELDS = %w[status reason provenance fact_id known_omitted unsearched output_truncated recorded_items candidate_matches scan_complete model_registry_binding observed_model_label].freeze
    COVERAGE_FIELDS = %w[capture_partial_or_unknown capture_partial families_not_projected capture_families capture_scan_complete scan_scope scan_complete known_matches known_omitted not_searched candidate_search_complete declaration_scan_complete candidate_ranges_complete source_rows_not_searched rows_attempted rows_not_searched rows_metadata_omitted rows_output_omitted truncated absence].freeze
    PRODUCER_FIELDS = %w[name engine core_version capture_schema call_target_schema link_encoding_schema prism_version ruby_syntax_version parser_policy ruby_version ruby_engine rails_version].freeze
    SPAN_FIELDS = %w[start_byte end_byte start_line end_line].freeze

    def self.render(brief, manifest:, generation:, model_id:, max_bytes: 32_768)
      new(max_bytes).render(brief, manifest, generation, model_id)
    end

    def initialize(max_bytes)
      unless max_bytes.is_a?(Integer) && max_bytes.between?(1, MAX_BYTES)
        raise InvalidInput, "max_bytes must be an integer between 1 and 65536"
      end
      @max_bytes = max_bytes
      @output = +""
    end

    def render(brief, manifest, generation, model_id)
      unless hash_id?(generation) && hash_id?(model_id) && brief.is_a?(Hash) && brief["version"] == 1 &&
          brief["generation"] == generation && brief.dig("root", "id") == model_id && brief.dig("root", "kind") == "rails_model"
        raise InvalidSnapshot, "The model brief does not match the selected generation/model summary"
      end
      @generation = generation
      append "# Saved model investigation\n\n"
      fields({ "generation" => generation, "model_id" => model_id }, %w[generation model_id])
      append "\nSaved evidence only. Labels and candidates do not establish runtime binding, callback execution, delivery, order or live freshness. Empty searched evidence does not prove absence.\n\n"
      append "## Model\n\n"
      identity(brief.fetch("root"))
      fields(brief.fetch("model"), %w[name base_class superclass abstract table inheritance_column source coherence])
      append "\n## Producer and grammar\n\n"
      fields(manifest, %w[schema_version])
      fields(manifest["producer"] || {}, PRODUCER_FIELDS)
      append "\n## Coverage and limits\n\n"
      coverage = brief.fetch("coverage")
      fields(coverage, %w[capture_partial_or_unknown families_not_projected])
      array(coverage.fetch("families")).each { |row| fields(row, %w[family status]); append "\n" }
      fields(brief.fetch("limits"), %w[items_per_family wire_bytes_including_newline])
      fields({ "encoded_report_budget_bytes" => @max_bytes }, %w[encoded_report_budget_bytes])
      fields(brief, %w[uncertainty])
      FAMILIES.each do |name|
        family = brief.fetch("families").fetch(name)
        unless family["generation"] == generation
          raise InvalidSnapshot, "A model brief family has a different generation"
        end
        append "\n## #{name.tr('_', ' ')}\n\n"
        fields(family, FAMILY_FIELDS)
        fields(family["coverage"] || {}, COVERAGE_FIELDS, missing: false)
        items = array(family.fetch("items"))
        append "\nReturned rows: #{items.length}. Omission counts above concern this saved query scope; unknown counts are not zero.\n"
        items.each_with_index do |row, index|
          append "\n### Row #{index + 1}\n\n"
          case name
          when "columns" then fields(row, %w[name type null])
          when "associations" then fields(row, %w[name macro target polymorphic status])
          when "registry_candidates" then identity(row)
          when "callbacks" then callback(row)
          else reference(row)
          end
        end
        followup(name, model_id)
      end
      append "\n## Resolving evidence\n\n"
      append "Commands use STORE as a caller-supplied local store placeholder. Use a compatible installed Thistle and access to the same saved generation. IDs and byte/line spans refer only to that generation; source commands return captured files separately. No source bodies, excerpts, callback condition values, arbitrary attributes, link metadata, cursors or store paths are embedded. Producer fields absent from the saved manifest remain unknown.\n"
      @output
    rescue KeyError, TypeError, NoMethodError, EncodingError, ArgumentError
      raise InvalidSnapshot, "The model brief has an unsupported or malformed report shape"
    end

    private

    def append(text)
      if text.bytesize > @max_bytes - @output.bytesize
        raise LimitExceeded, "Encoded Markdown report exceeds max_bytes; no report was emitted"
      end
      @output << text
    end

    def array(value)
      raise InvalidSnapshot, "The model brief has an invalid row collection" unless value.is_a?(Array)
      value
    end

    def fields(data, names, missing: true)
      raise InvalidSnapshot, "The model brief has invalid report fields" unless data.is_a?(Hash)
      names.each do |name|
        next if !missing && !data.key?(name)
        append "- #{name.tr('_', ' ')}: #{literal(data[name])}\n"
      end
    end

    # Code spans keep all user text inert, including HTML, links and autolinks.
    # No dynamically constructed destinations; all commands contain validated IDs.
    def literal(value)
      return "unknown" if value.nil?
      unless value.is_a?(String) || value == true || value == false || value.is_a?(Integer)
        raise InvalidSnapshot, "The model brief has a non-scalar report field"
      end
      raw = value.to_s
      raise LimitExceeded, "A Markdown field exceeds max_bytes" if raw.bytesize > @max_bytes
      text = raw.encode(Encoding::UTF_8)
      raise InvalidSnapshot, "The model brief contains invalid UTF-8" unless text.valid_encoding?
      # A field cannot fit if its unescaped bytes already exceed the whole budget.
      raise LimitExceeded, "A Markdown field exceeds max_bytes" if text.bytesize > @max_bytes
      # Token boundaries avoid retrying a greedy scheme match at every letter.
      if !text.match?(/\A[0-9a-f]{64}:\d+\z/) && text.match?(%r{(?:\A|[^a-z0-9+.-])[a-z][a-z0-9+.-]*:(?!:)|(?:\A|[\s=(])[~\\/]}i)
        return "[withheld path or URL]"
      end
      text = text.gsub(/[[:cntrl:]\u2028\u2029\u202a-\u202e\u2066-\u2069]/) { |char| "\\u%04x" % char.ord }
      longest = 0
      text.scan(/`+/) { |run| longest = run.length if run.length > longest }
      fence = "`" * (longest + 1)
      "#{fence} #{text} #{fence}"
    end

    def hash_id?(value)
      value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)
    end

    def command(operation, id, suffix = "")
      return unless hash_id?(id)
      append "\n`thistle #{operation} #{id} --store STORE --generation #{@generation}#{suffix}`\n"
    end

    def identity(row)
      fields(row, %w[id kind name evidence path])
      fields(row["location"] || row["span"] || {}, SPAN_FIELDS, missing: false)
      command("source", row["id"])
      command("links", row["id"])
    end

    def callback(row)
      fields(row, %w[callback_id registry_id position kind inherited registry_provenance])
      fields(row["filter"] || {}, %w[kind name owner status])
      explanation = row.fetch("explanation")
      fields(explanation, %w[status reason binding coherence links_search_complete known_effects_omitted effects_non_exhaustive])
      identity(explanation["method"]) if explanation["method"]
      fields(explanation["source"] || {}, %w[path sha256 bytes lines])
      array(explanation.fetch("effects", [])).each do |effect|
        append "\nPotential request (not execution):\n\n"
        fields(effect, %w[kind receiver selector safe_navigation provenance excerpt_truncated])
        append "\nCall span:\n\n"
        fields(effect["call_span"] || {}, SPAN_FIELDS)
        append "\nReceiver span:\n\n"
        fields(effect["receiver_span"] || {}, SPAN_FIELDS)
      end
      command("links", row["registry_id"])
    end

    def reference(row)
      fields(row, %w[link_ordinal detail_omitted match_basis candidate_label candidate_matches candidate_search_complete])
      append "\nOrigin:\n\n"
      identity(row.fetch("origin"))
      fields(row.fetch("link"), %w[relation target resolution])
      array(row.fetch("candidates")).each do |candidate|
        append "\nLabel candidate (binding unknown):\n\n"
        identity(candidate)
      end
    end

    def followup(name, id)
      if %w[columns associations registry_candidates].include?(name)
        command("model-brief", id, " --family #{name}")
      elsif %w[incoming outgoing].include?(name)
        command("references", id, " --direction #{name}")
      end
    end
  end
end
