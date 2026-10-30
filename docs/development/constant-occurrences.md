# Saved nonreceiver constant occurrences

LOS-136 records lexical constant reads beyond call receivers. The original
source base is PR111 at `89ca3d48755c9f3639f70792b811d0c64e1d186d`, containing
PR109 at `b7b9eab5404d61984842394d6641edc878ab8509`. Root separately transferred
the recognized-family seams and authorized a normal source merge of PR110 at
`9c0bb785165b74e1db033a27929ded93f2ae9a60`. That second parent supplies the
existing root-qualified label/charging adapter; it must not be copied or
reimplemented on the original base. These are source dependencies, not inherited
runtime acceptance. This checkpoint and its regressions are **unexecuted**.

## Occurrence contract

Each admitted maximal static `ConstantReadNode` or `ConstantPathNode` contributes
one distinct unresolved `references_constant` object link to its lexical origin.
`Kit::Button` has one occurrence for that exact target and none for prefix `Kit`.
Different sites stay distinct. A leading `::` remains in the target and syntax.
The existing file origin covers top-level and ordinary block/DSL bodies; real
class/module/method origins replace it. No method, executed task or dynamic self
is invented. Ordinary child traversal, node charges and historical LIFO order
remain intact. No second full AST walk or retained occurrence index is added.

The version-1 `attributes.thistle_constant` assertion contains exact source
`syntax`, `rooted`, nullable `lexical_scope`, `role` and a half-open four-coordinate
`location` tuple. Roles describe immediate syntactic edges: `argument`,
`predicate`, `rescue_class` or `value`. Container expressions may give an inner
read a value edge. Lexical scope is the existing enclosing namespace label,
not a reconstructed constant lookup environment or runtime binding. Origin
IDs and file digests continue to identify saved evidence.

Direct static constant call receivers retain only their existing grouped call
evidence. A dynamic receiver expression can still contain actual constant reads;
its terminal path suffix is not fabricated into a static constant target.
Declaration names, assignment targets, superclass and class/module mixin labels,
strings and comments are excluded. Actual reads within string interpolation are
Ruby expressions. Superclass/mixin raw-label matching is outside this rule;
this does not claim to fix PR110's F03. Unsupported dynamic declarations keep
their refusal/diagnostic behavior and their bodies stay unsearched.

The producer reuses the existing bounded constant-label classifier (256 bytes,
bounded path depth). An oversized admitted label refuses capture. A dynamic or
unsupported-depth path reports unavailable with a diagnostic and conservative
partial coverage; actual inner expressions still traverse. No diagnostic or
capacity ceiling is increased.

## Before/after known answers

The dedicated harmless fixtures and public test were authored before producer
changes. They are labelled expectations, not reproduced runtime results.

| Syntax | Original base | Selected occurrence answer |
| --- | --- | --- |
| `Loader.for(CoreModel, :assoc)` | Loader call receiver only | CoreModel argument site |
| `value.is_a?(CoreModel)` | Local receiver call only | CoreModel argument site |
| `rescue ErrorType` | No constant occurrence | ErrorType rescue-class site |
| `{ primary: CoreModel }` | No call/constant occurrence | CoreModel value site |
| `{ primary: Kit::Button.new(...) }` | Already a call receiver | Same earliest grouped call; no added occurrence |
| `Kit::Button` / `::Kit::Button` | No occurrence | Two exact full-path sites, no Kit prefix |
| Two separate `CoreModel` reads | No occurrence | Two sites, not one label group |
| `Other::CoreModel` | Separate namespace label | Never a basename match to CoreModel |
| Declaration names, quoted text, comments | Not caller reads | No accidental occurrences |

The public expectations include class, method, file and rake-block origins;
six separate CoreModel declarations force late ambiguity beyond the inline
candidate prefix. Incoming and candidate continuations must reach all sites,
preserve original rooted syntax and follow Source after live bytes and CURRENT
change. These are pending checks. The producer alone does not complete that
public journey.

`dynamic_receiver.rb` separately requires two actual CoreModel argument reads
inside dynamic receiver expressions, with no fabricated `Child` terminal label.
The unavailable dynamic path remains diagnosed. It must not suppress those
inner reads merely because an enclosing expression is used as a receiver.

