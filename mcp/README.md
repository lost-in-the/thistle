# Thistle local MCP Reader

Optional local stdio source for investigating **one explicitly selected saved
Rails generation** through Find, model Brief, Links/references, Source and Check.
Rust owns analysis, identity, indexing and validation; the Ruby adapter preserves
Reader answers and adds protocol/session admission. Captured text is data, never
agent instructions. The application is not loaded.

Status: source implementation and pure-double checks only. SDK transport, native,
package/install and actual Codex/Claude investigation acceptance remain **UNRUN**.
All 17 launch requirements remain unqualified. These five initial tools are a
first delivery, not the eventual Woods-comparable investigation ceiling.

The intended optional internal package uses Ruby >= 3.4, matching Core and the
official Ruby MCP SDK pinned to `mcp = 1.8.2`. Package/dependency manifests and
setup are a separate integration-owner change; this source does not provide an
installable gem yet. Core and Map do not require the adapter or SDK.

After separately authorized packaging/installation, the proposed invocation is:

```sh
thistle-mcp --store ./saved-evidence/store --generation SAVED_GENERATION_SHA256
```

Both arguments are mandatory. Missing/unavailable generations refuse; there is
no CURRENT fallback. The store is startup configuration, never a tool argument.
No HTTP listener, capture, refresh, app boot, live records, evaluation, Console,
shell tool or provider credentials are supplied. Protect the local store and the
client that receives its source with the same care as the application source.

Read the [tool and lifecycle contract](docs/local-reader.md) and the
[authored acceptance cards](test/fixtures/los146_reader/README.md). The secret-free
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
