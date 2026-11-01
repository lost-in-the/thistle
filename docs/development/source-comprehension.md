# Saved model source comprehension — LOS-147

This source increment prepares one model/concern reading journey. Core wiring
adds optional explicit capture context, strict publication/open validation and a
Reader operation. Map route/View wiring is now present in source. Actual native
checks and installed/served evidence still belong to the integration owner. The
full initial R120 source review is retained; this correction awaits changed-scope R2.
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
and positive u32 `line`. Undef gaps and descriptors without an inventoried direct
owner use null owner/source. A visibility-only entry may resolve to an excluded
body or an in-chain wrapper, depending on Ruby; neither justifies a guessed owner.
Anonymous owners remain
anonymous. Descriptor provenance is reflection, not a captured source span.

Rust `validate_observation` checks exact fields, names, indexes, visibility,
duplicates, complete descriptor-name coverage and owner/source agreement.
`batch(context, observation, root)` uses existing `ObservationAdmission` counters
and wire-byte admission. New `rails_source_ownership` facts have no physical path
or location. Identity uses kind/version/registry ordinal/model label; duplicate
registry labels remain different facts. Only safe absolute hints beneath the
supplied root become relative hints; relative, eval/internal pseudo-locations,
outside and unsafe hints become unavailable. Root `/`
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
inventory means unknown, not an empty application. An anonymous owner returns
`anonymous_owner_no_label_candidate`; a repeated owner label returns
`duplicate_owner_label_unknown`. These are row-level unknowns with no candidates
and no complete candidate-range claim, never a whole-page refusal. Both families
continue normally to subsequent owners/methods.

One response returns up to `limit` row/candidate slots. A row with no candidates
(including generated methods or unsupported owner labels) consumes one slot; a
row with multiple candidates consumes one slot per candidate. The compact `rows`
outline retains owner index/name, method/visibility, status and per-row range
witnesses even when no code candidate exists. `owners` contains only page-local
owners in original ancestry-index order, not a reconstructed full class. The existing
`recorded_domain` cursor scope is `[source_comprehension, id, family]`; its two
positions are the owner/flattened-method ordinal and candidate offset. Cursors
cannot change generation, model or family. Callers follow `continuation`; the
selector never auto-traverses all rows or reads source. Byte-limited pages shorten
the selected suffix and return its exact next row/candidate offset, rather than
skip it or require one request per generated method. A single row that cannot fit
still refuses the requested byte budget. A zero-progress work
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

The package selectors, installed-manifest assertions and shared reading guides now
include this contract. Root retains current CI disposition, the full independent
review and actual finite execution.

## Cost and alternatives

No second owner directory is retained. Existing method lookup stopped after its
second match and could not enumerate duplicate candidates; the additive page API
reuses its fixed-key index and Work contract. Recorded-directory construction is
lazy and visits/sorts the saved fact domain under its existing guards. This is
not zero whole-domain work. Reader open, lazy build and request work are distinct.
Request caps remain 20,000 visits, 100,000 label comparisons, 32 MiB of label bytes,
an 8 MiB scratch reservation and 32/64 KiB encoded output. Candidate traversal
leaves 1024 visits and 8 MiB of label-byte accounting for compact projection and
byte-limit trimming; these are within the existing caps. Visits/bytes also meter
required observation scans, row lookup and copied compact labels/hints.
Immutable saved ownership facts are trusted after strict publish/open validation;
queries neither revalidate nor encode their full trees. There is no asymmetric
2 MiB query-group cap; the 2 MiB per-model **admission** cap remains.
Projection/serialization create bounded copies;
these accounting limits are not heap or RSS measurements. No speed claim.

Admission indexes direct names per owner for linear descriptor validation instead
of repeated name searches. Each query builds borrowed label/effective-name maps
over at most 64 owners and 2048 descriptors, metering those scans. It uses direct
array lengths and at most 64 owner-range checks per selected row, without walking
the full direct-method inventory. Candidate projection has at most 16 row/candidate
slots. Byte fitting can encode at most 16 shrinking compact projections; it never
copies full saved facts or ownership trees. Method-page continuation repeats its
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
**UNRUN** in this phase. The initial missing-rustfmt preflight and earlier attempts
are retained; no Rust/native execution is admitted for this correction.
No package/native/installed/served result can be inherited from another artifact.

## R120 correction dispositions — source only

| Stable finding | Correction and focused evidence |
| --- | --- |
| R120-01 | Unknown anonymous/duplicate-label rows retain normal continuation. Authored Rust traversal checks both families reach Parent; fixture now has a mid-chain anonymous module. Pure observer/presenter checks cover the raw row and visible unknowns. |
| R120-02 | Descriptors without a known inventoried direct owner normalize owner/source to null; strict admission still rejects forged hints/owners. Builtin-only Ruby 4.0.9 visibility probe observed a child-owned wrapper, so the review's boundary-owner trigger was not reproduced on that Ruby. Regression accommodates actual VM forms and exercises real builtin descriptors against missing/outside owner inventories. Other cohort execution is pending. |
| R120-03 | Only absolute root-prefixed safe hints survive. Authored Rust cases cover relative, eval/internal, outside, traversal and double-slash hints. |
| R120-04 | Up to limit row/candidate slots and compact outline per response; authored Rust check traverses 40 generated methods in five limit-eight pages and verifies byte-cut suffix identity. README corrected. |
| R120-05 | Removed immutable-fact revalidation/group encoding; direct-name admission maps and metered request maps replace repeated name scans. Authored Rust tests cover >2 MiB ambiguous groups, a large unique inventory, and exhausted scan allowance. |
| R120-06 | One admitted shared-file block highlights the union of selected spans, with each fact's physical start linked in-page and exact Source preserved. Pure presenter regression checks both spans/anchors, one numbered file and family-specific continuation. |

These are implemented source dispositions, not independent acceptance. Root owns
changed-scope R2 and actual native/installed/served/customer evidence. The full
initial report/raw remain unchanged: ~696s analysis exceeded its 300s target;
missing timeout wrappers, first-open 0644 scratch lists, retention EROFS, partial
doc/test reads, unverified transcript persistence and unmeasured CPU/RSS/quota
remain disclosed. Prior CI and procedural attempts keep their exact identities.

The opt-in installed producer/consumer harness and served task protocol are in
the [Map contract](https://github.com/lost-in-the/thistle/blob/43b2bca7555b8b62f970bc9751939226a274f4ef/map/docs/source-comprehension.md)
at source checkpoint `43b2bca`. The explicit URL remains usable without a sibling
Map checkout. These checks require Root's
shared wiring and a new finite execution lease. Root owns review/check/integration;
Leah owns applicable acceptance. Self-checks do not independently qualify the work.

The repository ledger's L04/L14 candidate cells record this bounded source
increment and pending acceptance. All 17 rows remain UNQUALIFIED. Broad effective
source, complete Field Guide discovery, schema, history and human jobs remain
declared outcomes; this guide and package inclusion do not qualify them.
