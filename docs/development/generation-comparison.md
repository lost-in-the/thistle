# Two saved generations: comparison component v1

LOS-151 asks what changed between two explicit saved investigations and which
recorded neighboring evidence merits inspection. This Rust operation and public Reader method are wired in source with
known-answer contracts. Historical 1fb CI compiled and reported 229 PASS / 2 FAIL;
f17 fixed the two fixture expectations, preserving schema-1 opaque and schema-2/3
equality controls; its exact source CI subsequently completed all eight checks
successfully. This current correction's native cases remain **AUTHORED UNRUN**;
f17 feedback does not validate changed bytes. Installed/Map/MCP/client/person acceptance remains open.
Root owns integration/review/execution; PM owns planning; Leah owns applicable
acceptance. All 17 launch capabilities remain unqualified.

## Request and ownership

The native operation is `generation_comparison`, with existing pinned
`handle` and `other_handle`, and these fields:

```json
{
  "selection": {"kind": "method", "name": "Order#schedule_receipt"},
  "family": "entity",
  "direction": "incoming",
  "limit": 8,
  "max_bytes": 32768,
  "cursor": null
}
```

`Query::parse(&Value)` validates typed selection and limits; `scratch()` proposes
one 32 MiB global admission; `select(&Reader, &Reader, &Query)` borrows both saved
Readers. Native dispatch atomically clones both existing `Arc<Reader>` values under the
registry mutex, releases it before analysis/I/O, and keeps the global reservation
through actual native envelope serialization. This component opens no store by
path and adds no index/cache; it reuses the existing Reader recorded-name directory.
The public Ruby method is
`left.generation_comparison(right, selection:, family: "entity", direction: "incoming",
limit: 8, max_bytes: 32768, cursor: nil)`. Both arguments are already pinned
Readers; no store path or moving revision is selected by this call. Thin Ruby
forwards once and neither closes nor reopens either Reader on refusal.

## Exact matching

| Kind | Saved semantic key | Eligibility |
| --- | --- | --- |
| `file` | exact `name` (captured path) | static evidence, name equals original path, physical location present |
| `class`, `module`, `method` | exact qualified `name` | static evidence; `attributes.name_resolution` must be `lexical` or `absolute_lexical` |
| `rails_model` | `attributes.model.name` | named saved representation |
| `rails_save_callbacks` | `attributes.callbacks.name` | named saved representation |
| `rails_job_mail` | `attributes.job_mail.class.name` plus `class.kind` | explicit `role: "job"` or `"mailer"` required |

Kind is always part of the key. `Order`, `OrderLine`, `Shop::Order`, `::Order`
and `order` are different query names; there is no prefix matching, receiver
guessing, namespace stripping, heuristic rename or normalization. Current capture
already emits an absolute declaration's qualified name without its leading root
marker; the matcher uses that actual saved name. Ambiguous relative declaration
paths and unresolved method receivers remain uncomparable. Anonymous registry
display labels do not supply keys. Other kinds require a separate supported
identity contract and are refused.

Each side uses the existing sorted recorded-name directory for an exact name/kind
range and global count. `schema::validate_facts` unconditionally validates model,
callback and job/mail saved identities for every supported schema: named
`fact.name` must equal the semantic metadata name; anonymous labels are excluded
by `candidate_name`. This is a closed validation property, not a producer/cohort
assumption. Source keys already use `fact.name`. No valid hidden registry alias
requires a full-domain query scan; an inspected mismatch fails as an invalid snapshot.

Without a role filter, the exact range total proves duplicate count and at most
two physical identities are projected. Unique eligibility is inspected before use.
For more than two duplicates, eligibility is explicitly unknown for uninspected
entries (`unsupported_name_resolution:null`, `eligibility_scan_complete:false`),
with a separate preview flag; ambiguity never selects a winner. Job/mail filters
inspect the complete exact name/kind range in bounded pages, count every matching
role and charge visits/comparisons to the shared work. If that entire role proof
cannot fit, the request refuses, never claiming uniqueness from a prefix.
Saved IDs, physical paths and ordinals are
retained as original evidence, never used as cross-generation keys. A unique
logical match relates saved representations; it proves no runtime binding,
canonical model identity, dispatch or loaded-source coherence.

