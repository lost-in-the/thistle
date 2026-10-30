# Lexical call origins outside methods

LOS-135 gives otherwise ownerless Ruby call syntax an existing source-file
origin. This is a source checkpoint based on PR109 commit
`b7b9eab5404d61984842394d6641edc878ab8509`; using that source does not accept
PR109. The regressions below are authored and **unexecuted**. No compilation,
native capture, Ruby test, installed journey or support qualification is claimed.

## Ownership contract

The file fact already admitted by capture becomes the initial traversal origin.
An explicit class, module or supported real method replaces that origin exactly
as before. An ordinary block or lambda retains its enclosing lexical origin and
the existing dynamic-scope flag. A top-level `def render` remains the real
`Object#render` method; it does not also contribute file-owned call evidence.

This is lexical containment, with exact saved byte/line spans. A file-owned
`describe`, `it` or `task` call does not identify a test, task execution, runtime
receiver, described subject or coverage result. Method/block calls retain the
same grouping rules, including one earliest representative for each simple
receiver/selector/safe-navigation group within its owning fact. References count
recorded groups, not all textual occurrences. Different top-level blocks may
share a file-owned group. Call targets stay unresolved.

Unsupported declarations inside dynamic blocks and unsupported singleton scopes
remain refused under the existing traversal policy. Their bodies do not acquire
invented methods or speculative traversal. Declaration/mixin diagnostic groups,
occurrences, LIFO encounter order, partial coverage and admission limits remain
in force. A useful file origin does not make dynamic declaration coverage complete.

## Small before/after known answers

These expectations were written from the pinned source and public parser-child
schema before changing behavior; they are not independently executed results.
The six harmless fixtures live in `test/fixtures/lexical_body_origins/`.

| Fixture / expression | Pinned source before change | Expected after change |
| --- | --- | --- |
| `top_level.rb`: top-level `Kit::Button.new` and hash value | No call origin | Existing file fact; earliest grouped call |
| `top_level.rb`: hash value inside `top_render` | Real `Object#top_render` | Same real method, no duplicate file occurrence |
| `render.rake`: hash value inside `task do/end` | No call origin | Existing `render.rake` file fact |
| `button_spec.rb`: hash value inside nested `describe` / `it` | No call origin | Existing spec file fact |
| `namespaces.rb`: module/class body calls | Module/class facts | Same module/class facts |
| `namespaces.rb`: method hash value and nested block | Real method fact | Same real method; earliest grouped call |
| `dynamic.rb`: method declaration inside a block | Unsupported declaration | Same refusal, one declaration and one mixin occurrence |

`HashNode -> AssocNode -> value` is already present in the generated child
visitor. `Kit::Button.new` is a call with a constant receiver; no nonreceiver
constant collector or LOS-136 behavior is added. The new native hash regression
isolates a file hash and a normal method hash, so another grouped call cannot
mask a visitor failure. The generated visitor and PR109 diagnostic regressions
are unchanged.

The public Reader regression expects exactly seven incoming Button groups:
three file origins, one module, one class and two real methods. It follows each
saved origin through ordinary outgoing `references` and `source` on a fresh
Reader pinned to the first generation after live bytes and CURRENT change.
Expected content digests, representative call and receiver spans, origin
containment and generation identities must remain exact. It never loads the
fixture application or executes its DSL bodies.

## Cost, limits and alternatives

The implementation carries one existing fact index into the same traversal.
It adds no facts, parser passes, AST child enumeration, resolver, retained index,
FFI crossing, Reader API, dependency or storage-format revision. A new explicit
body-fact type would distinguish individual blocks but add identities, schema
and navigation costs without establishing dynamic ownership. A second AST walk
would repeat extraction work and risk duplicate evidence. Reusing file facts is
the smallest contract that answers this source-navigation question; reconsider
body identities only for a separately scoped need to distinguish lexical blocks.

