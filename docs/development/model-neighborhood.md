# One saved model's schema and one-hop neighborhood (LOS-149)

Which named models and source sites surround this saved model, how are they
related, and what evidence supports each edge? Rust/public Reader owns that
selection. Map presents one bounded page; Leah owns applicable acceptance.
Root owns integration, new changed-scope R2 and later finite actual gates.
All 17 launch requirements remain UNQUALIFIED.

## Public Reader and saved evidence

~~~ruby
reader.model_neighborhood(model_id, family: 'edges', direction: 'outgoing',
  type: 'all', candidate: nil, limit: 8, cursor: nil, max_bytes: 32768)
~~~

The selected ID must be a saved rails_model, not a static class assumed to be a
runtime model. The Ruby method forwards primitives. This correction adds no
capture/schema/observer/Reader/C bridge/parser/directory/CLI/dependency/JS change.

DTO version 1 contains generation, compact root, model/table/primary-key scope,
family/direction/type/candidate, candidate_context, items, coverage, next_cursor,
cost, usage and semantics. IDs and table/key labels stay scoped to this saved
model and immutable generation. Equal labels do not merge identities.

* edges: outgoing association entries then other recorded outgoing links, or
  incoming saved links. Direction is incoming/outgoing; type is
  all/association/reference. Association-only outgoing needs no reference scan.
* columns: raw name/type/sql_type/null and the required saved tagged default.
  Current model schema requires that tag; a missing tag is invalid evidence,
  not a compatibility feature. There is no default_recorded or per-column
  default_presence alias. Global default_presence remains not_recorded.
* database: explicit unavailable physical database FK/index/ON DELETE inventory,
  never invented absence or inferred constraints.
* candidates: saved named representations for one outgoing edge. a:N selects
  an association ordinal; r:N a recorded link ordinal. candidate_context names
  the selector, association/reference kind, name and original target label.

Schema families require outgoing/all. Candidates require outgoing and exactly
one selector compatible with the type filter. Invalid IDs/positions/scopes,
missing facts, unsafe storage and integrity errors refuse.

Association edges retain the whole saved entry and exact fact_id/family/ordinal
witness, with origin_id referencing the response root. Polymorphic/unknown
targets remain rows without links. Reference edges move origin and candidates
once into their typed fields. Their recorded object contains only the effective
original link, link_ordinal, detail_omitted and match_basis; it contains no
duplicate identity or candidate aliases. Outgoing association_target_label links
are excluded before materialization because the declaration already appears.
Incoming such links remain explicitly original recorded references, without
inventing declaration options.

At most four candidates appear per edge, with global known matches and explicit
display omissions. Counts are saved representations, not distinct model
definitions. Static declaration sites, indexed observations and runtime metadata
are not automatically separate implementations or bindings. One candidate still
has unknown binding/coherence; zero can mean unloaded or uncaptured. Incoming
candidate search remains globally incomplete. Candidate pages enumerate the full
range without selecting a canonical first match.

Leading :: is removed only from association lookup keys through the maintained
constant_label rule. Original target/link/display spelling remains unchanged.
References and candidate continuation use the same normalized range, preserving
namespaces and original-byte comparison charging.

Literal false, zero, empty string and null retain their exact saved types.
Expression and opaque values remain separate and unevaluated. A literal null
does not establish DEFAULT NULL or absence of a clause: clause presence was not
recorded. SQLite raw defaults can be strings for boolean/integer columns.
Rails foreign_key/dependent options are not physical FK or DB ON DELETE facts.
Selection performs no resolver/constantize/inflector/application/DB/source/parser
access, full-fact expansion, callback analysis or execution/binding claim.

## Transactional admission and continuation

Reader defaults remain 8 rows / 32 KiB; ceilings remain 16 / 64 KiB. Wire sizing
includes native ok/result envelope plus one newline byte. Usage reports actual
returned rows and wire bytes. Mandatory-envelope/first-selected-row overflow
refuses; Map translates native budget refusal into an actionable display limit,
rather than reporting missing/invalid evidence.

The recorded-v1 scope is
['model_neighborhood',id,family,direction,type,candidate].
Columns/candidates use [offset,0]. Outgoing edges first use association ordinal,
then [association_count + reference_fact_position,reference_link_position].
Incoming uses the reference fact/link position. Positions do not grant authority
or assert counts/completeness. Changed limits are permitted; changed identity,
generation, family, direction, type or candidate scopes refuse.

Every component/row attempt stages its owned values and next position. The
position is committed only after row metadata and wire admission. A later
specific limit_exceeded keeps the already admitted prefix and resumes at the
failed step's input. A wire-deferred row never uses its post-row cursor. Only
safely consumed skips reported by the private reference adapter can advance an
otherwise empty budget-stopped page. First zero progress still refuses. Visits,
copies, failed metadata charges and attempts are never rolled back.