## DTO and independent comparison axes

Version 1 retains the **ordered pair** of immutable generation IDs, root IDs and
schema versions, typed selection, matching counts/physical identities, family,
direction, bounded items, scan status and continuation. Capture provenance is a
fixed allowlist: generation, root_id, schema_version, source label,
commit_provenance and loaded_code_coherence. It copies no arbitrary producer,
diagnostic or manifest envelope. Root IDs are provenance, not application binding.

Entity results independently report `source`, `metadata`, `relationships`,
`line_diff`, presence and absence coverage. Statuses are `added`, `removed`,
`changed`, `unchanged`, `ambiguous`, `uncomparable`; line diff is explicitly
`unavailable`. A demonstrated changed axis makes the entity changed. Entity
unchanged requires all three axes unchanged; unknown source never becomes
unchanged from metadata equality. Missing source/relationships are uncomparable.

`metadata_only` requires validated unchanged source and unchanged relationships.
Changed registered metadata with unknown source is
`metadata_changed_source_unknown`. For example, changing a model's table field
keeps its logical `rails_model` key and changes metadata; it does not manufacture
a removed/added model or assert source equality.

Metadata projection includes actual `attributes`, removing **only** the enclosing
registry's generation-local ordinal from `model`, `callbacks` or `job_mail`.
Nested callback positions/ordinals, registration sequence, options, semantic array
order, duplicate entries, false/zero/empty values and missing-versus-null/default
presence survive. No recursive ordinal removal or semantic array sorting occurs.
Opaque metadata is compared as saved data, not interpreted as runtime semantics.

Relationship comparison preserves list order/multiplicity. It uses the maintained
borrowed `SemanticLinkView` decoder, including schema-3 compact wire calls; v1
named/v2 compact call fields share one semantic projection. Recognized physical
call/receiver/constant coordinates are excluded from relationship digests because
they have independent original witnesses. Unknown extension fields remain present.
Resolved targets are uncomparable here: generation-local target IDs require an
explicit cross-generation target mapping, which is not fabricated.

Source compares SHA-256 of each selected declaration/file's validated physical
byte span. It admits bounded file bytes before reading, reuses maintained
no-symlink blob/digest/UTF-8 validation, then validates source coordinates with
`schema::stored_facts`. Same manifest digest never bypasses blob validation.
Unrelated bytes outside the selected span do not change its source result. Both
original fact IDs, paths, full payload digests/byte counts and physical spans stay
available for pinned Source reveal. Presentation lines are null. Equal selected
bytes do not mean unchanged file layout, a line mapping or loaded-code coherence.
Added source has no prior lines. No textual line diff is computed. Only local
`source_attempt` or `source_bytes` admission failure degrades source to
`uncomparable`/`source_allowance` with omitted witness and pinned Source followups;
metadata/relationships continue. Spent attempts and bytes are never refunded.
Unsafe paths, corrupt/invalid blobs, metadata/global budget errors and all other
errors still propagate. A scoped addition/removal remains a presence result even
if its independent source axis cannot be admitted.

## Absence and capture scopes

A missing match is not automatically a deletion. File absence requires exactly
one `source_inventory` coverage row on each side, complete status and identical
nonempty recorded scope. Class/module/method absence additionally requires
matching complete `ruby_declarations` coverage, including equal recorded parser
policy/version fields where present. Missing, duplicate, partial, unavailable,
unknown or mismatched coverage cannot prove addition/removal. The result includes
the relevant allowlisted recorded scope/status/parser-policy fields. Unknown
coverage-policy fields or invalid optional parser labels also prevent absence
claims. Scope equality compares saved scopes;
it is not independent verification that the publisher captured everything.

