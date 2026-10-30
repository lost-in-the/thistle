# Registered save callback evidence

LOS-50 ([original issue 78](https://github.com/lost-in-the/thistle/issues/78))
asks which save callbacks are registered on an already loaded model. Phase A
composes the donated components with accepted Model source: native shared
admission/dispatch, publication and fresh Reader validation, Capture append and
Map Source presentation. Source checks are distinct from executed native/Ruby/
Map and installed-artifact acceptance. Leah owns acceptance; root retains final
review, integration and exact-package checks. All launch rows remain unqualified.

## Phase A integration and evidence boundary

Model and callbacks share `schema::ObservationAdmission::{new,ensure_facts,admit}`.
Its context keys, global fact/link/byte counters and configured ceilings retain
Model's meaning. Entry counts remain per observation batch/family. Each native
batch returns context-independent `appended` charges for facts, links, entries
and conservative encoded fact bytes. Capture counts the format-2 static facts
once, reuses RailsCapture's existing local route byte charge next, and uses native appended
charges thereafter. It never serializes growing old facts for each new family.
Publication independently validates the actual complete capture before I/O.
When joining routes into an empty static array, subtract exactly the first
conservative comma; zero routes add nothing. The focused regression covers empty/
nonempty static arrays and zero/one/multiple routes, preserving previous exact
post-route admission boundaries.

The View hook supplies the existing pinned Reader, generation and mount to the
callback presenter. A separate installed callback producer copies/boots only the
harmless callback fixture, captures/publishes it and advances CURRENT. A fresh
consumer opens the retained generation without Rails, checks registered known
answers/source/uncertainty and renders the real Map Source view. Its input and
receipt hashes and loaded native identity are recorded by `qualify_baseline.py`.
The existing selected-arm Model/Find/heredoc smoke and argv are unchanged.
Callback applicability is selected by the packaged observer; missing inputs
refuse. Producer failure stops the consumer and all later qualification work.

Default capture/publication stays format 2. Codec registration/helper work is a
separate stacked source head; no schema-3 store, measured saving, full-app fit or
qualification is established by callback composition. The prior failed Ruby
preflight and failed uncomposed hosted attempts remain evidence below and in
LOS-50; no earlier result transfers to this changed source.

## Supported observation and meaning

The input is an explicitly supplied, already loaded Rails application using
Active Record **8.1.4**. Static capture never boots an application. The observer
inventories loaded `ActiveRecord::Base.descendants` without eager loading,
autoloading model targets, instantiating records, checking out database
connections, evaluating scopes, or invoking callback/condition bodies. It reads
the version-pinned `CallbackChain`/`Callback` primitive layout. The save registry
comes from Rails' private class-attribute value-reader closure, guarded by the
same instruction-sequence identity as a fresh framework-generated reader on an
isolated plain class. It never dispatches model `_save_callbacks` or `__callbacks`
accessors. A custom storage getter or unavailable VM/layout yields unavailable
chain metadata. This narrow adapter targets the existing MRI development cohorts;
it does not establish arbitrary Ruby-engine or monkeypatched-framework support. Unsupported
versions yield unavailable inventory. Unrecognized chain layout is unavailable;
unrecognized entries retain their position with partial metadata.

Positions are zero-based positions in `_save_callbacks`, including before, after
and around entries. They are **not execution chronology**. Rails' compilation,
halting, conditions, yielding and exceptions can change actual execution. Create,
update, validation, transaction and other callback chains are outside this slice.
See the upstream [Rails 8.1.4 callbacks contract](https://api.rubyonrails.org/v8.1.4/classes/ActiveSupport/Callbacks.html)
and [pinned implementation](https://github.com/rails/rails/blob/v8.1.4/activesupport/lib/active_support/callbacks.rb).
The engine implementation is independent of Woods.

`inherited: true` means the exact registered callback object is also present in
the immediate superclass's observed save chain. `false` means it was not shared;
`null` means comparison was unavailable. Conditional skips may replace a callback
object; false therefore does not prove local registration. `superclass` is a
label, not a resolved target. Symbol filters and conditions separately carry the
effective `UnboundMethod#owner` label and source location. A subclass can share
an inherited registration while overriding its effective method. Registration
site, originating concern and original declaring class remain unknown.

Procs carry location hints but their bodies remain opaque. Other callable
objects, framework wrappers, and unsupported values are opaque; their `inspect`,
`to_s`, JSON methods and call bodies are not used. A missing method retains its
symbol label with unknown owner/source. `if`/`unless` contain safe references;
`[]` means none registered and `null` means unavailable. Rails-inserted internal
conditions can be opaque. These values are never boolean execution results.

## Primitive and normalized contracts

`CallbackObserver < ModelObserver` reuses the released Model contract at
`ba50925591fc920ae8ef164bb456ccb9b49c1bbc`: primitive copying, bounded entry
counting and streaming encoded-size accounting. The observer returns:

```text
{version:1, active_record_version, root, status, models:[
  {name, superclass, save:{status, entries:[
    {kind, filter, if, unless, inherited}
  ]}}
]}
reference = {kind:"method", name, owner, source} |
            {kind:"proc", source} | {kind:"opaque"} | {kind:"unavailable"}
source = {path, line} | null
```

Envelope status is observed/unavailable. Chain status additionally admits
partial. Kind is before/after/around or null. Ruby produces primitives only;
Rust validates every field and refuses unknown versions and malformed known
evidence. Limits raise errors, never silent truncation. The observation root is
the supplied absolute source root; Rust removes it and drops external/unsafe
source hints. The root and external source paths are not stored in callback
facts. Paths supplied relatively by Ruby may remain unavailable.

`callbacks::batch(context, observation)` follows Model's incremental native
transport: existing source/fact payloads are never retransmitted. Both components use
`schema::ObservationAdmission::new(context)` and `admit(&fact, entry_count)`
extracted from existing Model admission. Context retains Model's
`limits`, `facts`, `links`, `diagnostics`, `fact_bytes` shape. Each callback and
condition consumes an entry; each model consumes a fact; labelled relationships
consume links; combined fact JSON consumes the existing byte budget. The helper
must validate used counters, ceilings, checked additions, array bracket/comma
accounting and diagnostics before admitting output. This source branch does not
provide a parallel admission implementation. Root also owns reconciliation of
entry accounting across observer families.

Rust emits one `rails_save_callbacks` fact per model, including empty/unavailable
chains. `attributes.callbacks` adds version, generation-local ordinal, Active
Record version, `coherence:"unknown"`, `provenance:"registered_metadata"` and
zero-based entry positions. IDs digest `["rails_save_callbacks",1,ordinal,name]`;
they identify records within a saved generation, not durable model identity or
live object identity. Model labels remain unresolved relationships. No callback
fact has a captured `path`/`location`; source-location hints do not prove that
loaded code equals captured bytes. `validate_fact` recomputes strict identity,
relationships, positions and provenance on publication **and fresh Reader open**.

## Saved Reader and Map

The presenter accepts a saved fact, `generation:`, optional `reader:` and trusted
Map `mount:`. Root invokes it in the runtime Source fallback, as with Model.
It displays kind, chain position, effective owner, superclass comparison,
conditions, uncertainty and supported source hints without JavaScript.

A hint becomes a captured-file Source link only after the supplied Reader and
source response match the selected generation, manifest path/digest, bytes and
line bounds. The link uses the existing digest-of-path file selector and pins
the same generation. It is labelled **Captured source (coherence unknown)**,
never resolved dispatch or execution. Missing, external, oversized, stale,
invalid or unavailable hints remain text. Display limits are 256 KiB metadata,
200 rows, 16 attempted source files and 1 MiB expanded source bytes. Larger
evidence remains available through Reader facts. Source reads are cached only
for one render; no live files are read. Existing Map authorization, navigation,
focus and generation routing remain root-owned.

## Original component integration plan

This uses Rails' existing registry rather than parsing callback macros or adding
a reflection library: source macros alone cannot establish effective inherited
or skipped registrations. Reading the pinned primitive layout avoids compiling
the chain, at the cost of a narrow version adapter. Reconsider the adapter when
supporting another Rails version or when upstream offers a nonexecuting public
metadata API. Root should record this bounded choice and shared helper extraction
in the existing decisions document during integration; this worker does not own
that shared file.

The original donated source left these hooks uncomposed. Phase A now implements
them on the callback continuation; installed execution/acceptance remain root-owned:

1. Land/reconcile the fixed Model components; reuse its observer helpers and
   `schema::{model_object,model_label,encoded_bytes}`. Extract shared admission
   with the API above and retain the existing Model regression behavior.
2. Add `mod callbacks`, dispatch `callback_batch` with context/observation only,
   and call `callbacks::validate_fact` for recognized facts in `schema::facts`.
3. After the Model batch, instantiate `CallbackObserver` with absolute root,
   remaining fact/entry/byte budgets; call the native batch with current combined
   counters; append facts/coverage and `producer.callback_observer`. Reconcile
   generic effects coverage so callback execution remains unavailable. Admission
   failure must stop publication.
4. Require/invoke `CallbackPresenter` on callback facts in View, passing the
   existing pinned Reader/generation/mount. Preserve existing access controls.
5. Compose the dedicated tests below and affected installed Core/Map smoke and
   packaging checks. Reconcile query metadata allowlisting if callback fields
   beyond the model name are to be searched; no search expansion is claimed here.

## Evidence and remaining work

Dedicated source regressions (not qualification):

- `test/fixtures/callbacks/` registers harmless real Rails callbacks with
  inherited/skipped/conditional/around cases and execution/formatting canaries.
- `test/test_callback_observer.rb` checks independent known answers, inherited
  overrides, conditional skips, unknown layout, missing methods and limits.
- `engine/src/callbacks_tests.rs` checks normalization, strict negative mutations,
  combined admission, source isolation, publication refusal and fresh Reader.
- `test/test_callbacks.rb` requires real shared Capture/native/schema composition,
  publication and reopening a saved generation after current changes.
- `map/test/callback_presenter_test.rb` checks escaping, conditions, bounds and
  pinned links. Its Reader double is presentation evidence only.
- `map/test/callback_journey_test.rb` requires real capture, a reopened pinned
  Reader and View composition after the current generation changes.

The original donated source phase had **not run** these tests, built native artifacts, booted
Rails, executed Map, installed packages or run an evaluator. Eight Ruby syntax
checks, whitespace validation and the note filesystem/text guard passed. Rust
formatting/typechecking is unverified (`rustfmt` unavailable).

The single granted Ruby-only attempt stopped at its exact-runtime preflight:
the selected local image declared Ruby 3.4.12, while the grant required 4.0.9.
Neither test process ran. Before refusal, the child verified enforced 2 CPU,
1 GiB, zero swap, 128 PID limits, no network and a task-owned `0700` disk TMPDIR.
The launcher enforced 600-second child/630-second outer deadlines and an 8 MiB
combined log cap. Input hashes remained unchanged; the container and private
HOME/TMPDIR were removed. The slot was released without fallback or rerun.

A new runtime grant must identify exact resources before further execution;
a released resource is not a grant. The full Reader/Map journey and installed
candidate checks remain outstanding until root composes and verifies the hooks.
Source delivery does not authorize publication or launch acceptance.

## Phase A source checks and failed minimum-cohort preflight

The composed native suite passed 74 tests on combined codec source
`f6d3066a49d813ab89b339c6f50920e61f2db422`, including six callback tests
and real publication/fresh Reader/refusal checks. That source/archive retains its
own receipt; later Ruby-only source changes do not relabel it as a new run.
Nine harmless qualification-orchestration regressions passed, including separate
callback producer failure propagation and unchanged historical Model applicability.
Changed Ruby files passed syntax checks.

A distinct Ruby/Map source attempt on
`4a2ceb6d2c758c1034121fe21eedc41b4dedb6eb` failed in dependency preflight
before compilation or any Ruby/Map tests. The child verified Ruby 3.4.12,
Rust 1.90.0 and the granted cgroup/network/private disk TMPDIR controls. The
exact authorized SQLite 2.10.2 cache installed privately. A compound dependency
assertion then failed before printing the actual tuple. The author unnecessarily
required an exact JSON version; the generic retained error cannot identify which
assertion failed. No cause or alternate tuple is inferred. No source build copy,
native library, or dependent test was produced. Inputs were unchanged, cleanup
was verified and the slot released without retry. Root must disposition another
finite attempt; installed/exact-package acceptance remains separate.

Failure log SHA256:
`8676d3c05007e1cb7ff58d6423d2bc3379bfb8d5862d0675c617be8cb40ffe7c`.
Result SHA256:
`78a31b419ec1b29ad5a33301b2b4f1d3d880ef447a2f484aa8542ff7af8062ae`.
This preserves both failed preflights; neither is callback runtime success.

A separately authorized corrected attempt on the same frozen source printed and
retained the actual tuple before named checks: Ruby 3.4.12, Rails/Active Record
8.1.4, JSON 2.9.1, SQLite 2.10.2 and selected Rouge 5.1.0. The named Rouge check
refused because the candidate requires development `~> 4.6` and runtime `< 5`.
Availability of other compatible installed Rouge versions was not inspected.
The JSON IO-generator probe, extension build and all five test commands were not
reached. This does not establish the cause of the earlier generic failure.
No dependency substitution or retry followed. Input invariance and cleanup were
verified; selected spec paths and the separate receipt remain retained.

Corrected-attempt log SHA256:
`4bf68a74f3e425a4ccf71518544ed207152221566932f073d7832f5e1ccc2a94`.
Result SHA256:
`2c62474704cb2200225c64f3a82be5bdd431bb8e93398ded71b25791cb342845`.

Source self-review examined shared checked admission and refusal atomicity,
per-family entry meaning, semantic IDs/provenance, one-way primitive native
transport, exact separator charges, pinned requested source expansion, unchanged
FFI/Reader lifecycle and installed-orchestration failure propagation. No parallel
admission implementation or old-static-fact rescan was introduced. The minimum
source journey and installed artifacts remain open evidence gaps; native tests
alone cannot accept the callback insight outcome.

## Phase A native execution receipt

The single authorized offline native run on combined source
`f6d3066a49d813ab89b339c6f50920e61f2db422` passed **74 tests**, including all
nine codec tests and six callback tests. Rust/Cargo 1.90.0 ran in exact image
`f377fb86ef51f1b4b31787dc58131ad453fe306e58b36296f29e76a98487c520`.
The child verified 2 CPU, 2 GiB memory, zero swap, 256 PIDs, no network, read-only
copied source and a private 0700 disk-backed TMPDIR. Deadlines were 600 seconds
for Cargo and 630 seconds outside the container; logs were capped at 8 MiB.
Inputs were unchanged and the container/private build directory were removed.

Native log SHA256:
`6103f3d400b6e79f919692268a1ceb4a724aee177adfa267b33113d65c7ecb21`.
Input manifest SHA256:
`b297b50ec372fa2be4a6f0096651600792bfe03e5cd5cb42c47102ab481535b7`.
The 18 compiler warnings identify codec APIs not yet consumed by production;
Phase B must connect those APIs. They were not suppressed. No Ruby/Map runtime,
installed callback journey or exact-package acceptance follows from this native
receipt. Historical failures retain their original identities and scopes.

## Source-supported potential effects (LOS-62)

`reader.callback_effects(registry_id, limit: 50)` explains a selected saved
`rails_save_callbacks` fact ID in the Reader's pinned generation. The integer
limit is 1–200. A model label is never used to join registry facts. Responses carry
the exact registry ID, saved model label, generation, registry status and callback
position/kind/filter/effective owner/inheritance/registered conditions. A callback
ID is `registry_id:position`, meaningful only together with this generation.
Conditions remain references, never boolean results. Registered metadata,
source-supported potential behavior and observed execution are separate evidence
families; execution is unknown.

A supported filter needs an observed method owner, method name and relative
source path/start line. The native selector scans captured static instance-method
declarations once, grouped by exact effective owner/method name. It requires one
unique declaration, `singleton: false`, lexical name resolution, the exact
`owner#method` name, matching path/start line and a nonempty complete span.
Duplicates (including another declaration at a different location) stop binding.
A provisional candidate from an incomplete uniqueness scan cannot bind. Inherited
filters use their effective owner, which may differ from both the model label
and the superclass registration. Name-only, unresolved/unknown owner, stale or
mismatched descriptors, singleton methods, procs and opaque references remain
unknown with explicit reasons.

Even a match is labelled **descriptor-matched captured declaration**, with
**runtime/source coherence unknown**. The saved descriptor and matching source
coordinates do not prove that these bytes were VM-loaded or that live method
identity/dispatch agrees. No loaded-byte equality proof exists in this format.

The first supported operation is a **potential enqueue-style request**: an
existing representative `calls` link whose selector is exactly `perform_later`
and whose recognized typed metadata records a non-omitted constant receiver.
The response displays concrete `receiver.perform_later`, captured file path,
SHA-256/length, method/call/receiver half-open byte and line spans, and at most
512 bytes of supporting call source. A shortened excerpt is explicit; full source
remains available through the pinned Reader. The existing source loader verifies
the blob's digest/length and the schema validates all selected method/call/receiver
coordinates against actual saved UTF-8 bytes before effects are returned. Receivers must lie inside their call spans. This narrow explanation supports
calls physically inside the matched lexical method span. Prism can validly
associate heredoc interpolation calls whose bytes follow that method's `end`;
such a call yields `unknown` with `recorded_call_outside_lexical_method_span`,
not snapshot corruption or exhaustive absence. Registry evidence remains available.
A missing blob is unavailable; corrupt bytes/positions and other integrity/path
errors refuse and never become benign missing evidence.

Constant identity, ActiveJob ancestry, runtime dispatch, condition/branch
satisfaction, invocation, job delivery and execution are **unknown**. This is
not an observed enqueue. There is no constant resolution, alias expansion,
call graph, argument/value extraction, AST traversal, parsing, execution or live
filesystem fallback. Existing first-representative call deduplication is preserved;
these groups are non-exhaustive, and lexical occurrence is not execution order.
`no_supported_match` concerns only the searched recorded declaration and supported
operation; it never establishes no possible effect, including when the registry
or capture is partial/unavailable.

Each request holds a 32 MiB transient reservation from the existing aggregate
query budget through native response serialization. It retains only borrowed
identities and bounded results, with no persistent index/cache. Caps are 200
attempted callback rows, 20,000 fact visits (including anchor admission and selected-method validation/analysis), 50,000
link visits, 32 MiB compared label bytes, 16 attempted files, 256 KiB per file,
1 MiB charged expanded source and 128 KiB encoded returned output. Each selected
method's links are charged twice: schema validation and effect inspection,
including nonmatches. File attempts and declared expansion bytes are charged
before reading, including failures; each unique selected file is read at most
once. Oversized files consume attempts without expansion. Row metadata is capped
at 8 KiB before copying, at most eight potential effects are displayed per method,
and returned row payloads share 96 KiB, leaving envelope headroom. Omitted metadata,
output rows/effects, row limits, incomplete uniqueness searches and source/link
budgets are explicit. Unknown unsearched matches are never counted as zero.

For F visited facts, C selected descriptors (at most 200), M manifest files,
S charged source bytes and L admitted links, work is O(F log C + C² + 16M + S + L
+ returned bytes). Descriptor search uses a charged binary search, rather than
C full-fact scans. Per-file schema validation batches methods and constructs one
newline index. Peak scratch consists of O(C) borrowed groups and bounded result
Values, one at-most-256-KiB expanded file and its byte-offset newline index,
selected row output and ordinary JSON/FFI copies, all admitted under the 32 MiB
reservation. This is conservative accounting, not a measured RSS, speed or
headroom claim. Existing per-request source and query limits remain unchanged.

Map invokes the optional API in its existing callback Source fallback and escapes
all text/excerpts. Supporting source links pin generation/path. Older Readers or
an older native engine's exact unknown-operation refusal show unavailable;
resource refusal shows its limit. Other failures, including invalid snapshots
and generation/registry mismatches, propagate. Existing hint-only links also
preserve integrity refusals. No View/app, authorization or lifecycle changes are
required. The actual installed consumer assertion is additive preparation;
source tests and syntax checks cannot establish settled installed-package
acceptance. Root owns review, integration and exact-pair checks; Leah owns
applicable acceptance. All 17 launch capabilities remain unqualified.

### LOS-62 focused development receipt

The final source check passed 10 native tests, 10 Core tests / 69 assertions
(saved primitive, observer and callback publication), and 12 Map tests / 134
assertions (presenter, real callback journey and fresh consumer). There were no
failures/errors/skips in those final groups. The additive installed-consumer hunk
passed syntax checking only; no installed package acceptance is claimed.
Ruby 3.4.12, Rails 8.1.4, Rouge 4.6.1 and Rust/Cargo 1.90.0 ran offline in image
`f377fb86ef51f1b4b31787dc58131ad453fe306e58b36296f29e76a98487c520`.
Final loaded native SHA-256:
`9a8a2dc5b57d8cdeb1db11486c2f52669423ecb64fe9b7a7a5c668c3a059926c`.
Final copied-input manifest SHA-256:
`f58fbe64c5c6d457e5ec51459e2924415a397d440f0aee8745b56d976c064312`.
Final log SHA-256:
`9b6c03cb388bc8233b0ddbf801a6af69c3905ac833d87db2a00c8d3d6ae7fec6`.

All attempts shared one 600-second child / 630-second outer window, completing
at 416.04 seconds from the initial start, with an 8 MiB combined log ceiling.
The child verified 2 CPU, 2 GiB memory, zero swap, 256 PIDs, no network,
read-only copied inputs and private disk-backed HOME/TMP. No dedicated backing
quota was configured; availability was recorded without a headroom claim.
Input invariance was checked; containers and private build/input/HOME/TMP copies
were released, retaining private immutable archives/receipts only.

Two earlier failures remain preserved: the input copier initially excluded four
legitimate vendored `cc/src/target` files (no compilation/tests), then concurrent
native test fixture captures hit the engine's single-capture admission (9 passed,
1 failed; dependent work stopped). The fixture now shares one synchronized real
Prism capture. Their log SHA-256 identities are respectively
`7c8209bbf7b87833595863427606d3f255e0954d96634c10d0ab5703f528b6ce`
and `f96171c2f9c39638c9fca46a73de4fc7bf4443e57221319f97ff1bd01466f2fb`.
A passing intermediate source was rechecked after self-review removed repeated
per-method file line counting and redundant JSON result copies. Its earlier
native identity is not relabelled as the final native above. Self-review also
charged selected-method validation/analysis to the fact budget. Root's substantive
review, affected CI and settled installed-package evidence remain outstanding.

### Root integration fixture correction

After the dated focused receipt above, Root moved positive `perform_later` calls before their unconditional execution-canary raises. The real registered effective override now contains the request before its canary, with registry conditions still unevaluated; the saved-primitive examples retain explicit conditional uncertainty. This avoids using code after a guaranteed raise as the positive potential-effect example. No callback, condition or job was executed. The original 32 focused tests and native hash retain their earlier fixture identity; current composed-head CI and installed checks establish this changed fixture. Composition preserves accepted PR100 Find changes without modifying its query or smoke implementation.

The original `bda29fe` hosted run41026998561 passed its Core assertions but failed the fresh Map consumer on Linux and ARM with `cannot load such file -- thistle/map`. Its child process depended on a parent `RUBYLIB` supplied by the focused launcher, while canonical CI passes source paths with parent command-line `-I` flags. Root now passes explicit Core and Map `-I` paths to that fresh child, preserving the no-Rails and saved-generation checks. This repairs the test invocation rather than product dependency/routing policy; the failed run remains retained.

Codex finding4421893675 on `c9d157c` identified the valid discontiguous heredoc layout. Root changed only the explanation guard and added an actual Prism capture/publication/fresh Reader/Check regression. Existing digest, file/line/UTF-8 and receiver-in-call corruption refusals remain intact; no parser/schema/capture change or broader call-ownership inference is introduced. Current-head CI must establish the new regression; earlier passes retain their original source identity.
