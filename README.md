# Thistle

> **Very early alpha — not recommended for use.** Thistle is an experimental
> development project, not ready for production or general use. Its interfaces,
> storage formats and behavior may change. Results and supported environments
> are still being verified; do not rely on it for important decisions.

Thistle is a Rust evidence engine packaged as a Ruby gem, with a thin Ruby layer
for explicit Rails introspection. This is an early implementation
milestone of the [reviewed product plan](https://chatgpt.com/space/page_83d1d4a1a4ec81918d7310c21061c4e4).
It is not yet a launch replacement for Woods and makes no comparative speed claim.

The repository [mission](https://github.com/lost-in-the/thistle/blob/main/docs/MISSION.md) defines the governing product goals. Contributors
and agents should use the [workflow](https://github.com/lost-in-the/thistle/blob/main/docs/development/agent-workflow.md) and
[portable configuration guide](https://github.com/lost-in-the/thistle/blob/main/docs/development/agent-configuration.md).

The engine handles static capture using Prism's established parser, validates
fact and source identities, publishes immutable generations, and answers queries.
It does not execute the inspected Ruby files. The Ruby bridge exchanges bounded
JSON batches, releases the GVL during Rust work, and always frees native response
buffers. There is no Ruby engine fallback.

Capture uses vendored Prism 1.9.0 in its guarded CRuby 4.1 compatibility
mode, independent of the host Ruby. Capture metadata records this mode and
parser policy; older manifests without those fields have an unknown grammar.
This mode does not establish complete Ruby 4.1 language or host support.

## Build the alpha source gem

Source development supports Linux and macOS with Ruby 3.4 or 4.0 and Rails 8.1 integration. The
primary and minimum CI pairs, including exact patches, live in
[`.github/ci-policy.json`](https://github.com/lost-in-the/thistle/blob/main/.github/ci-policy.json); the Gemfile reads that same
Rails default. See the [platform setup guide](docs/development/platforms.md) for
native macOS, Linux, a dedicated Docker environment and installation into a Rails
application. Both gems require Ruby 3.4 or later. Use Rust 1.90.0, a C compiler,
Ruby development headers and libclang 18. Cargo dependencies are vendored and
locked for offline source-gem builds. Public platform qualification and
precompiled gems remain launch work; passing these development cohorts does not
qualify other Ruby/Rails combinations or platforms.

The [CI policy decisions](https://github.com/lost-in-the/thistle/blob/main/docs/development/decisions.md) explain the selected
cohorts, their maintenance policy, and the separate historical experiment profile.
For repository contributions, use [one fragment per change](https://github.com/lost-in-the/thistle/blob/main/docs/development/changelog.md).

```sh
bundle install
bundle exec rake test native map
bundle exec rake installed
gem build thistle.gemspec
gem install --local thistle-0.1.0.pre.3.gem
```

If libclang is installed in a nonstandard directory, set `LIBCLANG_PATH` to its
directory. `THISTLE_CARGO` may identify a specific Cargo executable. Source builds
must use the locked vendored dependencies; a build that cannot find them fails.
This development package deliberately refuses public RubyGems publishing.

Installed packages include the platform guide and the tagged-call, loaded-model,
callback, Find, route-constraint and model-reference contracts in
`docs/development/`. Contributor policy, the launch ledger and historical
validation records remain in the repository; these packages do not qualify any
launch requirement.

## Inspect source

```sh
thistle capture ./my-app --output ./my-app/.thistle
thistle find OrdersController --store ./my-app/.thistle
thistle model-brief MODEL_ID --store ./my-app/.thistle --generation GENERATION_ID
thistle source FACT_ID --store ./my-app/.thistle
thistle links FACT_ID --store ./my-app/.thistle
thistle check --store ./my-app/.thistle
```

For larger source trees, opt in to a higher traversal budget with
`thistle capture ./my-app --output ./my-app/.thistle --max-nodes 3000000` or
`Thistle.capture(root: path, output: store, limits: { max_nodes: 3_000_000 })`.
The default is 1,000,000 visited nodes and the provisional ceiling is 5,000,000;
other limits retain their defaults and ceilings. This counts nodes visited by
extraction after Prism parses each file, not all parser nodes. It is not a parser
stack or process-memory limit. A limit refusal publishes no new generation.
New captures record effective limits and visited nodes in their producer metadata;
older captures do not acquire this metadata retroactively.

New captures use snapshot schema 3, with `producer.call_target_schema: 2`
and `producer.link_encoding_schema: 1`. Capture and Reader APIs return semantic
call-link objects. Their `thistle_call` extension remains
`{version: 2, data: [kind, name, omitted_limit, safe_navigation,
[start_byte, end_byte, start_line, end_line], receiver_location_or_null]}`;
the receiver location uses the same four-coordinate tuple. On disk, schema 3
may encode an eligible static unresolved call link as `[0, target, data]`.
Other links retain their complete objects. The Reader retains stored rows and
materializes semantic objects only for requested responses. Call targets,
unresolved labels, grouping and captured source bytes retain their meaning.

Consumers must use the manifest's `schema_version` to interpret stored evidence.
Schema 1 treats extension versions other than 1 as opaque, including an otherwise
valid compact-looking version 2. Schema 2 recognizes strict metadata versions 1
and 2; schema 3 additionally recognizes the tagged storage rows. Producer metadata
never selects a format. See the [tagged-call contract](docs/development/tagged-call-encoding.md).

Explicit `Store#publish` uses the capture's `schema_version` selector. An absent
selector means legacy schema 1. Explicit schema-1/2 publication keeps its legacy
representation and generation identity rather than migrating it. Unsupported or
malformed selectors are refused. New readers retain old generations; engines
that support only schema 1/2 refuse schema-3 stores. Use the matching Core and Map
`0.1.0.pre.3` pair for new stores and call display.

Commands return JSON. Errors return structured JSON on stderr and a nonzero exit.
`thistle help` describes the stable literal action names. Every query identifies
its generation; pass `--generation ID` to revisit the same captured evidence.
Missing generations are refused, never replaced silently with current results.

```ruby
require "thistle"
reader = Thistle::Reader.new("./my-app/.thistle")
begin
  facts = reader.find("OrdersController", limit: 20)
  source = reader.source(facts.first.fetch("id"))
  puts source.fetch("content")
ensure
  reader.close
end
```

`Source` returns the full captured file with its digest and the selected fact's
byte/line location. Links remain explicitly unresolved unless evidence resolves
them. `Check` verifies captured bytes; it does not assert live source or Rails
freshness. Coverage distinguishes unavailable and partial families from empty
successful results.

For a saved `rails_model` ID selected through Find, `model-brief` returns a bounded
investigation brief: recorded fields/associations, incoming/outgoing label references
and registered-callback candidates with source-supported potential requests. Pass
`--generation` explicitly; `--limit` defaults to 8 per family (1–16), and
`--max-bytes` defaults to 32768 (at most 65536, including the JSON newline).
Unknown binding, partial capture, omissions and unsearched evidence remain explicit.
Follow the returned fact IDs and source anchors using the same generation.
The [loaded-model contract](docs/development/loaded-model-evidence.md#model-investigation-brief)
describes its evidence and work limits. Ruby exposes the same operation as
`reader.model_brief(model_id, limit: 8, max_bytes: 32768)` on its pinned handle.

## Observe an already booted Rails application

Run this explicitly in the application's trusted runner process:

```ruby
require "thistle"
Thistle.capture(root: Rails.root.to_s,
                output: Rails.root.join(".thistle").to_s,
                rails: Rails.application)
```

Rails observations inherit the application's authority. The current route batch
records observed runtime facts and unknown source/runtime coherence. It does not
fabricate source positions, prove immutable application boot, or claim that a
route is callable without constraints. Static capture never boots Rails itself.

## Optional Map

Map can [collect and reopen a small investigation](map/docs/investigations.md)
using one saved generation and up to 24 selected fact IDs. Ordinary GET links
support collecting, removing and reopening evidence without JavaScript. The
focus URL carries only the generation and IDs and grants no access; recipients
need an authorized Map mount with that saved capture. Missing evidence and
uncertainty remain explicit. Source opens captured bytes at the pinned
generation even after CURRENT changes. This requires the matching Core with
the bounded [fact identity operation](docs/development/fact-identity.md).

`map/` contains an independent read-only companion gem. It uses Thistle's reader
API and an approved source-view component from Woods Map. It has no Woods runtime
dependency. Its [repository README](https://github.com/lost-in-the/thistle/blob/main/map/README.md) covers local mounting, access boundaries and keyboard use.

## Trust and lifecycle

Only one writer publishes a store at a time. Content and manifests are validated
before the atomic current-generation pointer changes. Failures before that change
preserve the last published generation. A directory-sync failure after the change
returns `commit_uncertain`: reopen the store because a new generation may already
be current, with crash durability unconfirmed. Store files use restrictive creation modes and
descriptor-anchored filesystem access refuses symlinks and non-regular files.
Readers pin immutable facts and verify source bytes when expanded or checked.

The current milestone retains generations and source blobs until the user removes
the entire store. Automated retention, quotas and recovery after power loss are
not yet qualified. Do not treat content digests as signatures or authorization:
someone who can replace a whole store can author another internally consistent
store. Protect it like source code.

The native reader registry has bounded handle and encoded-data budgets. These are
limits on serialized data, not a measured bound on native heap or process RSS. Close
readers explicitly. An engine inherited after `fork` refuses further use; start
Thistle in a fresh process. General fork support is a launch requirement.

## Evaluation and next work

The sibling `thistle-eval/` installs built gems into a fresh gem home and tests them
outside this source checkout against independently labelled fixtures, mutations,
and intentionally defective results. Local separation is not a hardened sandbox.
See the [repository capability ledger](https://github.com/lost-in-the/thistle/blob/main/docs/capability-ledger.md) for the broad unqualified launch jobs and the
evaluation/CI documents for external controller requirements.

This milestone is intended to make the architecture executable and reviewable.
Full customer-outcome parity, full reused Map integration, semantic retrieval,
incremental/watch behavior, platform distribution, user studies and comparative
launch qualification remain explicit gates in the reviewed plan.