Even a complete declaration result means absence **within those recorded source
scopes**, never deletion from the running application. Loaded registries are not
exhaustive inventories and cannot establish absence in this version. All other
missing matches remain uncomparable. Reopened duplicate labels stay ambiguous
even if the first physical declaration appears unique on a page.

## Nearby evidence and cursor

`family: "references"` selects direct A/B witnesses in one direction. Outgoing
witnesses walk only the unique selected fact's links on each present side.
Incoming witnesses use the maintained one-leading-`::` key normalization for
recognized constant receivers, constant occurrences and association target labels,
preserving their original saved spelling in `candidate_label` and `recorded_link`.
Thus `::Order.find` can witness `Order`, while `Shop::Order`, case and qualification
remain distinct. `inherits`, `includes`, `extends`, `prepends` and model base labels
keep exact matching. Omitted/implicit/dynamic
receivers supply no invented incoming class witness. Incoming rows remain label
evidence, including for a selected registry representation; they establish no
binding between source and registry. Every row retains side, generation,
direction, origin physical identity, original link index and complete semantic
recorded link. Missing-side references may still be useful inspection witnesses;
they do not prove the selected entity existed there.

Incoming method/file queries explicitly refuse with `unsupported_comparison`
before scanning: this witness contract cannot answer callers or file consumers.
Their entity/source and outgoing comparisons remain useful. This is a current
boundary, not permanent completion of the full replacement semantics.

Rows mean **potential evidence to inspect**. Execution, causality, exhaustive
impact, risk, invocation and test coverage are unavailable. An unrelated changed
entity is not a neighbor merely because its capture changed.

The bounded cursor string encodes:

```text
["comparison-v1", left_generation, right_generation, scope_sha256,
 side, next_fact_position, next_link_position]
```

Scope hashes version, full typed selection, family, direction, row limit and byte
limit. Reversed/different pairs, altered selections/filters/limits, malformed or
out-of-domain positions refuse. Cursors are positional, not authority tokens;
caller-supplied positions may skip work and never establish capture completeness.
Normal continuation preserves the exact next unconsumed work position. Row/byte
cuts never consume the withheld witness. Work spent examining it stays charged.
An exhausted allowance preserves the admitted prefix and remaining position;
zero progress refuses rather than returning a repeated token. Scan completion
only means the requested saved domains were searched; capture completeness is
independent. There is no fabricated total for unsearched witnesses.

Outgoing cursors retain the same tuple and scope. They normalize to the next
selected physical fact/link or the next present side, including absent sides and
completed link lists. An untrusted unrelated fact position before the selection
cannot carry its link offset into the selected fact; it normalizes to link zero.
Positions after the selection may skip it, as with existing positional cursors.
No unrelated-fact traversal is needed to canonicalize or emit these positions.

## Cost and alternatives

One existing `model_brief::RequestWork` covers both exact-range lookups/visits, coverage,
source validation, metadata, relationships, reference traversal and finalization:
20,000 fact visits, 50,000 link visits, 100,000 label comparisons, 32 MiB label
bytes, 1 MiB total selected file bytes, 16 source attempts, 8 MiB encoded metadata
work with the existing 3 MiB finishing reserve. No reset/rollback or independent
left/right allowance exists. Root candidate visits, binary lookup comparisons
and compared label bytes are reported. Reference fact/link visits are reported
separately. Already completed Reader-open validation, by-ID/path/search cache
construction and Reader admission precede this operation; they are not free
per-page work or new measured results.

Default output is 8 rows/32,768 bytes, ceiling 16/65,536. Count the actual
`{"ok":true,"result":...}` native envelope, without assuming a newline. Mandatory
identity or first-row overflow refuses. Staging reserves an additional 512 bytes
for final scan/cursor digit growth and cost fields. Final actual encoding is
checked too. Metadata is counted before cloning; one selected value/link is
limited to 128 KiB, selected relationship digests to 1,024 entries. Bounded source
buffers and maintained validation allocations fit within the proposed conservative
32 MiB request admission. These are accounting budgets, not measured RSS/latency.

