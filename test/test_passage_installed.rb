# frozen_string_literal: true

# AUTHORED UNRUN. Manual entry; it does not start a producer, shell, build or server.
# Root invokes the two explicit fixture phases in separate installed processes:
#   ruby produce.rb NEW_PUBLIC_WORK_DIR > producer.json
#   ruby consume.rb producer.json
# Their stdout belongs in Root's admitted protected sink, never a bare command
# copied from this comment. See docs/development/passage.md and served_protocol.md.
# The producer must reach the actual framework storage/ISeq guard and the real
# Ruby3.4 Set @hash path in Root's minimum cohort. Pure NameError/native-Set mocks
# do not satisfy that gate. Reader/Map/export cards distinguish direct create
# from the actual saved conditional span and inspect compact callback omissions.
if $PROGRAM_NAME == __FILE__
  raise 'Run the explicit LOS150 producer/consumer protocol under Root admission; this file is documentation, not an execution grant.'
end
