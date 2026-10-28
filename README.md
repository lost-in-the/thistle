# Thistle

Thistle is a Rust evidence engine packaged as a Ruby gem, with a thin Ruby layer
for explicit Rails introspection. This is a private first implementation
milestone of the [reviewed product plan](https://chatgpt.com/space/page_83d1d4a1a4ec81918d7310c21061c4e4).
It is not yet a launch replacement for Woods and makes no comparative speed claim.

The engine handles static capture using Prism's established parser, validates
fact and source identities, publishes immutable generations, and answers queries.
It does not execute the inspected Ruby files. The Ruby bridge exchanges bounded
JSON batches, releases the GVL during Rust work, and always frees native response
buffers. There is no Ruby engine fallback.

## Build the private source gem

Development targets Linux with Ruby 3.4 or 4.0 and Rails 8.1 integration. The
primary and minimum CI pairs, including exact patches, live in
[`.github/ci-policy.json`](.github/ci-policy.json); the Gemfile reads that same
Rails default. Both gems require Ruby 3.4 or later. Use Rust 1.90.0, a C compiler,
Ruby development headers and libclang 18. Cargo dependencies are vendored and
locked for offline source-gem builds. Public platform qualification and
precompiled gems remain launch work; passing these development cohorts does not
qualify other Ruby/Rails combinations or platforms.

The [CI policy decisions](docs/development/decisions.md) explain the selected
cohorts, their maintenance policy, and the separate historical experiment profile.
For release notes, use [one fragment per change](docs/development/changelog.md).

```sh
bundle install
bundle exec rake test
cargo test --locked --offline --manifest-path engine/Cargo.toml
gem build thistle.gemspec
gem install --local thistle-0.1.0.pre.1.gem
```

If libclang is installed in a nonstandard directory, set `LIBCLANG_PATH` to its
directory. `THISTLE_CARGO` may identify a specific Cargo executable. Source builds
must use the locked vendored dependencies; a build that cannot find them fails.
The private package deliberately refuses public RubyGems publishing.

## Inspect source

```sh
thistle capture ./my-app --output ./my-app/.thistle
thistle find OrdersController --store ./my-app/.thistle
thistle source FACT_ID --store ./my-app/.thistle
thistle links FACT_ID --store ./my-app/.thistle
thistle check --store ./my-app/.thistle
```

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

`map/` contains an independent read-only companion gem. It uses Thistle's reader
API and an approved source-view component from Woods Map. It has no Woods runtime
dependency. Its README covers local mounting, access boundaries and keyboard use.

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
See `docs/capability-ledger.md` for the broad unqualified launch jobs and the
evaluation/CI documents for external controller requirements.

This milestone is intended to make the architecture executable and reviewable.
Full customer-outcome parity, full reused Map integration, semantic retrieval,
incremental/watch behavior, platform distribution, user studies and comparative
launch qualification remain explicit gates in the reviewed plan.