Previously dropped calls now consume the existing call-key map, links, compact
schema-3 encoded evidence, response materialization and immutable-generation
retention. New groups may therefore cause an honest `max_links` or 64 MiB evidence
refusal on an input that previously succeeded. No limit is raised. No additional
source blob is required for a file already captured. Source bytes are retained
as before; each changed generation retains its additional links under the current
store lifecycle. Reader admission, scratch, paging/output and diagnostic limits
continue to apply. Encoded charges are not a heap/RSS measurement.

During extraction, calls retain the existing schema-3 compact row projection
instead of expanded semantic JSON objects alongside the Prism AST. Grouping keys
are released after file traversal, before the public semantic link objects are
materialized and sorted. This reuses the existing encoder/decoder, preserves
per-site grouping, public output and encoded charges, and adds no format revision.
Call/link index and link-vector growth use fallible capacity reservation. This
reduces simultaneous representations; CPU and peak-memory effects still require
the unchanged Linux parser-boundary checks, not a source-only performance claim.

Static links also consume the allowance later offered to Rails observation:
`lib/thistle/capture.rb` passes only `max_links - static_links` to the runtime
observer. Exhausting that remainder can refuse the whole combined capture, not
just omit runtime rows. Spec/Rake bodies may therefore crowd out runtime evidence.
The file-owned `fact`, `links` and `source` follow-ups can materialize the whole
file link tree under the existing APIs; this change adds no transient reservation
to those paths. Incoming/model-brief pages may reach their existing work limits
sooner. These amplification risks remain explicit; no spec-heavy field outcome,
whole-application completeness, memory headroom or runtime-support claim follows
from the small source fixtures or a successful cursor traversal.

For the native two-call fixture, the expected single tagged row is
`[0,"new",["constant","Kit::Button",false,false,[0,15,1,1],[0,11,1,1]]]`.
Its UTF-8 compact JSON length is 70 bytes; the capture charge includes its
existing conservative one-byte separator. The authored regression compares the
actual complete WireFacts encoding with the native hint (actual bytes + 2 for
one fact with nonempty links). This is format arithmetic and a planned assertion,
not a measured capture-size, memory or speed result. The same fixture fits one
file fact, one grouped link and eight visited nodes; seven nodes must refuse.
Separate direct-boundary assertions require encoded/link refusal before mutation.

Self-review examined scope replacement, no duplicate ownership, LIFO ordering,
group representative replacement, exact source containment, diagnostic refusal,
pre-admission charging, generation pinning and downstream retention. No new
shared seam or extra traversal was needed. Remaining uncertainty is compilation
and execution of these changed bytes, plus independent review and installed
artifact applicability; source inspection cannot close those gates.

## Finite later validation owned by Root

After independent review settles an exact source candidate and a separate finite
runtime claim is granted, stop dependent checks on failure:

1. Compile/run the native capture and diagnostic regressions once, including
   `capture::origins_tests`, existing F01 LIFO/generation/refusal checks, receiver
   grouping, tagged encoding and reader-boundary cases. Inspect warnings. The new
   module has three small tests and no large generated corpus.
2. Use one native extension from that candidate to run the two new public Ruby
   tests, affected capture/references/source/parser-boundary contracts and relevant
   Map integration/smoke checks. Require exact seven origins, no duplicates,
   pinned bytes/spans after CURRENT advances, and unchanged CURRENT on refusal.
3. Build one exact Core/Map artifact pair in the declared build context and reuse
   those bytes for the affected fresh installed contracts outside the checkout.
   Bind source/base, packages, loaded native, locks, fixtures, commands, failures
   and support tuple in the receipt. Confirm new engine module packaging and
   rerun the saved Reader/Source/reference journey against the installed artifact.
4. Root dispositions required candidate CI and integration applicability; changed
   package bytes inherit no earlier installed pass. Preserve all failed attempts.

No private application, Rails boot, DSL execution, DB, frozen experiment replay,
performance campaign, cap change, launch qualification or publication is part of
this slice. All 17 launch requirements remain unqualified.
