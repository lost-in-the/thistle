# frozen_string_literal: true

# Opt-in entry documentation only. Ordinary unit discovery must never boot the
# producer, load Rails/native or allocate a fixture database from this file.
if $PROGRAM_NAME == __FILE__
  raise 'Root must separately admit the LOS153 produce.rb / consume.rb processes; see the public fixture README.'
end
