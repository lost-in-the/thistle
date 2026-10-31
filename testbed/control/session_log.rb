# frozen_string_literal: true

require 'json'

module SessionLog
  module_function

  def open(root, token)
    raise 'Session token refused' unless token&.match?(/\A[0-9a-f]{32}\z/)
    directory = File.join(root, token)
    info = File.lstat(directory)
    raise 'Session directory refused' unless info.directory? && info.uid == Process.uid && (info.mode & 0o777) == 0o700
    [directory, File.open(File.join(directory, 'host.log'), File::WRONLY | File::CREAT | File::EXCL, 0o600)]
  end

  def failure(directory, diagnostic)
    info = File.lstat(directory)
    raise 'Diagnostic directory refused' unless info.directory? && info.uid == Process.uid && (info.mode & 0o777) == 0o700
    name = "host-failure-#{Process.pid}-#{Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)}.json"
    path = File.join(directory, name)
    temporary = path + '.tmp'
    data = JSON.generate(diagnostic)
    raise 'Diagnostic byte budget' if data.bytesize > 4096
    File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(data); f.flush; f.fsync }
    File.link(temporary, path)
    File.unlink(temporary)
  end
end
