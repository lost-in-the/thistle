# Loaded model evidence component (#73)

This bounded component observes already loaded Active Record models when the
caller supplies an already booted Rails application to `Thistle.capture`. It
supports the current Rails 8.1.4 development cohorts in `.github/ci-policy.json`.
It does not qualify L02 or any other launch row. Root integrates the component;
Leah accepts the complete journey.

## Observation and meaning

`Thistle::ModelObserver.new(limits:, evidence_budget:).call` produces version 1
primitive observations. The scope is **all currently loaded descendants of
ActiveRecord::Base in that process**, including abstract, anonymous, engine and
STI classes. It does not restrict that inventory to the supplied source root,
boot/eager-load/reload the application or resolve association targets. Inventory
absence, unsupported Active Record versions and unavailable families are explicit.
It does not install an executor/reloader callback.

Each model records its name, base and superclass labels, abstract flag, table,
primary key (including composite arrays), inheritance column, raw database
columns and separate named effective association reflections. `items` and
`payments` remain two records even when both use `has_many`. Ruby attribute
overrides/defaults, ignored-column policy, scopes, callbacks, indexes, concerns
and record behavior are outside this observation. Raw schema reads may use the
application's configured database connection/schema cache; adapter or connection
failures leave columns unavailable while preserving association observations.
No records are queried or instantiated.

Only exact primitive database defaults are copied; unsupported objects are
opaque and default functions are marked as expressions without their expression
text. Ruby attribute defaults are never read. Opaque option values are not
stringified, inspected, traversed or evaluated. Declared association options
have a fixed allowlist; other options are counted as omitted. Arrays or complex
option values are opaque. Scope presence is recorded without calling the scope.
The model family's overall coverage remains partial, even if all currently
loaded classes could be observed.

Reflection targets and base/superclass names are labels, not proof of dispatch,
binding, target existence or membership in this capture. Ordinary association
class-name labels may be Rails-inflected names. Through associations retain their
through label and only an explicit `class_name` target; asking Rails to infer the
through target can load another class. Polymorphic targets remain unknown.

Rust's `model::append(capture: Value, observation: &Value) -> Result<Value>`
validates the input, emits `rails_model` runtime facts under `attributes.model`
version 1, assigns ordinal-based snapshot-local identities, emits separate
unresolved labelled links, and admits the combined static/route/model facts.
The identity is only meaningful with the generation; it does not identify an
object across reloads, processes or captures. Same-name loaded classes remain
separate ordinal facts. Model facts have **null path/location**, explicit source
unavailable, and unknown runtime/source coherence. Matching a static declaration
name cannot establish the loaded implementation's source. Static captured source
remains separately accessible via its own facts.

Model schema validation runs on both publication and Reader opening. It rejects
malformed/unknown model versions, extra opaque payloads, duplicate family names,
invalid provenance, invented resolved links and inconsistent model identities.
It uses existing max_facts, max_links, max_entries, max_diagnostics and 64 MiB fact
budgets, with no raised caps. Ruby bounds each observed entry and the accumulated
batch before sending JSON; Rust independently validates and admits the combined
capture. Publication is never attempted after refusal.

## Integrated adapters

Root added `mod model`, the `append_models` dispatch and the model presenter hook
in `4ac02431a01e7b07e3e66ec1b0a9c5a21d46b06a`, then combined integrated schema-2
main `7633b2b03ada60f6ba112c144702bc662210f27d` in candidate
`76f7d2197f25902e96a18e2ea3ad100d5ba8f053`. The native dispatch takes the
request-owned capture and observation, then calls `model::append(capture,
&observation)`. No Ruby-owned buffer crosses or outlives the FFI call. Existing
`fact_tiles` appends `ModelPresenter.render(fact)` on Source (including its
source-unavailable fallback) and Links. Schema-2 contextual call validation and
legacy snapshot behavior remain in place.

The focused execution below establishes the composed source journey. Independent
review, settled installed acceptance, shared docs/version reconciliation and
Leah's acceptance remain separate. The model writer did not edit `schema.rs`
during resumed validation; its diagnostic-helper ownership belongs to #75.

`ModelPresenter.render(fact)` emits escaped HTML for model facts, and an empty
string for other facts. It shows bounded column and association tables, unknowns,
source context and truncation. It does not need additional routes, JavaScript,
Reader methods, CSS, or a dependency on the Find implementation. Tables use
existing scroll/focus styling and work without JavaScript.

## Library fit and maintenance

Use Rails' maintained reflection and schema APIs instead of building a textual
macro extractor or copying Woods code. The Ruby shim observes only; existing
serde/JSON, schema, store and Reader contracts handle core evidence. There are no
new Cargo or runtime gem dependencies. The development Gemfile adds Active Record
at the same CI Rails version plus maintained sqlite3 2.x for an independently
declared, in-memory schema fixture. A fake adapter alone would not verify real
schema/default/STI/reflection interactions. SQLite is a fixture cohort, not an
all-adapter support claim. Reconsider version guards when Rails changes these
metadata APIs; verify behavior before adding a version to the allowlist.

Primary sources checked for Rails 8.1.4:

