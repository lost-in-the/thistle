# Two saved generations: comparison component v1

LOS-151 asks what changed between two explicit saved investigations and which
recorded neighboring evidence merits inspection. This Rust operation and public Reader method are wired in source with
known-answer contracts. Native compilation, installed execution and Map/MCP/client
or person acceptance remain **UNRUN**. Source wiring is not runtime evidence.
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
path and has no persistent index/cache. The public Ruby method is
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

Every request scans the complete left and right borrowed fact domains under one
shared allowance before using any unique match. It counts every duplicate,
projects at most two physical identities per side and reports exact known omitted
identity counts. A matching prefix never proves uniqueness. Exceeding the entire
proof allowance refuses the request. Saved IDs, physical paths and ordinals are
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
Added source has no prior lines. No textual line diff is computed.

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
witnesses come from the unique selected saved fact. Incoming witnesses compare
exact recorded constant receivers, constant occurrences, `inherits`, `includes`,
`extends`, `prepends`, model base labels and association target labels. A method selector is
not a class label. `::Order` stays distinct from `Order`; omitted/implicit/dynamic
receivers supply no invented incoming class witness. Incoming rows remain label
evidence, including for a selected registry representation; they establish no
binding between source and registry. Every row retains side, generation,
direction, origin physical identity, original link index and complete semantic
recorded link. Missing-side references may still be useful inspection witnesses;
they do not prove the selected entity existed there.

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

## Cost and alternatives

One existing `model_brief::RequestWork` covers both matching scans, coverage,
source validation, metadata, relationships, reference traversal and finalization:
20,000 fact visits, 50,000 link visits, 100,000 label comparisons, 32 MiB label
bytes, 1 MiB total selected file bytes, 16 source attempts, 8 MiB encoded metadata
work with the existing 3 MiB finishing reserve. No reset/rollback or independent
left/right allowance exists. Root lookup alone visits `left.facts.len() +
right.facts.len()` every request. Reference fact/link visits are reported
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
library. A complete borrowed linear matching scan was chosen over a new directory:
it supplies an explicit proof and simple ownership, with no persistent memory or
invalidation. Cost is O(A+B) fact/label work per GET, plus admitted selected bytes,
links and one-direction witness scan; there is no pairwise cross product. This
deliberately refuses larger domains rather than claiming hidden completeness.

The existing recorded-name directory is a plausible later alternative, but its
first whole-domain build/sort, retained reservation and typed key proof must be
charged and shared. Pairwise matching, materializing all facts, a second persistent
index/store open, a Ruby comparison engine and presenter-derived impact were
rejected for cost/semantic/ownership reasons. Consider a maintained textual-diff
library only with an actual line-diff contract and bounded source job. Root owns
any shared decisions record update and measured reconsideration of repeated scan
cost. No speed result, benchmark or architecture completion is claimed.

## Evidence and remaining integration

The native tests, real-Reader forwarding tests and fresh installed producer/cards
are authored; Rust compilation, store/Reader runtime, Rails/DB/capture, build,
install, Map/MCP/client/browser and human acceptance are **UNRUN**. Pure syntax,
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
Stopping before later values sets `scan_complete:false` and `unsearched:true`;
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
consume its fact-visit pool in addition to the two full matching scans; key
comparisons, path bytes, leaf comparisons, value projection, staging encodes and
final serialization are charged without resets. The source witness reserves five
times the combined selected-span bytes against label-byte work before scanning,
covering the prefix pass, region line counts and span/window hashes. This is
prospective accounting, not a measured instruction/RSS/latency bound. Source
bytes and metadata value limits were not raised. Source windows and each field
row are staged against the whole actual native envelope with the existing
512-byte finalization margin; final actual encoding and the shared final reserve
remain authoritative. No whole-domain source copy or retained index/cache exists.

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
