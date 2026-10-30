# Root-qualified recorded callers

LOS-134 corrects the saved-label matching path for a caller written as
`::Widget.build`, including inside another namespace. It does not add capture
families, constant resolution or runtime binding. The original call label and
source remain available. All 17 launch capabilities remain unqualified.

## Matching and evidence

The existing schema-aware `SemanticLinkView` decides whether metadata is a
recognized call. Only a non-omitted receiver classified as `constant` supplies a
constant matching key. Strip exactly one leading `::` from that borrowed receiver
label for comparison with the saved declaration name. The existing producer
already removes this marker from absolute declaration names. Preserve namespace
segments, case and Unicode bytes: `::Shop::Widget` matches `Shop::Widget`, never
`Widget`. Relative `Shop::Widget` retains the same full-label key. Relative
lexical lookup is not inferred, including from a nested caller.

Use the existing receiver classification rather than implementing another Ruby
identifier grammar. Static capture obtains that classification from Prism;
explicitly published recognized metadata remains the publisher's recorded
assertion. This change neither validates nor repairs that assertion's spelling.
The helper is not applied to arbitrary link targets. Nonconstant and omitted
receivers keep their existing behavior. Unknown extensions keep literal target
matching; in particular, schema 1's opaque version-2 metadata is not promoted to a
recognized receiver. Recognized version-1 metadata and schema-2/3 version-2
metadata use the same key, including schema-3 stored rows.

Incoming selection, outgoing candidate selection and candidate follow-ups all
use this same borrowed key. `candidate_label`, link targets and extension data
retain the original spelling. Fact IDs, relation types, source bytes/digests and
spans are untouched. Incoming `label_match_binding_unknown`, outgoing uncertainty,
full-domain candidate counts, duplicate declarations and ambiguity remain intact.
A unique label match still proves no dispatch, execution or canonical binding.

## Alternatives and cost

Reuse the existing borrowed link view and optional sorted fact-position directory.
The only new representation is two borrowed slices, one for evidence spelling
and one for matching. Stripping a single two-byte prefix requires no allocation,
parsing, cache or additional scan. Incoming comparison charges the original
receiver and declaration byte lengths before comparing the key. Outgoing binary
search compares the key but charges the original receiver length for each label
comparison. Existing comparison, byte, output and refusal limits remain unchanged.
The shared model-brief label allowance receives those same original-byte charges.

Directory construction, ordering, reservation and retention are unchanged:
O(F log F) string comparisons on first use, borrowed keys and O(F) positions;
range lookup still uses two binary searches plus the requested candidate page.
Reader opening, reopening, serialization, mutex/Arc lifetimes, FFI crossings and
store admission acquire no new work or ownership. New matches can of course
produce additional bounded pages. This is source analysis, not measured latency,
RSS or support evidence.

Capture-time normalization would lose evidence spelling or require duplicated
metadata and would miss retained generations. Rewriting stores would change
identities and require migration authority. Ruby/CLI normalization would duplicate
Rust semantics and leave other consumers inconsistent. A universal resolver,
reverse-link index or new dependency adds work and maintenance unrelated to this
label defect. Reconsider the representation only if a separately scoped outcome
needs actual resolution or measured whole-job costs justify it. Root owns any
later shared-decision or package-document reconciliation; this bounded document
is repository guidance and adds no package-manifest change.

## Authored checks and current limit

This candidate is source-only. No candidate compilation, Rust typecheck, native
or Ruby product test, capture, publication, installed check or benchmark has run
in this phase. Authored regressions are plans, not passing evidence. Source/static
receipts belong to the PR and exact immutable candidate; earlier accepted traversal
and installed evidence retain their original identities.

The focused native regressions cover recognized v1/v2 contexts, schema-1 opaque
lookalikes, nonconstant/arbitrary targets, namespace/case/Unicode preservation,
original-byte charging/refusals, incoming/outgoing agreement, paged late duplicate
ambiguity and reopening the old generation after CURRENT changes. Existing
reference and recorded-domain tests retain their broader scan/admission controls.

The tiny producer fixture records `Widget.build`, `::Widget.build` and a nested
`::Widget.build` caller, a separate duplicate declaration, and positive/negative
`Shop::Widget` controls. The new public test uses one-result pages, fresh pinned
CLI Readers after CURRENT advances, outgoing candidate follow-ups, exact source
bytes/digest/receiver spans and unchanged reopened facts/links. Source filenames
and stable IDs do not imply execution order or binding. Fixtures are captured as
source, never evaluated as application code.

## Finite later validation plan

Root must separately allocate the existing execution resource and name the
settled source SHA/base, allowed host/time/resource window, loaded native and
package identities before any candidate execution. No runtime or host claim is
held by this writer. Proposed focused work, subject to that allocation:

1. One offline native build from the immutable candidate, under existing enforced
   process/disk/log limits with failure propagation. Run the `references::tests`
   and `recorded_domain::tests` Rust filters and applicable existing native/parser
   and reader-boundary controls. Preserve every failure. No benchmark, corpus or
   application replay. Budget the entire affected native step once, rather than
   repeating compilation per filter.
2. Run `ruby -Ilib -Iext/thistle_native test/test_root_qualified_references.rb`
   with that exact built native, plus affected existing reference/model-brief
   controls under current gates. The new journey has one tiny capture, one tiny
   CURRENT replacement and at most eight continuation pages per helper call.
   Native controls retain the larger scan-boundary proof; the tiny journey tests
   matching and ordinary public access without reproducing that larger corpus.
3. Root obtains independent substantive review and current affected required CI
   for the settled head/base. Candidate CI remains development evidence. A missing,
   failed, cancelled or inconclusive lane is not a pass.
4. Run ONE focused changed-package installed journey under the existing installed
   contracts and relevant Map smoke. Copy the new public test and its tiny fixture
   outside the checkout, invoke it with installed Core and no checkout load path,
   and retain exact package, actually loaded native/Ruby, fixture/test, toolchain
   and support-tuple identities. Account initial open, first lookup/directory
   build, reuse and reopen separately; do not infer RSS from encoded budgets.
   Package/manifest execution and any necessary packaging integration belong to
   Root's existing gate, not this source writer's claim.

Root owns execution allocation, independent review, CI, installed applicability,
integration and final technical disposition. PM owns planning/acceptance tracking;
Leah retains applicable acceptance. No merge, publication, launch qualification,
cap increase or frozen Experiment 001 change follows from this source checkpoint.
