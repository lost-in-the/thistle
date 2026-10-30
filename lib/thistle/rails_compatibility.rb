# frozen_string_literal: true

module Thistle
  # Exact observation layouts, not a general Rails/adapter support promise.
  # Native admission maintains its own independent allowlist.
  module RailsCompatibility
    OBSERVATION_VERSIONS = %w[7.1.6 8.1.4].freeze
  end
end