- [Inheritance API](https://api.rubyonrails.org/v8.1.4/classes/ActiveRecord/Inheritance/ClassMethods.html): base/abstract semantics.
- [ModelSchema API](https://api.rubyonrails.org/v8.1.4/classes/ActiveRecord/ModelSchema/ClassMethods.html): effective column defaults differ from raw schema.
- [Rails reflection source](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/reflection.rb): named reflections; through target inference can call `klass`.
- [Rails schema cache](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/connection_adapters/schema_cache.rb) and [column metadata](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/connection_adapters/column.rb): raw defaults and schema reads without model attributes.
- [sqlite3-ruby](https://github.com/sparklemotion/sqlite3-ruby): maintained embedded fixture adapter.

The coordinator can record this fit decision in shared development decisions at
integration; that file is outside this writer's ownership.

## Verification and remaining gates

Initial component preparation was source/static only under the #70/Find host
leases. Hosted component run `40910171169` on `8a68f154` failed at missing native
registration. Later wired run `40912831415` on `4ac0243` compiled successfully but
failed the observer test's singleton setup on a frozen String literal in both
Ruby cohorts. Both failures remain historical; neither is reclassified as a
passing test or a missing toolchain.

The resumed test fix uses a mutable **exact String** for the singleton `encode`
and `to_json` canaries; it preserves the no-dispatch checks. The real fixture now
also guards the through reflection's `klass`, asserts partial/unavailable
coverage, and supplies Map's producer. Map reopens that saved generation without
Rails, after a newer generation has published, through ordinary Source/Links.

Offline copied-source validation used root input `76f7d219` plus these three
changed tests (no runtime implementation change). Final input archive SHA-256:
`61444efd27f712bc16a176eed080583ad8e6168de0f08767fff66c43cbe064cd`;
per-file SHA-256 manifest:
`7b8da1e4da1494452959c6607dc8d1ea6c3506c479d3dec3e38ddbac77691c32`.
The later edit to this document is not part of those tested archive bytes.

The rootless retained image was
`f377fb86ef51f1b4b31787dc58131ad453fe306e58b36296f29e76a98487c520`:
Ruby 3.4.12, Rails/Active Record 8.1.4, Rust 1.90.0, libclang 19, Rouge 4.6.1,
sqlite3 gem 2.10.2 (SQLite 3.54.1). The upstream SQLite gem was copied from the
existing dependency cache and installed offline; SHA-256
`ca92731ab464df9cae503fa1a439a549e2724f6953c8c05a7769b59366e38f15`.
No Woods implementation was copied. This is the minimum CI Ruby cohort; it does
not replace hosted primary-cohort evidence or widen supported versions.

Execution used 2 CPUs, 2 GiB memory, zero swap and 256 PIDs, verified inside the
worker; child Ruby/Python resolved task-private disk-backed `/work/tmp`. The
worker had no network, host home, Git metadata, credentials, evaluator-policy or
socket mounts. Container/outer deadlines were 600/630 seconds, and output was
capped at 8 MiB. Only copied source/dependencies/build output were writable.

Attempts 1–2 stopped before candidate compilation: Rustup attempted to update
its read-only image location, then an incomplete process-local GEM_PATH hid
bundled Minitest. Explicit selection of the installed Rust toolchain and inclusion
of the image's bundled-gem path fixed setup. Attempt 3 passed 4 native model tests,
4 Core model tests/40 assertions and 3 initial Map tests/44 assertions. Attempt 4
used the stronger real-application Map test and ran the affected guards once:

- `cargo test --locked --offline --manifest-path engine/Cargo.toml -- --test-threads=2`: 36 passed, including model identity, admission, buffer ownership, schema-2 and opaque legacy identity.
- `rake unit` using the extension built by `rake compile`: 40 tests, 347 assertions.
- `ruby -Ilib -Imap/lib -e 'gem "rouge", "4.6.1"; Dir["map/test/*_test.rb"].sort.each { |file| require_relative file }'`: 41 tests, 755 assertions.

All final test groups had zero failures/errors/skips. The final log SHA-256 is
`3997584ca184d78803ace0dd8fd76e009ec17a36264270ec4b31cb4b0d92f672`.
Source archives, manifests, command arrays, all attempt logs and the built native
artifact are retained privately with the coordinator's technical handoff.
This is source validation, not installed-artifact qualification. No unchanged
build/suite was rerun after that success, and the runtime lease was released.

Next: independent scoped review must converge, then Root schedules the settled
exact installed Core/Map contracts, parser/reader-boundary probes and Map smoke.
Current hosted required lanes still apply. No release-candidate or private-app
campaign, benchmark, frozen-policy change or publication was run here.

Finite implementation review: this path adds one full bounded JSON request/response crossing, linear model/column/reflection traversal and validation, and
snapshot facts charged through existing Reader admission. There is no persistent
model cache or application-object retention after capture, and no per-association
target loading. Guarded error handling retains family unavailability without
serializing application exception text. The Map display cap avoids rendering all
rows but does serialize the model to check its size. These are operating costs,
not measured performance results. The minimum-cohort source journey now passes; independent review, current
hosted lanes and settled installed evidence remain substantive outstanding checks.

### Owned capture integration correction

Root removed the avoidable whole-capture Rust deep clone: append consumes the
JSON request-owned capture and returns that same allocation with the bounded
model batch appended. Existing source content and fact allocations are moved,
not duplicated. A focused allocation-identity regression checks retained source
buffers. Combined validation/admission still runs before publication; a failed
request yields no result or publication. Ruby caller values remain separate
from the native request representation. This does not remove the full
Ruby/native request/response serialization or the existing validation/accounting
work, and establishes no timing/RSS result.

This root correction passed the focused minimum-cohort source checks above after
the Find build lease released. The original failed component CI
40910171169 remains recorded; no test result transfers to the corrected head.

### Integrated schema context

Root reconciled the component with integrated schema-2 main 7633b2b0. The
additive model validator remains in the facts path, alongside the unchanged
contextual call validator. Both legacy schema-1 behavior and schema-2 tests
are retained. append moves the capture's explicit schema context unchanged.
This composition passed the source checks above; independent review and installed
checks remain outstanding.
