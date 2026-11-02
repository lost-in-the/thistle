# frozen_string_literal: true

# AUTHORED UNRUN. Reuse the fresh installed Core harness with this fixture's
# produce.rb then consume.rb in separate processes outside the checkout.
# No Rails, Active Record, database, parser/capture or server is required.
# The entry contract itself grants no runtime/build/install authority.
if $PROGRAM_NAME == __FILE__
  raise 'Use the explicit source-freshness installed producer/consumer under Root admission; see its fixture README.'
end
