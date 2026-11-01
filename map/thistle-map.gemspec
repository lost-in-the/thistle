# frozen_string_literal: true

require_relative 'lib/thistle/map/version'

Gem::Specification.new do |spec|
  spec.name = 'thistle-map'
  spec.version = Thistle::Map::VERSION
  spec.authors = ['Leah Armstrong']
  spec.summary = 'Read-only investigation views for captured Thistle evidence'
  spec.description = 'Private implementation preview: generation-pinned source, search, links and coverage views.'
  spec.homepage = 'https://github.com/lost-in-the/thistle'
  spec.required_ruby_version = '>= 3.4'
  spec.files = Dir.chdir(__dir__) do
    # Installed presentation contract and required reuse provenance.
    installed_docs = %w[docs/MODELS.md docs/REUSE.md docs/investigations.md docs/source-comprehension.md docs/job-mail-template.md docs/route-actions.md docs/passage.md docs/model-neighborhood.md docs/model-reading.md]
    installed_docs.each do |path|
      raise "Missing installed document: #{path}" unless File.file?(path)
    end
    Dir['lib/**/*.rb', 'assets/*', 'examples/*.ru', 'README.md', 'CHANGELOG.md', 'LICENSE*'] + installed_docs
  end.sort
  spec.require_paths = ['lib']
  spec.license = 'Nonstandard'
  spec.metadata['allowed_push_host'] = 'https://invalid.example'
  spec.add_runtime_dependency 'thistle', '= 0.1.0.pre.3'
  spec.add_runtime_dependency 'rouge', '>= 4.5', '< 5'
end

