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

Rust's `model::append(capture: &Value, observation: &Value) -> Result<Value>`
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

## Root integration request

The isolated component intentionally does not edit the shared native module /
dispatch or existing Map view files. After the Find writer releases those paths:

1. In `engine/src/lib.rs`, add `mod model;`, and the dispatch arm:
   `"append_models" => model::append(&request["capture"], &request["observation"]),`.
2. In the existing Map view, require `model_presenter`, then append
   `ModelPresenter.render(fact)` once to the return value of `fact_tiles`.
   This covers Source (including its source-unavailable fallback) and Links.
   Keep the current generation, authorization, reader lifecycle and navigation.
3. Reconcile the additive schema validation with the integrated #71 schema-2
   implementation; preserve its schema version and grouping behavior. The
   component itself was prepared on the assigned schema-1 base.
4. Reconcile shared documentation/version metadata as the integration owner.
   Do not claim that the component alone has a working native dispatch or Map
   route. The integration test deliberately requires the adapters and will fail
   without them; there is no skip or Ruby fallback.

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

The #70 benchmark lease forbids native compilation, Rails boots and workloads
during this component's preparation. Ruby syntax and diff/fragment checks are
static evidence only. Runtime tests and numerical performance claims are unrun.
One intermediate Ruby syntax check caught a missing closing parenthesis in the
entry accounting edit; it was corrected and the syntax check passed. The host
has no `rustfmt` command; Rust parsing/typechecking remains unverified.

After explicit lease release and adapter composition, run the focused native
model tests, `test/test_model_observer.rb`, `test/test_models.rb`, and the two new
Map model tests in the existing credential-free copied-source worker. The real
fixture boots Rails, declares independent SQLite schema, installs raising scope,
default, callback and business-method canaries, captures, publishes, and opens a
fresh Reader process without Rails. Assertions cover ordinary/STI labels,
columns/defaults, two has-many records, belongs-to, through/polymorphic unknowns,
missing table, no guessed source, and publication preservation on refusal. Map
integration consumes the saved normalized model through its ordinary routes.

Then run affected native/Ruby/Map required CI lanes on the settled integrated
head, both current Ruby cohorts for the dependency/native interface changes,
installed Core contracts, native/parser and reader-boundary regressions, and
exact-pair Map smoke. Missing or failed checks are not accepted evidence. Keep
#71's fixed acceptance candidate unchanged. No full private application campaign,
new benchmark, frozen-policy change or release publication belongs to #73.

Finite implementation review: this path adds one JSON crossing and a bounded
capture clone, linear model/column/reflection traversal and validation, and
snapshot facts charged through existing Reader admission. There is no persistent
model cache or application-object retention after capture, and no per-association
target loading. Guarded error handling retains family unavailability without
serializing application exception text. The Map display cap avoids rendering all
rows but does serialize the model to check its size. These are operating costs,
not measured performance results. Runtime API/typecheck compatibility and full
adapter composition remain substantive outstanding checks.
