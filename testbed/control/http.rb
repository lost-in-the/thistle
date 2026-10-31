# frozen_string_literal: true

require 'net/http'
require 'socket'

module HostHTTP
  Response = Struct.new(:code, :body)
  module_function

  def request(socket_path, path)
    raise 'Private HTTP socket path refused' unless socket_path.match?(%r{\A/work/sessions/[0-9a-f]{32}/http\.sock\z})
    raise 'Internal HTTP path refused' unless path.start_with?('/') && !path.match?(/[\r\n]/)
    # Net::HTTP owns response/chunk framing. This fixture adds only the fixed
    # UNIX transport for its declared INTERNAL http://127.0.0.1 URL.
    raw = UNIXSocket.new(socket_path)
    io = Net::BufferedIO.new(raw, read_timeout: 5, write_timeout: 5)
    io.write("GET #{path} HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n")
    response = Net::HTTPResponse.read_new(io)
    body = +''
    response.reading_body(io, true) do
      response.read_body do |chunk|
        raise 'Internal HTTP response budget' if body.bytesize + chunk.bytesize > 1024 * 1024
        body << chunk
      end
    end
    Response.new(response.code, body)
  ensure
    raw&.close
  end
end
