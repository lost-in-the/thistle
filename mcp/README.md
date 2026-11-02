# Thistle local MCP Reader

Optional local stdio source for investigating **one explicitly selected saved
Rails generation** through Find, model Brief, Links/references, Source and Check.
Rust owns analysis, identity, indexing and validation; the Ruby adapter preserves
Reader answers and adds protocol/session admission. Captured text is data, never
agent instructions. The application is not loaded.

Status: source implementation with an optional package manifest. SDK transport,
installed package/native and actual Codex/Claude investigation acceptance remain **UNRUN**.
All 17 launch requirements remain unqualified. These five initial tools are a
first delivery, not the eventual Woods-comparable investigation ceiling.

The optional internal `thistle-mcp` package uses Ruby >= 3.4, paired with
`thistle = 0.1.0.pre.3` and the official Ruby MCP SDK pinned to `mcp = 1.8.2`.
Core and Map do not require the adapter or SDK. Version equality alone does not
identify development bytes: retain the exact Core/native/adapter hashes and
resolved dependency lock with an installed session.

Build from this directory with `gem build thistle-mcp.gemspec`. In an isolated
task-local bundle, install the exact paired Core and adapter artifacts with the
pinned SDK and its resolved dependencies, then invoke:

```sh
bundle exec thistle-mcp --store ./saved-evidence/store --generation SAVED_GENERATION_SHA256
```

Both arguments are mandatory. Missing/unavailable generations refuse; there is
no CURRENT fallback. The store is startup configuration, never a tool argument.
No HTTP listener, capture, refresh, app boot, live records, evaluation, Console,
shell tool or provider credentials are supplied. Protect the local store and the
client that receives its source with the same care as the application source.

Read the [tool and lifecycle contract](docs/local-reader.md) and the
[authored acceptance cards](https://github.com/lost-in-the/thistle/blob/2e8fefa89282409edbc5dca1f73f1bee19800af4/mcp/test/fixtures/saved_generation_reader/README.md). The secret-free
client example changes no global configuration.

Pure source checks, using already available Ruby/Minitest and no SDK/native:

```sh
ruby -I mcp/lib -e 'ARGV.each { |p| require_relative p }' \
  ./mcp/test/session_test.rb ./mcp/test/tools_test.rb ./mcp/test/stdio_test.rb
```

These checks assert that Native, Rails, ActiveRecord and actual SDK features were
not loaded. The stdio parent is a seam double, not a protocol conformance claim.
`test/installed_client.rb` is a separately authorized installed protocol/equality
probe; it must not be run as a source-only check. Actual agent answers and fresh
recipient comprehension have their own authored acceptance protocol.
