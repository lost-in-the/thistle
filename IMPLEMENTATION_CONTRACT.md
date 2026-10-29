# Thistle first implementation contract

This is the first private implementation milestone of the approved [product plan](https://chatgpt.com/space/page_83d1d4a1a4ec81918d7310c21061c4e4). It does not establish launch parity or production readiness. Do not read or reuse Woods engine implementation. Map code/assets may be reused with provenance. **Owner clarification during implementation: the core must be Rust.** This supersedes the earlier conditional-Rust reference-implementation choice. Rust owns static capture, validation, indexing, storage and queries; Ruby is the gem/Rails facade. Do not ship a Ruby engine fallback.

## Ownership

- Root: core package, canonical validation, snapshot store/reader, CLI, integration and self-inspection.
- Capture agent: `engine/src/capture.rs`, thin `lib/thistle/capture.rb`, `lib/thistle/rails_capture.rb`, capture-specific tests/fixtures. Rust uses established Prism through ruby-prism bindings, not a new parser.
- Map agent: `map/` optional gem, including provenance, its tests, integration contract.
- Evaluator agent: sibling `../thistle-eval/`, core `.github/`, baseline capability ledger and independent artifact evaluation docs/tests.
- Coordinate contract changes before modifying another owner's files.

## Data contract v1

`Thistle::Capture.new(root:, rails: nil, limits: {}).call` returns a JSON-safe Hash with string keys: `root_id`, `files`, `facts`, `coverage`, `diagnostics`, `producer`.

`files` entries contain `path` (relative POSIX, no traversal), `sha256`, `bytes`, `encoding`, `content` (UTF-8 source). Files whose original encoding cannot safely round-trip to JSON are explicitly unavailable or normalized with original digest and documented byte mapping; do not fabricate offsets. Root persists source separately. Capture may use Prism but must not evaluate application code for static inspection. Runtime inspection is explicit via `rails:` and only uses the supplied trusted application.

Each fact contains `id` (SHA-256 stable identity), `kind`, `name`, `path` (relative or null), `location` (null or `start_line`, `end_line`, `start_byte`, `end_byte`), `evidence` (`static` or `runtime`), `attributes` (Hash), `links` (Array). A link contains `relation`, `target` (symbolic name), `resolution` (`unresolved` unless actually verified). Facts need source provenance through path/digest; runtime facts with no reliable source are explicitly null. IDs can use `Digest::SHA256.hexdigest(JSON.generate([producer,kind,name,path,start_byte]))`. No global complete call-graph claims.

Native Ruby capture records Prism version, guarded Ruby 4.1 compatibility mode and parser policy in the producer, Ruby declaration coverage, and syntax diagnostics. The producer is part of generation identity. Missing grammar metadata in older manifests means unknown; generic captures need not supply it. This mode does not claim complete Ruby 4.1 language or host support.

New native captures record effective limits and post-parse visited extraction nodes in producer metadata. The `max_nodes` default is 1,000,000; explicit values up to the provisional 5,000,000 operational ceiling are accepted. Other ceilings remain their existing defaults. This budget does not bound parsing, stack usage or RSS; legacy manifests are not backfilled.

Coverage entries: `family`, `status` (`complete`, `partial`, `unavailable`), `scope`, `reason` (null permitted). Every capture records unsupported dynamic resolution and no execution trace. Diagnostics: `code`, `message`, optional `path`. Limits must produce explicit incompleteness or refusal, never silent truncation. Source paths/symlinks cannot escape root. Ignore .git, .thistle, vendor, node_modules and tmp by default; describe scope.

## Public core contract

- `Thistle.capture(root:, output:, rails: nil, limits: {})` captures and publishes, returns a manifest Hash.
- `Thistle::Store.new(path).publish(capture)` atomically publishes one immutable generation. `Reader.new(path, generation: nil)` pins one generation.
- Reader: `manifest`, `facts`, `find(query, limit: 50)` returns matching facts, `fact(id)` returns fact or raises, `source(id)` returns `{generation, fact, content, sha256}`; `links(id)` returns labelled unresolved/resolved links, `check` returns explicit coverage/identity status.
- `generation` is a digest of canonical semantic payload. Manifest includes schema version, root identity, facts/source hashes, generation, producer and coverage. Unknown schema/digest corruption/path escapes fail closed.
- Map can depend on core Ruby API above; it cannot depend on Woods, run arbitrary commands or expose an execution interface. Visible actions: Find, Source, Links, Check; human-readable labels, optional focus-scoped keys, no shortcut activation in inputs.
- CLI: `thistle capture ROOT --output STORE [--max-nodes INTEGER]`, `thistle find QUERY --store STORE [--generation ID] [--limit N]`, `source ID`, `links ID`, `check`, `version`. JSON on stdout; diagnostics/errors on stderr; nonzero errors. CLI does not boot Rails implicitly.

## Verification

Independent evaluator installs built .gem artifacts in a clean GEM_HOME, runs commands from outside the gem source checkout, controls expected fixture facts and mutations, and rejects corrupted/omitted/stale candidate results. Initial tests need real Ruby parsing, two dissimilar evidence families including real Rails if the dependency can be installed, generation pinning, failed-publication isolation, path handling, CLI failures, and read-only Map behavior. Report precise tested runtime/package tuples. A test harness sharing a filesystem with candidate code is not a hardened sandbox; production CI authority remains separately owned.

## Delivery constraints

Use Ruby 3.0-compatible facade syntax where feasible and Prism >= 1.0, < 2.0 through Rust bindings. Supported platform claims await tests; local testing initially uses official Ruby 3.3.13 and pinned Rust 1.90.0. Native code is the chosen core architecture by owner direction; performance still requires measurements. New code is not automatically licensed for public distribution; record project owner and mark unreleased private work pending release metadata/license choice. Every claimed result must come from an executed check.

New static call links carry the complete method name as `target`, remain
unresolved, and may carry versioned lexical receiver syntax and representative
source locations under `attributes.thistle_call`. Source remains pinned to the
same generation. Grouped simple receivers represent a lexical summary, not a
runtime binding or every occurrence. Older snapshots keep their recorded targets;
unknown metadata versions do not imply receiver or dispatch information.