RequestWork exposes only finish_metadata to open its existing final 3 MiB.
Component metadata still uses the first 5 MiB; a failure poisons that allowance.
Only final bounded response sizing/serialization uses the reserved part. Total
metadata remains 8 MiB; no cap or work-counter reset is introduced. Other shared
limits remain 20,000 fact visits, 50,000 links, 100,000 comparisons and 32 MiB
labels. Reference component limits (16 MiB labels / 2 MiB output) still apply.
Only budget errors are caught for resumable stops; invalid/unsafe/other errors
propagate. A null component cursor with scan_complete false is never completion.

The crate-private select_filtered adapter accepts only an internal relation
enum, uses scope ['model_neighborhood_references',id,incoming,filter], and reports
safely consumed skips. Incoming label and relation comparisons and fact/link
visits are charged before rejection. Rejected links incur no detail/candidate/
metadata materialization. No filter enters public references Query, and its
ordinary unfiltered DTO/cursor scope is unchanged. Rooted association matching
is the intentional shared semantic correction. Internal cursor scopes cannot
be reused as public/unfiltered or differently filtered cursors.

Coverage page_complete describes the selected remaining domain.
last_reference_step describes just one completed/refused component attempt,
including row_retained and input/next/consumed-skip positions. It may describe a
wire-deferred row and is explicitly not whole-page completeness. Cost separates
reference_attempts, completed_reference_steps and completed_step_work; incomplete
failed-step work remains charged privately but is not falsely reported as part
of completed-step counters. Capture family count, examined non-complete families,
unexamined suffix count, family unavailable status and unknown remaining counts
stay distinct. A completed empty suffix does not erase earlier pages or repair
partial capture.

The existing lazy borrowed-label directory is reused, never duplicated. Its
separate at-most-100,000-fact construction/sort/retained-capacity work and actual
build/reuse counters remain visible without repeated constant accounting prose.
Reader-open facts and summed actual visits across its five passes remain separate. Fresh Readers rebuild; each
page repeats root projection, anchor/scope/coverage construction and candidate
range bounds. Incoming resumes consumed fact/link positions without replaying
their link prefixes. One 32 MiB scratch reservation remains through native
serialization; locks end before serialization/Source. These are accounting
bounds, not measured heap/RSS/CPU/speed claims.

## Map budget and accessible presentation

Dedicated route validation, nine fields, 4096 bytes, all 24 collection IDs,
atomic bounded-search drop and the existing notice remain NavigationContext's
authority. This correction changes neither App nor Nav. View changes only its
model_neighborhood_page admission/error handling; every other method, including
the entire Source method, remains byte-identical to the admitted 12a baseline.

One common GET form holds generation/model/collection/search state once for
schema/filter/candidate buttons. Button paths and all hrefs are generated through
Nav; escaped form fields use its admitted query. The current family/direction/
type is visible with aria-current. Unavailable columns/associations are visible
before the list/table and explicitly not known empty. Candidates name the edge
and original target. Static candidates have one named physical Source href,
rather than duplicate Links and Source URLs; runtime candidates use Links.
The selected root is already identified at the heading and has no duplicate
per-row navigation link.

Admission derives row count and native bytes jointly for each family/direction.
Let u be the actual escaped Nav Source URL with a 64-hex size placeholder plus
16 bytes for its physical line fragment; this placeholder is never a candidate
or emitted link. Each cursor-bearing control separately reserves
3*512+128 bytes. The unchanged layout reserves 4096+9u+cursor bytes (seven
hrefs and at most two query units of form values). Presenter controls reserve
2048+3u+cursor bytes (shared form values and one continuation href). Per row,
outgoing edges need at most four hrefs, incoming/candidates one, columns/DB zero.
Extra outgoing root-name repetitions reserve (L-1)*4096*5 bytes. The minimum
202 JSON bytes of required version/cost/usage headers are not rendered;
validation guarantees them and admission credits only those 202 bytes. Primary escaped
text reserves five times native JSON bytes; represented labels/options are not
also dumped repeatedly. The largest L <=8 leaving the measured compact-page
target is chosen, with no 1024-byte clamp. The 4626-byte scheduling target is
the measured literal four-long-candidate useful page with six non-complete
capture families, not a
claim that every arbitrary maximum-length saved value fits.

