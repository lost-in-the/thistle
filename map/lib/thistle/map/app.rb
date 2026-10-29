# frozen_string_literal: true

require 'uri'
require 'ipaddr'
require_relative 'view'

module Thistle
  module Map
    # A Rack-compatible app. The host chooses the server and the mount explicitly.
    # Never consults forwarded headers or opens a user-supplied filesystem path.
    class App
      MAX_QUERY_BYTES = FindPresenter::MAX_QUERY_BYTES
      DIGEST = /\A[0-9a-f]{64}\z/.freeze
      DEFAULT_HOSTS = %w[localhost 127.0.0.1 [::1]].freeze
      ASSETS = {
        '/assets/woods-map-tokens.css' => ['woods-map-tokens.css', 'text/css; charset=utf-8'],
        '/assets/map.css' => ['map.css', 'text/css; charset=utf-8'],
        '/assets/map.js' => ['map.js', 'text/javascript; charset=utf-8']
      }.freeze
      HEADERS = {
        'content-security-policy' => "default-src 'none'; style-src 'self'; script-src 'self'; " \
          "img-src 'self'; connect-src 'none'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
        'x-content-type-options' => 'nosniff', 'x-frame-options' => 'DENY',
        'referrer-policy' => 'no-referrer', 'cache-control' => 'no-store',
        'cross-origin-resource-policy' => 'same-origin'
      }.freeze

      def initialize(store:, authorize: nil, allowed_hosts: DEFAULT_HOSTS, reader_factory: nil)
        raise ArgumentError, 'allowed_hosts must be a nonempty list' if allowed_hosts.empty?
        raise ArgumentError, 'authorize must be callable' if authorize && !authorize.respond_to?(:call)

        @store = File.expand_path(store).freeze
        @authorize = authorize
        @allowed_hosts = allowed_hosts.map { |host| host.to_s.downcase.freeze }.freeze
        @reader_factory = reader_factory || ->(path, generation) { Thistle::Reader.new(path, generation: generation) }
        asset_root = File.expand_path('../../../assets', __dir__)
        @assets = ASSETS.transform_values { |file, type| [File.binread(File.join(asset_root, file)).freeze, type] }.freeze
      end

      def call(env)
        reader = nil
        return finish(env, 403, 'Access denied. This reader requires an authorized host and peer.') unless authorized?(env)
        unless %w[GET HEAD].include?(env['REQUEST_METHOD'])
          return finish(env, 405, 'This reader accepts GET and HEAD only.', extra: { 'allow' => 'GET, HEAD' })
        end

        path = env.fetch('PATH_INFO', '/')
        if @assets.key?(path)
          content, type = @assets.fetch(path)
          return finish(env, 200, content, type: type)
        end
        return finish(env, 404, 'This page does not exist.') unless %w[/ /source /links /check].include?(path)

        mount = mount_path(env)
        params = parameters(env.fetch('QUERY_STRING', ''))
        if (path == '/links' && !params['id']) || (path == '/source' && %w[id path file].count { |key| params.key?(key) } != 1)
          raise BadRequest, 'Choose a result before opening Source or Links.'
        end
        if (params['path'] || params['file']) && (path != '/source' || params['id'] || !params['generation'])
          raise BadRequest, 'File Source requires a saved generation and one captured file.'
        end
        reader = @reader_factory.call(@store, params['generation'])
        if params['generation'] && reader.generation != params['generation']
          raise Thistle::InvalidSnapshot, 'Reader substituted a different generation'
        end
        if params['file']
          # Resolve only inside this pinned manifest; never treat the reference
          # as a filesystem path or silently select another generation.
          selected = nil
          reader.manifest.fetch('files').each do |file|
            next unless FindPresenter.file_reference(file.fetch('path')) == params['file']
            raise Thistle::InvalidSnapshot, 'Ambiguous captured file reference' if selected

            selected = file.fetch('path')
          end
          raise Thistle::NotFound, 'Captured file reference is absent' unless selected

          params['path'] = selected
          params.delete('file')
        end
        view = View.new(reader: reader, mount: mount, params: params)
        content = case path
                  when '/' then view.find
                  when '/source' then params['path'] ? view.source_file : view.source
                  when '/links' then view.links
                  when '/check' then view.check
                  end
        finish(env, 200, content, type: 'text/html; charset=utf-8')
      rescue BadRequest => e
        finish(env, 400, e.message)
      rescue View::Limit => e
        finish(env, 422, e.message)
      rescue Thistle::Error => e
        status = e.is_a?(Thistle::NotFound) ? 404 : 422
        finish(env, status, 'The requested evidence is missing or invalid. No other capture has been substituted.')
      rescue StandardError => e
        env['rack.errors']&.puts("Thistle Map request failed: #{e.class}")
        finish(env, 500, 'This evidence view could not be opened.')
      ensure
        reader.close if reader.respond_to?(:close)
      end

      private

      class BadRequest < StandardError; end

      def finish(env, status, content, type: 'text/plain; charset=utf-8', extra: {})
        headers = HEADERS.merge('content-type' => type, 'content-length' => content.bytesize.to_s).merge(extra)
        [status, headers, env['REQUEST_METHOD'] == 'HEAD' ? [] : [content]]
      end

      def authorized?(env)
        authority = env['HTTP_HOST'].to_s
        match = /\A(\[[0-9a-f:]+\]|[a-z0-9.-]+)(?::([0-9]{1,5}))?\z/i.match(authority)
        return false unless match && @allowed_hosts.include?(match[1].downcase)
        return false if match[2] && !(1..65_535).cover?(match[2].to_i)
        return false if env['HTTP_SEC_FETCH_SITE'] == 'cross-site'
        return false unless same_origin?(env, authority)

        if @authorize
          @authorize.call(env) == true
        else
          DEFAULT_HOSTS.include?(match[1].downcase) && IPAddr.new(env['REMOTE_ADDR'].to_s).loopback?
        end
      rescue StandardError
        false
      end

      def same_origin?(env, authority)
        origin = env['HTTP_ORIGIN']
        return true unless origin

        expected = URI.parse("#{env.fetch('rack.url_scheme', 'http')}://#{authority}")
        actual = URI.parse(origin)
        %w[http https].include?(actual.scheme) && !actual.userinfo && !actual.query && !actual.fragment &&
          (actual.path.nil? || actual.path.empty?) &&
          [actual.scheme, actual.host, actual.port] == [expected.scheme, expected.host, expected.port]
      rescue URI::InvalidURIError
        false
      end

      def mount_path(env)
        mount = env.fetch('SCRIPT_NAME', '')
        return '' if mount == '' || mount == '/'
        raise BadRequest, 'Invalid mount path.' unless /\A(?:\/[A-Za-z0-9_-]+)+\z/.match?(mount)

        mount
      end

      def parameters(query)
        raise BadRequest, 'The query is too long.' if query.bytesize > MAX_QUERY_BYTES
        raise BadRequest, 'Malformed query encoding.' if /%(?![0-9a-f]{2})/i.match?(query)

        pairs = URI.decode_www_form(query, Encoding::UTF_8)
        raise BadRequest, 'Too many query fields.' if pairs.length > 8

        pairs.each_with_object({}) do |(key, value), out|
          raise BadRequest, 'Unknown or repeated query field.' unless %w[q id generation page path file kind prefix domain].include?(key) && !out.key?(key)
          raise BadRequest, 'Invalid query text.' unless value.valid_encoding? && !value.include?("\0") && !value.include?("\uFFFD")
          raise BadRequest, 'Search text is too long.' if key == 'q' && value.bytesize > 256
          raise BadRequest, 'Invalid evidence identifier.' if %w[id generation file].include?(key) && !DIGEST.match?(value)
          raise BadRequest, 'Invalid page number.' if key == 'page' && !/\A[1-9][0-9]{0,3}\z/.match?(value)

          raise BadRequest, 'Invalid search domain.' if key == 'domain' && !%w[all source metadata].include?(value)
          if key == 'path' && (value.empty? || value.include?('\\') || value.match?(/[[:cntrl:]]/) || value.split('/', -1).any? { |part| ['', '.', '..'].include?(part) })
            raise BadRequest, 'Choose a captured relative file path.'
          end
          out[key] = value
        end
      rescue ArgumentError
        raise BadRequest, 'Malformed query encoding.'
      end
    end
  end
end
