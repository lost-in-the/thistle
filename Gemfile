source "https://rubygems.org"
gemspec
require "json"
ci_policy = JSON.parse(File.read(File.join(__dir__, ".github/ci-policy.json")))
gem "rake", "~> 13.0"
gem "minitest", "~> 5.0"
gem "railties", ENV.fetch("THISTLE_RAILS_VERSION", ci_policy.fetch("primary").fetch("rails"))
gem "rouge", "~> 4.6"

