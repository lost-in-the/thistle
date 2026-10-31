# frozen_string_literal: true

# Only fixed harness programs. Prevent exception text/configuration/connection
# strings from leaking into retained subprocess output. No user-supplied code.
program = ARGV.shift
File.umask(0o077)
abort 'Unknown harness program' unless %w[host producer consumer probe].include?(program)
session = nil
begin
  if program == 'host'
    token = ARGV.shift
    require_relative 'session_log'
    raise 'Session token refused' unless token&.match?(/\A[0-9a-f]{32}\z/)
    session = "/work/sessions/#{token}"
    session, log = SessionLog.open('/work/sessions', token)
    ENV['THISTLE_HOST_SESSION'] = session
    $stdout.reopen(log)
    $stderr.reopen(log)
  end
  require_relative program
rescue Exception => error # include load/syntax failures; exit is always nonzero
  # Exception messages, SQL, environment, inspected values and external paths
  # are never diagnostic data. One allowlisted owned-source frame gives a
  # stable assertion/step identity bound to the retained source manifest.
  require 'json'
  frame = error.backtrace_locations&.find do |location|
    path = location.absolute_path.to_s
    path.start_with?('/input/control/', '/input/app/') || path.match?(%r{\A/work/sessions/[0-9a-f]{32}/attempts/[0-9a-f]{32}/app/})
  end
  file = frame&.absolute_path&.sub(%r{\A/input/}, '')&.sub(%r{\A/work/sessions/[0-9a-f]{32}/attempts/[0-9a-f]{32}/app/}, 'run-app/')
  safe_classes = %w[RuntimeError LoadError SyntaxError KeyError ArgumentError TypeError IOError Errno::ENOENT]
  kind = safe_classes.include?(error.class.name) ? error.class.name : 'UnexpectedError'
  diagnostic = { 'program' => program, 'step' => 'owned-program', 'class' => kind,
    'code' => frame ? "#{program.upcase}_L#{frame.lineno}" : 'HARNESS_UNEXPECTED',
    'frame' => file && { 'file' => file, 'line' => frame.lineno } }
  warn JSON.generate(diagnostic)
  if session && File.directory?(session)
    # Preserve a safe diagnostic even if opening host.log itself failed.
    SessionLog.failure(session, diagnostic)
  end
  exit 1
end
