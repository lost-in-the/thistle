# frozen_string_literal: true

# Fixed stdio-to-loopback transport for the host's bounded socat listener. This
# exposes no command/eval parameter and cannot select another address or port.
require 'socket'
socket = TCPSocket.new('127.0.0.1', 9292)
writer = Thread.new do
  IO.copy_stream($stdin, socket)
  socket.close_write
rescue IOError, Errno::EPIPE
  nil
end
begin
  IO.copy_stream(socket, $stdout)
ensure
  socket.close
  writer.kill
  writer.join
end
