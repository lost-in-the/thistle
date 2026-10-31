# Saved model source comprehension — LOS-147

This source increment prepares one model/concern reading journey. Core wiring
adds optional explicit capture context, strict publication/open validation and a
Reader operation. Map route/View wiring is now present in source. Actual native
checks, installed/served evidence and independent review still belong to the
integration owner.
The installed/served journey below is **UNRUN**. All launch rows remain open.

The customer must be able to identify the file and owner to edit, read its code,
follow an exact caller or contribution and return to the same saved investigation
and search. Code is the primary surface. This is the first Field Guide increment
in the restored Woods Map replacement scope, not whole-parent parity.

## Evidence and composition

Existing static fact IDs, owner/method labels, paths and physical spans are reused.
No Woods engine, index or runtime code is used. A source fact is authoritative
about its captured text, not whether a loaded registry is running that text.

`SourceComprehensionObserver#call(models:, stop_before:)` accepts explicitly
supplied loaded classes and a stop ancestor. It uses bound builtin Module, Class
and UnboundMethod readers, including `super_method` to recover a direct row hidden
behind a prepend. It never calls a user getter, resolves a constant, autoloads,
instantiates a model, reads a database or invokes a method body. The caller owns
the explicitly supplied loaded registry; this adapter does not discover one.
Concurrent method-table mutation may refuse observation; it is not an atomic VM
snapshot. A successful observation still makes no source/runtime coherence claim.

Raw DTO v1 is `{version: 1, models: [...]}`. Each model has exactly `name`,
`status: observed`, `superclass`, `stop_before`, `ancestors`, `effective_methods`.
An ancestor has its ordinal `index`, nullable `name`, `kind: class|module`, and
direct `methods` (`name`, `visibility`, nullable `source`). Effective descriptors
have `name`, nullable `owner_index`, nullable `source`. A source hint has `path`
and positive u32 `line`. Undef gaps use null owner/source. Anonymous owners remain
anonymous. Descriptor provenance is reflection, not a captured source span.

Rust `validate_observation` checks exact fields, names, indexes, visibility,
duplicates, complete descriptor-name coverage and owner/source agreement.
`batch(context, observation, root)` uses existing `ObservationAdmission` counters
and wire-byte admission. New `rails_source_ownership` facts have no physical path
or location. Identity uses kind/version/registry ordinal/model label; duplicate
registry labels remain different facts. Absolute hints beneath the supplied root
become safe relative hints; outside/unsafe hints become unavailable. Root `/`
is deliberately refused by this initial normalizer. Hints do not certify file
presence. `validate_fact` recomputes identity and validates the DTO on publication
and open; the integration must call it in both paths.

Ruby limits: 64 ancestors before the explicit boundary; 2048 distinct method
names; caller `max_facts`, shared `max_entries`, and streaming JSON byte budget.
The observer counts owner, direct-method and effective-descriptor rows against
the same per-observation-batch entry limit that Rust admits; other families keep
their existing per-batch entry meaning. Fact/link/byte counters are incremental
across families. No old fact tree is reserialized to append this family.
Rust also caps each model DTO at 2 MiB and 100,000 direct entries before cloning;
complete batch input uses the existing 64 MiB capture ceiling. Refusal never
returns a partly accepted batch. Ruby allocates the bounded reflection rows before
the final streaming envelope check; the byte counter is not a heap/RSS bound.

| Claim | Support and explicit limit |
| --- | --- |
| As-written source | Exact saved fact/path/span; whole captured file stays unchanged. |
| Included/prepended/superclass contribution | Named observed ancestor plus saved label candidates; binding unknown. |
| Loaded owner order | Builtin ancestor/descriptor observation, before declared boundary. |
| Effective saved method | Never asserted from concatenation, labels or a hint match. |
| Duplicate/reopened definition | All eligible candidates retained, never last-one-wins. |
| Conditional include/callback | Source syntax or registered metadata; condition/execution unknown. |
| Missing Ruby body | Descriptor can exist without a saved definition/source; no invented span. |
| Empty candidate page | No candidate in this searched range; no proof of application absence. |

## Rust query and the exact shared integration

Public Reader signature (wired in this Core source checkpoint):
`source_comprehension(id, family: nil, limit: 8, cursor: nil, max_bytes: 32768)`.
`Query::parse/scratch/select` lives in the dedicated Rust module. Allowlisted
families are `contributions` (default) and `methods`; limit ceiling 16, response
ceiling 64 KiB. It accepts a saved `rails_model` or static `class` ID. Anonymous
model labels currently refuse source composition explicitly.

`contributions` traverses observed owner rows and pages their class/module
declaration candidates using `recorded_candidates`. Without a unique ownership
registry candidate, it offers direct model-label declarations with unknown
binding. The model's as-written declaration is shown first; the separately
reported observed ancestry order is preserved. `methods` traverses the observed direct method inventory, retaining
included, prepended and superclass alternatives, then pages exact owner/name
definition candidates through the existing method directory. No observed method
inventory means unknown, not an empty application. Anonymous or duplicate owner
labels remain unsupported/refused where no distinct source candidate is justified.

One response visits one owner or method row, including an empty row. The existing
`recorded_domain` cursor scope is `[source_comprehension, id, family]`; its two
positions are the owner/flattened-method ordinal and candidate offset. Cursors
cannot change generation, model or family. Callers follow `continuation`; the
selector never auto-traverses all rows or reads source. A zero-progress work
exhaustion has no looping continuation and remains partial.