Existing serde/serde_json, SHA-256 helpers, maintained wire decoder and filesystem
validation serve this bounded component without dependencies or a custom diff
library. The initial linear root scans refused realistic pairs before answering;
the correction reuses `Reader::recorded_candidates`. Its first use constructs the
existing <=100,000-fact directory per Reader in O(N log N), with borrowed labels,
about one usize slot per fact, a retained global budget reservation and explicit
construction statistics. This is the directory's existing separate whole-domain
admission, not 20,000 per-query fact visits or free warm work. Fresh Readers rebuild;
other operations and repeated queries on the same Reader reuse it. The DTO carries
both sides' `built_this_request`, construction visits/key/sort bytes/comparisons,
capacity and retained bytes. On reuse, those construction counters are historical
directory costs, not visits performed by that query. Failure of global admission
still refuses; cold construction is not a speed claim.

Normal exact root lookup costs logarithmic bounds plus <=2 candidate visits per
side; job/mail role filtering costs the complete equal-key range, with no pairwise
cross product. Incoming references still require bounded resumable linear scans;
outgoing references walk only selected links. Repeated whole-domain root scans,
pairwise matching, materializing all facts, a second persistent
index/store open, a Ruby comparison engine and presenter-derived impact were
rejected for cost/semantic/ownership reasons. Consider a maintained textual-diff
library only with an actual line-diff contract and bounded source job. Root owns
any shared decisions record update and measured reconsideration of cold/open/query
cost. No speed result, benchmark or architecture completion is claimed.

## Evidence and remaining integration

The native tests, real-Reader forwarding tests and fresh installed producer/cards
are authored. Historical 1fb CI's 229 PASS / 2 FAIL and Root's earlier forwarding
receipt retain their exact identities. f17's all-eight source checks include the
fixture replacements. This correction's native tests remain **AUTHORED UNRUN**;
no old result qualifies changed bytes.
Installed/Rails/DB/capture/Map/MCP/client/person gates remain open. Pure syntax,
JSON and ownership checks have separate retained receipts. Source-only checks
cannot prove these authored contracts pass. The facade tests double only Native
transport and load the real public Reader; they do not establish native semantics.

Root has registered the module, paired registry lifetime handling and public
facade in source, with this contract in Core's installed document selectors.
Independent review and affected native/installed boundary gates remain required.
Shared guidance/decisions follow their existing writer ownership. Repository-only
fixtures at `test/fixtures/los151_generation_comparison/`
(README and served protocol) retain the later Reader-to-Map/MCP/client/user
evidence obligations. They are not installed package inputs.

This increment does not deliver actual commit/branch comparison. LOS-12 must
resolve selectors to immutable recorded commit/tree/capture identities during
capture/preparation, preserve dirty/same-SHA payload provenance, and supply real
history/range/co-change/author/test associations. Ordinary Map GETs must not run
Git or mutate checkouts. Timeline, since context, selected-context Impact and the
complete feature-planning/intermittent-mail-failure investigations remain open,
along with named evidence, physical reveal/return and narrative handoff quality.

## Fidelity refinement: concrete values and captured text

Phase one supplied independent digest/status axes; those alone did not explain
what changed. The same source component now adds the following **authored, unrun**
entity evidence. The request, public Reader API, families, DTO version 1 and
paired reference cursor remain unchanged. No Map/MCP consumer has been wired.
Root owns native/runtime gates, Map/MCP integration and actual acceptance gates.

`comparison.metadata.evidence` carries pinned `context.left/right` generation and
fact IDs, `items`, `status`, `scan_complete`, `unsearched`, `reason`, and exact
saved `fact` followups. Each item gives a named RFC 6901 JSON Pointer rooted at
`attributes` and separate `before`/`after` states:

