# frozen_string_literal: true

require_relative 'lib/thistle/map/version'

Gem::Specification.new do |spec|
  spec.name = 'thistle-map'
  spec.version = Thistle::Map::VERSION
  spec.authors = ['Leah Armstrong']
  spec.summary = 'Read-only investigation views for captured Thistle evidence'
  spec.description = 'Private implementation preview: generation-pinned source, search, links and coverage views.'
  spec.required_ruby_version = '>= 3.4'
  spec.files = Dir.chdir(__dir__) { Dir['lib/**/*.rb', 'assets/*', 'docs/*.md', 'docs/*.json', 'examples/*.ru', 'README.md', 'CHANGELOG.md', 'LICENSE*'] }.sort
  spec.require_paths = ['lib']
  spec.license = 'Nonstandard'
  spec.metadata['allowed_push_host'] = 'https://invalid.example'
  spec.add_runtime_dependency 'thistle', '= 0.1.0.pre.1'
  spec.add_runtime_dependency 'rouge', '>= 4.5', '< 5'
end