The sole transferred existing-file change is additive
`method_lookup::Directory::page(facts, owner, name, offset, limit, work)` plus
`MethodPage`. Returned positions are bounded to 16; every digest/key comparison,
label byte and candidate visit uses the existing Work interface. `matches_seen`
counts witnesses, **not a total unless range_complete**. A single extra match
proves another page without consuming that match. `partial` marks Work exhaustion;
no partial page proves uniqueness. Position order is the unchanged immutable
directory slot order; deterministic pagination reuses that generation's directory.
Build/sort/key/lookup/stats/caps and callback paths are unchanged.

Core wiring now present (execution remains UNRUN):

1. Dedicated module declaration, observation/query dispatch branches and query
   scratch reservation before selection. New Rust regressions are now reachable
   from the module declaration; they have not been run in this source phase.
2. Strict `rails_source_ownership` validator in the shared fact-validation path
   used by publication and Reader open. Ruby accepts the optional keyword
   `source_comprehension: {models: [ExplicitLoadedClass], stop_before: Boundary}`
   on both `Thistle.capture` and `Capture.new`. Nil preserves the previous path;
   explicit context with `rails: nil` still takes the Ruby orchestration path.
   Configuration is snapshotted as classes and a boundary, with no discovery.
   The guarded observer runs after any existing Rails families and appends via
   native `source_comprehension_batch` with normalized root, counters, descriptor
   and coverage. Invalid context or observation/batch failure stops publication.
3. Thin public Reader request method. `select` calls indexed
   `stored_fact`, `recorded_candidates` and `with_method_directory`; no new store
   resolver is needed. The method-directory closure copies only bounded positions
   and stats. It returns before projection, Source I/O or HTML.
Map source wiring now present (App execution remains UNRUN):

1. `/comprehension/contributions` and `/comprehension/methods` use the existing
   corrected PR119 navigation authority with exact cursor/generation scope and
   one bounded Reader projection per page. Compact root identity avoids fact
   expansion. Pinned manifest file bytes are reserved before deduplicated Source
   reads; exact identity/digest/size and aggregate physical display lines are
   checked on bounded responses before highlighting. Lines are not claimed to
   be known before reading; no Core metadata change is made.
2. Code precedes the owner outline/provenance and explicit existing
   schema/association/callback/reference follow-ups. No automatic all-family or
   source expansion occurs. Original physical Source anchors and default captures
   without optional ownership coverage retain their established behavior.

Root retains shared packaging/README/gemspec/ledger/decisions synchronization,
current CI disposition, the full independent review and actual finite execution.

## Cost and alternatives

No second owner directory is retained. Existing method lookup stopped after its
second match and could not enumerate duplicate candidates; the additive page API
reuses its fixed-key index and Work contract. Recorded-directory construction is
lazy and visits/sorts the saved fact domain under its existing guards. This is
not zero whole-domain work. Reader open, lazy build and request work are distinct.
Request caps are 20,000 candidate visits, 100,000 comparisons, 32 MiB of compared
label bytes, 2 MiB per borrowed metadata input group, an 8 MiB scratch reservation,
and 32/64 KiB encoded output. Projection/serialization create bounded copies;
these accounting limits are not heap or RSS measurements. No speed claim.

Flattened method-row selection scans at most the admitted 100,000 direct rows;
it does not copy their bodies. Candidate projection is bounded by 16 output rows
and the 2048-name observed descriptor table. Method-page continuation repeats its
bounded prefix scan through the unchanged directory, charging all work again.
If this cost becomes material, reconsider a measured position-based index cursor;
do not raise caps or hide repeated work. Existing Rust/serde/Prism and the Map
highlighter suffice; no parser, renderer framework or new dependency is introduced.

## Evidence and remaining gates

Pure observer/presenter tests are runnable without Thistle/native/framework/App.
Dedicated wiring probes run isolated subprocesses with Native and framework
registry adapters stubbed before facade loading. They check unchanged nil/default
behavior, context with `rails: nil`, after-Rails incremental counters, refusal
before publication, and Reader selector/close forwarding. No native capture or
framework is executed by these probes. They are dispatch evidence, not captured
semantic or saved-generation acceptance.
Rust regressions are authored in `source_comprehension_tests.rs` and remain
**UNRUN** in this phase. The Rust toolchain is absent from the active PATH;
rustfmt preflight failed before starting its child and that attempt was retained.
No package/native/installed/served result can be inherited from another artifact.

The opt-in installed producer/consumer harness and served task protocol are in
the [Map contract](../../map/docs/source-comprehension.md). They require Root's
shared wiring and a new finite execution lease. Root owns review/check/integration;
Leah owns applicable acceptance. Self-checks do not independently qualify the work.

Proposed ledger text for Root's normal implementation PR, preserving all statuses:

- L04 candidate cell: “LOS-147 prepares original physical source and identified
  owner/concern/superclass contribution witnesses, with duplicate candidates and
  source/runtime coherence unknown. Installed/served acceptance pending; broad
  effective-source semantics remain open.”
- L14 candidate cell: “LOS-147 code-first model/concern reading increment and
  context-preserving Source/caller journey pending changed-candidate acceptance.
  Full Field Guide discovery, schema, history and human jobs remain open.”

For the shared decisions record: record the additive existing-index page decision,
its repeated-prefix cost and reconsideration condition above. For Map README and
installed-doc manifests, link this contract and the Map contract with their actual
implemented/UNRUN boundary; do not claim the full restored replacement scope done.