```json
{
  "path": "/model/table",
  "before": {"present": true, "value_status": "shown", "value": "orders"},
  "after": {"present": true, "value_status": "shown", "value": "archived_orders"}
}
```

Missing is `{"present":false,"value_status":"missing"}`, with no value key.
Present null is `{"present":true,"value_status":"shown","value":null}`.
False, zero, empty strings/arrays/objects and default presence retain their actual
JSON types. A value exceeding 2,048 encoded bytes is explicitly `omitted` with
its saved presence, type and reason; the whole value is not silently clipped or
replaced by a digest. Family followups open the original saved facts. If even the
compact first named row cannot fit, the request refuses. Later byte/work cuts
preserve admitted rows, mark unsearched work, and retain those followups.

The walk borrows the actual attributes, merges canonical serde_json object keys
once and compares arrays positionally. It never guesses stable array-element
identity: insertion/reordering can change several index paths. Only the exact
enclosing registry ordinal is skipped; nested callback registration ordinals and
order remain evidence. Opaque JSON is shown as saved typed data, without assigning
unsupported runtime meaning to extension fields. A structural type change or
missing container is shown as a whole field when admitted; it is not recursively
reinterpreted. Keys escape `~` and `/`; pointers are bounded to 4,096 bytes and
walk depth to 64, with explicit unsearched states at either bound.

The existing `limit` admits at most 8 changed-field rows by default, 16 maximum.
Only discovering another differing value after the limit stops for `row_limit`;
equal trailing subtrees are really traversed and charged, so exactly-limit answers
can report complete. Work/depth/path/output cuts still mark unsearched. Stopping
before later values sets `scan_complete:false` and `unsearched:true`;
no total or completeness is invented. Fully scanned metadata can still have
omitted values, with `status:"partial"`, `scan_complete:true` and
`reason:"values_omitted"`. Unchanged metadata emits no changed rows. Unsupported,
ambiguous or absent pairs supply no fabricated field comparison. There is no new
changed-field cursor: the explicit next action is pinned `fact` inspection.
The outer entity scan is incomplete when field traversal stops; its separate
`content_evidence_complete` flag distinguishes information omission from traversal.

`comparison.source.witness` gives a **single first-difference window**, not full
hunks or a line mapping. Both selected source files are read and validated once
using the maintained blob/coordinate validation. Their request-local buffers are
retained just long enough to derive evidence, within the same total 1 MiB source
allowance. A linear byte-prefix scan finds the first difference; up to 64 bytes
of preceding context and at most 512 raw UTF-8 bytes per side are shown. Window
boundaries are valid character boundaries even if the differing byte lies inside
a multibyte character. No suffix matching, edit-distance matrix, parser or dynamic
application evaluation is introduced.

Each side retains generation, original fact ID/path, full captured-payload and
selected-span digests, exact physical window byte/line bounds, exact text and its
digest, and selected-span byte counts omitted before/after. The Source followups
retain each original saved ID and generation after CURRENT changes. A shorter
side may end at the insertion/deletion point; it receives no invented prior
lines. `complete_hunks:false` and `line_mapping:"unavailable"` remain explicit;
the existing `line_diff` axis stays unavailable. Later changes outside a window
must not be described as examined. Missing source gives unavailable evidence;
unchanged validated spans make a difference witness not applicable. Output/work
admission failure gives an explicit omitted state and pinned Source followups.

All work shares the original `RequestWork`. Structured metadata value visits
consume its fact-visit pool in addition to exact matching-range visits; key
comparisons, path bytes, leaf comparisons, value projection, staging encodes and
final serialization are charged without resets. The source witness reserves five
times the combined selected-span bytes against label-byte work before scanning,
covering the prefix pass, region line counts and span/window hashes. This is
prospective accounting, not a measured instruction/RSS/latency bound. Source
bytes and metadata value limits were not raised. Source windows and each field
row are staged against the whole actual native envelope with the existing
512-byte finalization margin; final actual encoding and the shared final reserve
remain authoritative. No whole-domain source copy or new retained index/cache exists;
the existing Reader directory reservation and construction cost are separate above.