The pure budget-enforcing fixture at 24 IDs +256q and /map requires success,
not 200-or-422. It includes real Rust-shaped reader-open/directory/coverage/
usage metadata, four long candidate identities and continuation. Outgoing uses
L1 /4829 native bytes; incoming/candidates L4 /4829; columns/DB L8 /6475.
Actual complete markup still must fit 64 KiB. Exceptionally unfit first rows
remain honest actionable limits under unchanged native/display ceilings.

The full named HTML list is primary. A deterministic server SVG uses exactly
the same selected rows, with targets on a separate line. It is added only if
the whole diagram fits alongside the full list and layout reserve. Otherwise
an explicit whole-diagram omission notice preserves every named HTML edge;
there is no per-row graph pruning or guessed zoom threshold. No JS or layout
dependency is added. Existing attributed Woods dia/dw tokens remain. A maintained
client graph engine would add acquisition/runtime/CSP/keyboard/no-JS maintenance
for this finite one-hop job; reconsider only for a separately admitted richer
graph outcome with measured benefit. Woods engine code remains prohibited.
Root retains shared decisions and any future reservation/concurrency change.

## Correction disposition and evidence

R125's full initial review at 12a requested changes; its findings remain open
until Root's new changed-scope R2 disposition. The following are author
proposals, not independent acceptance:

| Finding | Correction / remaining gate |
|---|---|
| 01,12 | Joint family admission, shared controls, single identity hrefs, budget-enforcing 24-ID/256q pure success cases; App probe authored UNRUN. |
| 02 | Transactional component/row admission and existing final reserve; -3/-4 fact, metadata, first-zero and suffix regressions authored UNRUN. |
| 03 | Pre-materialization relation filter, private scope/skip positions, sparse hundreds-of-links and ordinary public parity regressions authored UNRUN. |
| 04 | Exact duplicate_user path ignored before initialize, preserving six source positions; real Rails/Zeitwerk gate UNRUN. |
| 05 | Independent nonempty Item/User incoming associations, ReportBuilder incoming references/physical Source, outgoing base and exactly one Admin::User runtime candidate; installed gate UNRUN. |
| 06 | Visible active filters/aria-current and unavailable-not-empty notices; pure presenter coverage. |
| 07 | Required default tag, no redundant default-recorded/presence aliases; missing-tag refusal. |
| 08 | last_reference_step/row_retained and explicitly completed-step work counters; native wire/metadata gates UNRUN. |
| 09 | Root origin ID and moved reference origin/candidates; alias refusal in presenter. |
| 10 | Borrowed leading-root association keys and consistent public references, with original labels intact; unit/real fixture gates UNRUN. |
| 11 | Named candidate_context and candidate page heading; pure presenter coverage. |
| 13 | Raw adapter oracle after A capture/publication and before edits, without casting or warming capture; real gate UNRUN. |

The producer pins Rails 8.1.4 and public sqlite3 :memory: config before Active
Record lazy load. A runtime-only reviewers declaration supplies ::User while
saved source/runtime coherence stays unknown; no excluded model file changes.
Consumer cards require real independent nonempty domains, all filter/edge/list/
optional-diagram/witness agreement, physical Source href -> A line after CURRENT
B, full candidate ranges and 24-ID/search pages. These, all Rust/native/compiler/
framework/installed/store/DB/server/browser/served/person execution and changed
App probes are AUTHORED UNRUN in this correction phase. Pure presenter/stdlib/
syntax/JSON/static-scope checks establish none of those actual gates.

Initial-phase failures/receipts remain unchanged. The correction's stricter
budget test first exposed insufficient native bytes, then an incoming row-count
threshold; both failed attempts are retained and corrected without weakening the
test. Root/reviewer prep overrun, partial/unmetered reads and reported EROFS/
output fallback remain explicit historical gaps. New prospective source controls
do not reset them or establish a whole-procedure control/performance claim.

At e4c95a7c8f32107726e73ca442a28508ad336a74, primary CI run 41305835017,
job 124845939754 compiled Rust and reported 198 passing invariants / one failed
metadata-exhaustion regression; downstream native/Core/Map/package steps were
skipped. The regression guessed that 16 KiB admitted an incoming row despite
repeated identity/component/page charges. Its replacement uses two raw links
whose metadata each charges over 4 MiB under the unchanged 5-MiB component
allowance, with oversized detail omitted from each small public row. It requires
exactly the first row, a refused second step, exact input continuation and a
fresh-request second-row suffix, plus first-row zero-progress refusal and the
existing 8-MiB total ceiling. No output/progress/reserve behavior or allowance is
changed for this test correction. The replacement is AUTHORED UNRUN here; the
observed e4 failure remains a failure, and subsequent-head CI is unaccepted.
Root owns R2, integration/watch and later finite actual gates; PM planning;
Leah applicable acceptance. No merge/publication or qualification is authorized.
