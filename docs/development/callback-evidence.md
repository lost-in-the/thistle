# Registered save callback evidence

LOS-50 ([original issue 78](https://github.com/lost-in-the/thistle/issues/78))
asks which save callbacks are registered on an already loaded model. This source
phase supplies independent components; it does not establish an integrated or
accepted customer journey. Leah owns acceptance; the technical coordinator owns
shared composition and installed candidate checks. All launch capabilities remain
unqualified.

## Supported observation and meaning

The input is an explicitly supplied, already loaded Rails application using
Active Record **8.1.4**. Static capture never boots an application. The observer
inventories loaded `ActiveRecord::Base.descendants` without eager loading,
autoloading model targets, instantiating records, checking out database
connections, evaluating scopes, or invoking callback/condition bodies. It reads
the version-pinned `CallbackChain`/`Callback` primitive layout. Unsupported
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
transport: existing source/fact payloads are never retransmitted. Root extracts
`schema::ObservationAdmission::new(context)` and `admit(&fact, entry_count)`
from existing Model admission for both components. Context retains Model's
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

## Exact integration delta reserved for root

This uses Rails' existing registry rather than parsing callback macros or adding
a reflection library: source macros alone cannot establish effective inherited
or skipped registrations. Reading the pinned primitive layout avoids compiling
the chain, at the cost of a narrow version adapter. Reconsider the adapter when
supporting another Rails version or when upstream offers a nonexecuting public
metadata API. Root should record this bounded choice and shared helper extraction
in the existing decisions document during integration; this worker does not own
that shared file.

Existing files remain untouched by the source worker. Integrator work:

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

Source delivery has **not run** these tests, built native artifacts, booted
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
