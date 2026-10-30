# frozen_string_literal: true

require "optparse"
require_relative "../thistle"

module Thistle
  class CLI
    HELP = <<~TEXT.freeze
      Thistle — inspect captured evidence

      thistle capture ROOT --output STORE [--max-nodes INTEGER]
      thistle find TEXT --store STORE [--generation ID] [--limit 50] [--domain all|source|metadata] [--kind KIND] [--path PREFIX]
      thistle model-brief MODEL_ID --store STORE --generation ID [--limit 8] [--max-bytes 32768] [--family columns|associations|registry_candidates] [--cursor TOKEN]
      thistle references ID --store STORE --generation ID [--direction outgoing|incoming] [--limit 50] [--candidate-link ORDINAL] [--cursor TOKEN]
      thistle source-file PATH --store STORE --generation ID
      thistle source ID --store STORE [--generation ID]
      thistle links ID --store STORE [--generation ID]
      thistle check --store STORE [--generation ID]
      thistle version

      Find without domain/kind/path filters returns the existing named-fact response.
      Add --domain all (or another evidence filter) for literal source/metadata results.
      Source returns the exact captured file. Links preserves
      unresolved relationships. Check verifies snapshot integrity and reports scope;
      it does not claim the live application is fresh. Static capture executes no app
      code. Live Rails capture is an explicit Ruby API (see README).
    TEXT

    def initialize(out: $stdout, err: $stderr)
      @out, @err = out, err
    end

    def run(arguments)
      args = arguments.dup
      command = args.shift
      if [nil, "help", "--help", "-h"].include?(command)
        @out.write(HELP)
        return 0
      end
      if command == "version"
        raise InvalidInput, "version accepts no arguments" unless args.empty?
        emit("version" => VERSION, "native" => Native.call("op" => "version"))
        return 0
      end
      unless %w[capture find source source-file links check model-brief references].include?(command)
        raise InvalidInput, "Unknown action. Use thistle help to see the available actions."
      end
      options = command == "model-brief" ? { limit: 8, max_bytes: 32768 } : { limit: 50 }
      parser = OptionParser.new do |opts|
        if command == "capture"
          opts.on("--output PATH") { |value| options[:output] = value }
          opts.on("--max-nodes INTEGER", Integer) { |value| options[:max_nodes] = value }
        else
          opts.on("--store PATH") { |value| options[:store] = value }
          opts.on("--generation ID") { |value| options[:generation] = value }
          if command == "model-brief"
            opts.on("--limit INTEGER", Integer) { |value| options[:limit] = value }
            opts.on("--max-bytes INTEGER", Integer) { |value| options[:max_bytes] = value }
            opts.on("--family NAME") { |value| options[:family] = value }
          end
          if %w[model-brief references].include?(command)
            opts.on("--cursor TOKEN") { |value| options[:cursor] = value }
          end
          if command == "references"
            opts.on("--limit INTEGER", Integer) { |value| options[:limit] = value }
            opts.on("--direction NAME") { |value| options[:direction] = value }
            opts.on("--candidate-link INTEGER", Integer) { |value| options[:candidate_link] = value }
          end
          if command == "find"
            opts.on("--limit NUMBER", Integer) { |value| options[:limit] = value }
            opts.on("--domain DOMAIN") { |value| options[:domain] = value }
            opts.on("--kind KIND") { |value| options[:kind] = value }
            opts.on("--path PREFIX") { |value| options[:path] = value }
          end
        end
      end
      parser.parse!(args)
      expected = command == "check" ? 0 : 1
      raise InvalidInput, "#{command} expects #{expected} argument#{expected == 1 ? '' : 's'}" unless args.length == expected
      if command == "capture"
        raise InvalidInput, "capture requires --output STORE" unless options[:output]
        limits = options.key?(:max_nodes) ? { max_nodes: options[:max_nodes] } : {}
        emit(Thistle.capture(root: args.first, output: options[:output], limits: limits))
      else
        raise InvalidInput, "#{command} requires --store STORE" unless options[:store]
        if %w[source-file model-brief references].include?(command) && !options[:generation]
          raise InvalidInput, "#{command} requires --generation ID"
        end
        reader = Reader.new(options[:store], generation: options[:generation])
        begin
          result = case command
          when "find"
            if %i[domain kind path].any? { |key| options.key?(key) }
              reader.search_evidence(args.first, **options.slice(:limit, :domain, :kind, :path))
            else
              reader.search(args.first, limit: options[:limit])
            end
          when "model-brief" then reader.model_brief(args.first, **options.slice(:limit, :max_bytes, :family, :cursor))
          when "references" then reader.references(args.first, **options.slice(:limit, :direction, :candidate_link, :cursor))
          when "source-file" then reader.source_file(args.first)
          when "source" then reader.source(args.first)
          when "links" then { "generation" => reader.generation, "fact_id" => args.first, "links" => reader.links(args.first) }
          when "check" then reader.check
          end
          emit(result)
        ensure
          reader.close
        end
      end
      0
    rescue OptionParser::ParseError, ArgumentError => error
      fail_with("invalid_input", error.message, 2)
    rescue Error => error
      fail_with(error.code, error.message, error.is_a?(InvalidInput) ? 2 : (error.is_a?(NotFound) ? 3 : 4))
    rescue StandardError
      fail_with("internal_error", "The operation failed without a result.", 1)
    end

    private

    def emit(value)
      @out.puts(JSON.generate(value))
    end

    def fail_with(code, message, status)
      @err.puts(JSON.generate("error" => { "code" => code, "message" => message }))
      status
    end
  end
end
