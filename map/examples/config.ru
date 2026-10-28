# frozen_string_literal: true

require 'thistle/map'

# Run through your chosen Rack server bound to 127.0.0.1. No server is bundled.
# THISTLE_STORE is an operator-controlled path to a published Thistle store.
run Thistle::Map::App.new(store: ENV.fetch('THISTLE_STORE'))
