# frozen_string_literal: true

module ThistleTestProcess
  # Darwin rejects setting RLIMIT_AS. Keep the CPU and external wall deadlines;
  # the Linux lane additionally enforces the address-space ceiling. These known
  # regressions are not a hostile-input sandbox or macOS memory qualification.
  LIMITS = {
    rlimit_core: 0,
    rlimit_cpu: [10, 10],
    **(RUBY_PLATFORM.include?("linux") ? { rlimit_as: [2 * 1024**3, 2 * 1024**3] } : {})
  }.freeze
end
