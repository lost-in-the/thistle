# One saved model's schema and one-hop neighborhood (LOS-149)

This bounded customer view asks: **Which named models and source sites surround
this saved model, how are they related, and what evidence supports each edge?**
Leah owns applicable acceptance. Root owns integration, the full independent
source review, shared package/document selectors and decisions, and later actual
native/framework/installed/served gates. This source increment qualifies none of
the 17 launch requirements.

## Public Reader and DTO

```ruby
reader.model_neighborhood(model_id, family: 'edges', direction: 'outgoing',
  type: 'all', candidate: nil, limit: 8, cursor: nil, max_bytes: 32768)
```

The exact selected ID must be a saved `rails_model`, never an arbitrary static
class assumed to be a model. One native operation owns all semantic selection;
the Ruby method forwards primitives. There is no CLI, capture, schema, observer,
store, native C bridge, dependency or JavaScript change.

Version 1 returns `generation`, compact `root`, `model`, `family`, `direction`,
`type`, `candidate`, `items`, `coverage`, `next_cursor`, `cost`, `usage` and
`semantics`. Root includes saved ID/name/kind/evidence/path/location only. Model
includes name/table/primary_key/base/superclass/abstract/inheritance/source and
coherence; these labels remain scoped to the selected saved identity and
generation. Table/key equality does not merge model identities.

Families:

* `edges`: outgoing association declaration entries, then other recorded outgoing
  links; or incoming recorded links selected by the existing reference contract.
  Direction is `outgoing` or `incoming`; type is `all`, `association` or `reference`.
  There is no combined whole-schema or multi-hop traversal.
* `columns`: raw name/type/sql_type/null and tagged default, with explicit
  `default_recorded` and `default_presence: not_recorded`. This field reports
  whether the saved value exists, not whether the database has a DEFAULT clause.
* `database`: explicit unavailable physical FK/index/ON DELETE inventory. It
  invents no absence, inventory or relationships.
* `candidates`: all saved named representations for one outgoing edge. `a:N`
  identifies the selected model's association entry ordinal; `r:N` its recorded
  link ordinal. These are validated selectors, never constant names to resolve.

Schema families require outgoing/all scope. Candidates require outgoing and one
selector; their type scope cannot contradict the selected edge. Invalid IDs,
types, positions, scopes, missing facts and storage/integrity failures refuse.

An edge retains `origin`, relation/type/direction, original target label,
`target_status`, binding unknown, at most four compact candidates, global known
candidate matches, candidate-search completeness/omissions and selector. An
association adds the **whole saved association entry**, with exact witness
`fact_id/family/ordinal`. Polymorphic/unknown targets stay rows even without links.
Recorded reference rows retain the original component's origin/link ordinal/link,
effective evidence and detail-omitted flags in `recorded`; candidate identities
are moved to the edge's `candidates` array rather than copied twice. The outgoing
`association_target_label` link representation is suppressed because that exact
declaration already appears. Incoming association links are labelled recorded
references to association targets, without inventing missing declaration options.

Candidate counts are **saved representations, not distinct model definitions**.
Static declaration sites, indexed observations and runtime model metadata are
not automatically separate implementations or bindings. Even one candidate has
unknown binding/coherence. Zero matches means missing or unloaded/uncaptured,
not a proof that the constant does not exist. Incoming candidates identify the
selected label only and retain incomplete global candidate search. Namespaces
and original evidence spelling follow the existing reference/directory policies.

Literal null, false, zero and empty string retain their exact saved primitive
types. Expression and opaque values remain separately tagged and unevaluated.
Missing saved values remain unavailable. No explicit default-clause-present bit
exists; a literal null cannot establish DEFAULT NULL or absence of a default.
Raw SQLite defaults can be strings even for boolean/integer columns. Rails
association `foreign_key`/`dependent` options are not physical DB constraints or
ON DELETE. No automatic inflection/resolver/constantize/application/DB access,
binding, dispatch, execution, source parsing or source reads occur in selection.

## Continuation, work and wire admission

Default limits are 8 rows / 32 KiB, ceilings 16 / 64 KiB. Byte admission includes
the native `ok/result` success envelope plus one newline byte, with actual
`usage.wire_bytes_including_envelope_and_newline` and returned row count. The
mandatory envelope or first selected row exceeding the budget refuses. Later
wire overflow removes only a suffix and preserves the **dropped row's input
position**, never its post-row component cursor. No eligible row is skipped.

The existing `recorded-v1` generation-bound cursor scope is
`['model_neighborhood', id, family, direction, type, candidate]`. Columns and
candidate pages use `[offset,0]`. Outgoing edges use association ordinal first,
then `[association_count + reference_fact_position, reference_link_position]`;
incoming uses the reference fact/link position directly. No opaque count or
completeness assertion from a cursor is trusted. Following returned cursors
from the beginning exhausts the selected recorded domain. Changed limits are
allowed; changed model/generation/family/direction/type/candidate scopes refuse.