## Recognition and compatibility

The transferred implementation must recognize this family only in schema 3,
only version 1, with a closed validated metadata shape and static/unresolved
context. Exact syntax, target/root relationship, coordinates, source bytes and
fact containment must agree. Metadata remains a publisher assertion, not proof
of reparsed source semantics or execution. Schema 1/2 and unknown numeric
extension versions remain opaque with literal target matching. Recognized
malformed or contradictory call/constant families refuse rather than downgrade.
New links remain ordinary objects; call metadata, tag 0, format version, ABI and
public API are unchanged. There is no automatic migration.

The reference adapter must use PR110's existing borrowed original/key label
contract. Only a recognized constant label removes exactly one leading `::` for
matching. Original bytes remain visible and charged. Generic labels and opaque
metadata do not gain normalization. Existing `kind=None` candidate lookup,
directory, pagination, global ambiguity, generation pinning and budgets remain
unchanged. A future typed-kind lookup must revisit the F02 adapter invariant.

## Construction, retention and downstream cost

Capture carries a small role with each existing pending node and classifies each
maximal eligible path once. It allocates one ordinary link/metadata object and
source-syntax string per admitted nonreceiver site, with no dedup map or copied
AST. Unlike simple call groups, repeated constant sites add repeated evidence.
Every append checks `max_links` and charges the existing serialized evidence
budget before retained state mutates. Stored schema-3 call rows stay compact;
constant occurrences retain full objects. No memory or speed improvement is
claimed. Encoded charges are not heap/RSS measurements.

Retained generation size grows with occurrence count and syntax length; current
store lifecycle retains generations until removal. Reader admission, per-request
scratch/output limits and materialization now include the added ordinary objects.
Incoming reference scans and shared model-brief work encounter more links; Rails
combined publication budgets also include these links and bytes, leaving less
room for runtime observations. An input previously admitted may now refuse or
yield a bounded partial page. Continuations remain necessary; partial/unavailable
is never exhaustive no-match. These amplification costs require affected later
checks and are not evidence of private-app capacity, support or performance.

Alternatives considered: inventing call receivers would corrupt settled call
semantics; grouping reads by label would lose distinct sites; recording every
prefix would multiply evidence without proving namespaces; another full walk
would duplicate traversal/ownership work. The existing generic object-link path
with narrowly recognized metadata is the bounded design. A compact constant tag
or richer scope resolver would create additional format/maintenance costs and
is outside this outcome.

Self-review covers receiver suppression, maximal-path ownership, assignment and
declaration negatives, dynamic refusals, LIFO ordering, exact positions, append
atomicity, original-byte charging, old/opaque compatibility and downstream
retention. Compilation, behavior, independent review and installed applicability
remain unverified. Root owns their disposition; all 17 launch rows stay unqualified.

## Finite later validation

After source review settles an exact composed candidate and Root grants the
separate finite execution claim, stop dependent steps on failure:

1. Run the focused native occurrence, recognized-metadata/coordinate, references
   and original-charge checks once, with existing PR111 origin and F01 diagnostic
   LIFO/generation/refusal regressions, parser and reader-boundary contracts.
2. Use that candidate native extension for the new public Reader/reference/Source
   tests and affected existing capture/call/encoding/legacy contracts. Require
   exact fixture sites, rooted/namespace controls, late ambiguity, finite pages,
   saved Source/digests after CURRENT changes and unchanged CURRENT on refusal.
   Inspect warnings and affected shared Rails-budget checks.
3. Build one exact Core/Map artifact pair in its declared context. Reuse those
   bytes for affected fresh installed contracts outside the checkout, the same
   saved-source/reference journey, and relevant Map integration/smoke checks.
   Bind source/base/merge parents, package and loaded-native hashes, locks,
   toolchain/support tuple, fixtures and all failed attempts in the receipt.
4. Root reconciles current required CI and both source-parent integration
   applicability. Changed artifacts inherit no old installed result. PM owns
   administration and Leah the applicable acceptance decision.

No test, typecheck, native/candidate execution, application/DSL evaluation,
capture/store/DB, build/install, benchmark, frozen replay, cap change, launch
qualification or publication is authorized by this source checkpoint.
