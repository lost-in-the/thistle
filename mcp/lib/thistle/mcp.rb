# frozen_string_literal: true

# Optional adapter entry point. Core, Map and the SDK are not loaded here.
require_relative 'mcp/version'
require_relative 'mcp/limits'
require_relative 'mcp/tools'
require_relative 'mcp/session'

module Thistle
  module MCP
  end
end