References reuse `references::select_scoped` with a shared `RequestWork`, one row
at a time to keep exact wire-cut boundaries. Incoming resumes fact/link positions
without replaying consumed link prefixes. Every call repeats anchor identity,
scope/cursor and small coverage construction; outgoing repeats bounded candidate
range work. Reference filtering charges rejected rows too. An excluded outgoing
association metadata family advances by its known array length without visiting
or expanding entries. Association-only outgoing pages need no reference scan.
A component can exhaust shared
work with `scan_complete: false` and null next cursor: null alone is **not**
completion. A previously admitted outer prefix continues from that component's
input position on a fresh request; first-row zero progress refuses. An empty
searched step can still advance with an explicit cursor. Other component errors
propagate; no generic error-to-empty-success fallback exists.

One RequestWork retains the existing 20,000 fact visits, 50,000 links, 100,000
comparisons, 32 MiB compared/hashed labels and 8 MiB processed metadata bounds;
reference component ceilings (including 16 MiB label work and 2 MiB component
output) still apply. Metadata is sized before projection/copy, and final
construction/serialization/bridge copies are charged. Exhausted metadata can
refuse the whole request rather than invent completeness. RequestWork's counters
remain private; this DTO reports reference steps/scan/comparison/label counters,
wire usage, explicit zero source attempts and the existing budget policy.

The existing lazy generation-local borrowed-label directory supplies candidate
ranges and global counts. Its construction visits at most 100,000 saved facts,
sorts in place, reserves retained slot capacity under the aggregate Reader/query
budget, and reports its separate build/reuse/retained-capacity cost. There is no
second index or route-by-all-facts scan. Fresh Readers rebuild; each page repeats
root projection and initial directory range bounds. Reader-open five fact passes
are reported separately through the existing baseline. One conservative 32 MiB
transient reservation stays alive through native serialization; locks used by
the directory/registry end before serialization or subsequent Source operations.
These bounds and counters are not measured heap, RSS, CPU or speed claims.

Coverage separates recorded family status, capture partiality/omitted coverage
families, current remaining-domain scan completeness, known remaining counts and
unsearched input. Unknown counts are null, never zero. A completed empty suffix
does not erase previous pages or repair partial/unavailable capture.

## Map fit and maintained-tool decision

Dedicated `/model-neighborhood/FAMILY/DIRECTION/TYPE` pages validate exact model,
generation, family, filters, candidate selector and cursor before ReaderFactory.
The family/filter route encoding preserves the existing nine fields, 4096 bytes,
24 collection IDs and atomic search drop with its existing visible notice.
Source and other destinations shed neighborhood controls; changing filters
starts a new cursor domain. Only NavigationContext constructs hrefs, with strict
IDs and validated physical line fragments. Every arbitrary captured label is
escaped in HTML, SVG and URLs.

The existing repository has no graph engine/runtime/dependency. This finite
slice reuses the attributed Woods `dia`/`dw` presentation tokens and builds a
small deterministic server SVG. The immediately visible named HTML list is
primary; the optional diagram uses exactly the same Rust-selected edge array,
full endpoint names, types and directions. Repeated endpoints are edge rows,
not new model definitions. No labels are hidden until a guessed zoom threshold.
Long diagram labels have an immediate full named/list equivalent. Columns and
Database facts sit beside the heading, including on native `rails_model`
source-comprehension entry; static classes receive no assumed model link.
The entire existing `View#source` stays byte-identical.

Reusing a maintained client layout engine would add a runtime, acquisition,
layout/escaping, CSP, keyboard and no-JS maintenance for at most 16 rows; the
checkout has none to reuse. A whole graph/index framework or Woods engine code
would exceed this one-hop job. The local SVG needs only deterministic row
placement; the accessible list supplies names and links under overflow.
Reconsider a maintained layout library only for separately admitted richer
graph jobs with measured fit/maintenance benefit. Root synchronizes this
decision into the shared decision record; this writer owns only this contract.

Before the single Reader call, Map reduces row/DTO budgets using conservative
repeated-href, dual SVG/list label escaping and markup reserves. Actual complete
markup including layout still must fit 64 KiB, otherwise an explicit display
limit refuses the page. There is no independent graph pruning or hidden row
selection in Ruby. Long labels/defaults with a two-ID/q context are covered by
pure mocked display admission; real narrow-container/zoom usability is unproven.

## Evidence and remaining gates

Standalone Reader forwarding and presenter/navigation/mocked App tests are pure
source checks, with no native/framework/store/server/browser activation. Native
tests, real Rails 8.1.4 producer → saved A/partial → CURRENT B, fresh Rails-free
installed Reader/Map consumer, independent answer cards and visible keyboard/
no-JS/narrow/real-zoom protocol are **AUTHORED UNRUN** in this assignment. Native
regressions cover typed defaults, ambiguity, unknown/polymorphic rows, finite
filters/candidates, first-row refusal, dropped reference-row input positions and
one admitted row followed by shared zero progress. Real producer raw adapter
types are compared without casting them into synthetic boolean/integer answers.

Initial pure presenter execution found a frozen-string SVG mutation; the next
attempt exposed an over-specific expected wording. Later pure-check harness
attempts corrected Ruby keyword argument bracing and an escaped Source proof
marker. A rejected patch was a no-op; a search confirming that no-op returned
its expected no-match status. All attempts remain retained and are not native/
framework defects or acceptance results.
Root must settle shared package/doc integration, run its independent review and
the affected actual contracts/CI/support checks. The new installed entry is
deliberately non-automatic and grants no runtime lease. No person acceptance,
launch qualification, benchmark, merge or publication is claimed.
