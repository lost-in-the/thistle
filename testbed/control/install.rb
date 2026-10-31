# frozen_string_literal: true

require_relative 'profile'
require 'rubygems/package'
HostProfile.activate
inputs = '/input/artifacts'
home = '/work/gems'
unless File.exist?(File.join(home, 'installed.json'))
  # No gem install, build hooks, client compilation, or network. Exact original
  # source gem and spec plus already-built native are explicitly supplied.
  %w[core map].each do |name|
    package = Gem::Package.new(File.join(inputs, "#{name}.gem"))
    spec = package.spec
    package.extract_files(File.join(home, 'gems', spec.full_name))
    FileUtils.mkdir_p(File.join(home, 'specifications'))
    spec_path = File.join(home, 'specifications', "#{spec.full_name}.gemspec")
    if name == 'core'
      FileUtils.cp(File.join(inputs, 'core.gemspec'), spec_path)
      # Ordering matters: DIRECT original spec -> raw native -> complete marker
      # -> clear_paths -> find_by_name. Never lookup the incomplete extension.
      original = Gem::Specification.load(spec_path) or raise 'Original spec invalid'
      raise 'Core spec mismatch' unless original.full_name == spec.full_name
      extension = File.join(original.extension_dir, 'thistle')
      FileUtils.mkdir_p(extension)
      native = File.join(extension, 'thistle_native.so')
      FileUtils.cp(File.join(inputs, 'native.so'), native)
      expected = HostProfile.config.fetch('artifacts').fetch('native.so')
      raise 'Restored native changed' unless Digest::SHA256.file(native).hexdigest == expected.fetch('sha256') && File.size(native) == expected.fetch('size')
      File.write(File.join(original.extension_dir, 'gem.build_complete'), '')
    else
      File.write(spec_path, spec.to_ruby)
    end
  end
  Gem.clear_paths
  %w[thistle thistle-map].each { |name| Gem::Specification.find_by_name(name, '= 0.1.0.pre.3') }
  HostProfile.write(File.join(home, 'installed.json'), HostProfile.config.fetch('artifacts'))
end
raise 'Installed artifact drift' unless JSON.parse(File.read(File.join(home, 'installed.json'))) == HostProfile.config.fetch('artifacts')
HostProfile.identities(client: true)
