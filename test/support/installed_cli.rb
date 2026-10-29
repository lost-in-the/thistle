# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"
require "rubygems"
require "tmpdir"
require "rbconfig"

Dir.mktmpdir("thistle-cli-", File.realpath(Dir.tmpdir)) do |directory|
  root, store = %w[source store].map { |name| File.join(directory, name) }
  FileUtils.mkdir_p(root)
  content = "class PortableBasket; def count; items.length; end; end\n"
  File.write(File.join(root, "Basket_é.rb"), content)
  cli = Gem.bin_path("thistle", "thistle")
  call = ->(*args) do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, cli, *args)
    raise "CLI #{args.first} failed: #{stderr}" unless status.success?
    JSON.parse(stdout)
  end
  generation = call.call("capture", root, "--output", store).fetch("generation")
  options = ["--store", store, "--generation", generation]
  found = call.call("find", "PortableBasket#count", *options).fetch("results").first
  raise "Installed CLI did not find the method" unless found && found["kind"] == "method"
  source = call.call("source", found.fetch("id"), *options)
  raise "Installed CLI changed source" unless source.fetch("content") == content
  raise "Installed CLI lost generation" unless source.fetch("generation") == generation
  call.call("links", found.fetch("id"), *options)
  raise "Installed CLI Check failed" unless call.call("check", *options).fetch("integrity") == "verified"
  puts JSON.generate(status: "passed", scope: "installed CLI Find/Source/Links/Check")
end