Alternatives considered: an established full textual diff would add dependency,
algorithm and hunk-semantics obligations before that complete user job exists;
whole declaration text can exceed the response budget; hashes alone fail the
explanation question. The small prefix/window algorithm gives demonstrative,
revealable captured text with O(A+B) admitted source work and no new dependency.
The borrowed structural metadata walk avoids a copied normalized tree or a Ruby
diff engine; its maintenance obligations are the pointer/presence/ordinal/order
rules and bounded cuts above. Reconsider full hunks or a changed-field family
only under a separately settled completeness/continuation contract. Root owns
any shared decisions record update. No comparative speed claim is made.

Independent authored cards now require the old `!!value` and new `value == true`
normalization source, declaration parameter/default source, concrete model table
values, and raw adapter database-default values with their actual types. The raw
oracle is read after each capture, avoiding prewarming capture. A present-null
default must remain present and unchanged. Native cards separately demand
missing-versus-null, false/default values, nested registration ordering, opaque
field preservation, oversized-value omission, row/work/byte cuts, UTF-8 windows,
physical Source after CURRENT C, and integrity refusal before any content witness.
The installed consumer's corruption control uses only a bounded disposable copy
of the small public fixture; it preserves the original store. All new native,
framework/DB/producer/consumer/Reader/Map/MCP/client/person controls remain **UNRUN**.

The current main root ID is a canonical-path hash; it is not validated repository,
ref, commit or tree binding. This component only validates the saved root ID's
schema shape and retains it as provenance. The DTO says
`root_id_binding:"unvalidated_repository_ref_commit_tree"`. No Git collection,
HEAD label, branch/worktree substitution, committed-source claim or actual
commit/branch comparison was added. LOS-12/160 and the complete investigations
remain open; the component alone does not fulfill LOS-151.

## R131 source correction evidence boundary

The author proposes the following corrections against the initial f17 source
review. These are implementation dispositions, not independent finding closure.
Root owns changed-scope R2, signed delivery and actual native/installed gates.

| Finding | Correction and authored evidence |
| --- | --- |
| R131-01 | Existing exact-range directory matching; one 90,390-fact publication and Reader pair reused cold/warm, with construction versus per-query costs exposed. Closed registry-name validation negative controls cover schemas 1/2/3; role filtering crosses a 64-position page and counts all duplicates. |
| R131-02 | Maintained one-root constant normalization, with original labels retained; native receiver/occurrence/association cases and a real public fixture `::Order.find` card, excluding qualified/double-root false matches. |
| R131-03 | Explicit unsupported incoming method/file refusal, while entity and outgoing contracts remain useful. |
| R131-04 | Selected-link outgoing traversal and canonical pair-scoped physical positions; absent-side, untrusted offset and exact next-link cases. |
| R131-05 | Only source-local admission degrades, preserving metadata/relationship evidence and pinned Source; pre-spent source attempt/global metadata and existing corrupt-source controls remain explicit. |
| R131-06 | Limit checked when another changed field is found; equal trailing subtrees are visited and charged. |
| R131-07 | Wired-source headers distinguish historical failed CI, f17 replacement expectations and current unrun corrections. |
| R131-08 | Focused native coverage above, plus method/module/file, callback and job/mail kind cases; Root's excluded lifetime/handle controls are preserved. |

All new native cases are **AUTHORED UNRUN** in this source-only correction. The
earlier 1fb CI failure and f17 replacement-test identities remain unchanged;
neither qualifies changed bytes. Pure syntax/JSON/static checks have separate
scope. Actual Map/MCP/client/person explanation and the wider Git/history/impact
outcomes remain open; all 17 launch capabilities remain unqualified.
