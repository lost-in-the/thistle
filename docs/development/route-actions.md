# Saved route action candidates

LOS-144 answers one question: which captured instance-method definitions are
conventional candidates for the explicit controller/action defaults of this saved
Rails route? Rust selects the answer; Ruby forwards primitives and Map displays
the typed witnesses. This is source implementation, with native, installed,
served and person acceptance **pending**. All 17 launch capabilities remain
unqualified. It adds no capture family, CLI, runtime resolver or Passage narrative.

```ruby
reader = Thistle::Reader.new(store, generation: saved_a)
begin
  answer = reader.route_actions(route_id, limit: 8, cursor: nil, max_bytes: 32768)
  # Follow answer['next_cursor'] on this same generation and route.
  candidate = answer.fetch('candidates').first
  source = reader.source(candidate.fetch('fact').fetch('id')) if candidate && candidate['source']
ensure
  reader.close
end
```

`route_actions` is a native operation over an existing saved route ID. Limits
default to eight rows/32 KiB, with ceilings 16/64 KiB. Bytes include the native
success envelope and one newline. A mandatory envelope or first candidate that
cannot fit refuses; smaller pages never skip a dropped candidate.

## Naming and evidence

`ascii_snake_path_v1` accepts literal strings from a runtime `route` with null
path/location. Controller labels optionally start with one `/` or `::`, followed
by slash-separated lowercase ASCII snake-case components. Each underscore word
starts with a lowercase letter and continues with lowercase letters/digits.
Capitalize each word, join namespace components with `::`, and append
`Controller` to the final component. Actions use the same lowercase snake-case
word rule, without slashes. Examples: `orders/index` means controller `orders`,
action `index`, owner `OrdersController`; `::admin/purchase_orders` means
`Admin::PurchaseOrdersController`. Original strings are preserved separately.

There is no singularization, inflector, acronym registry, constantization,
controller loading, inherited-action resolution or constraint execution. A
literal `orders_controller` means `OrdersControllerController`; no suffix is
silently stripped. Constant-style `Admin::Orders`, uppercase, Unicode, malformed
paths, dynamic/missing defaults and action punctuation are unsupported. Custom
`API` inflection may differ from conventional `Api`: a missing conventional
candidate does not prove absence of a runtime action. Rack endpoints, mounts and
redirects without supported defaults are unresolved. Even supplied defaults do
not prove that the endpoint is a controller, that a request matches, or that
dispatch/invocation occurred. Visibility, loaded-code coherence and binding stay
unknown. No generic create/save/INSERT branch follows from a route candidate.

Eligible methods use the existing saved method directory: `method`, static
evidence, instance (excluding singleton/class methods), exact recorded `owner`
and `method_name`. Source IDs, paths and spans retain the original evidence.
No route file/line is invented. The response retains the original route attributes
(including verb, route path, order, coherence and constraint metadata) and links.
Oversized original evidence refuses before cloning. It is never reparsed or
silently trimmed into a successful empty answer.

## Version 1 response

The envelope contains `generation`, compact `root`, original `route.attributes`
and `route.links`, `naming`, `status`, `candidates`, `candidate_count`, `coverage`,
`offset`, `next_cursor`, `continuation`, `unknowns`, `usage` and `semantics`.
Every compact identity carries generation, ID, kind, name, evidence, path and
`span` (the saved four-coordinate location or null). A candidate supplies this
identity as `fact`, `source_status` and a generation/ID `source` operation
descriptor, or null when no physical mapping was saved. Selection does no Source
I/O. Opening Source subsequently verifies captured bytes through the existing
Reader boundary, independent of CURRENT or live files.

| Status | Meaning |
| --- | --- |
| `unique_static_candidate_binding_unknown` | Exactly one conventional static candidate in the saved domain, with the relevant capture families complete; runtime binding unknown. |
| `ambiguous_static_candidates` | At least two static witnesses; no definition selected. |
| `no_eligible_recorded_candidate` | Complete saved search found zero eligible definitions; inherited/uncaptured/custom binding remains unknown. |
| `discovery_incomplete` | Relevant capture family or candidate discovery incomplete; counts/candidates remain qualified witnesses. |
| `unsupported_route_or_naming` | Unsupported defaults/form; no lookup or empty-success claim. |

`candidate_count.lower_bound` is a global witness count, including matches before
the current page. `exact` is true only after exhausting the exact range.
The separate global lookup exhausts zero/one candidates or stops after two
matches. Thus a late duplicate prevents prefix uniqueness on the first page.
Partial capture takes precedence in the primary status; the count still shows
multiple witnessed candidates. `coverage.discovery_complete` means a global
zero/one/two decision was reached, not that all candidates were returned or
captured. `page_complete` means the remaining candidate suffix is exhausted.
`capture_partial_or_unknown` requires exactly one complete source-inventory,
Ruby-declarations and Rails-routes coverage row. Missing/duplicate/partial rows,
or more than 1024 coverage rows, cannot claim complete capture.

Continuation uses the existing opaque `recorded-v1` token, selected generation,
scope `["route_actions", id]` and position `[candidate_offset, 0]`. Limits can
change. Tokens convey no trusted totals or authority; replay repeats charged
work. A continuation advances only over returned candidates. Invalid scope,
generation/positions, or zero-progress work exhaustion refuses. An admitted page
can carry candidates and work-partial coverage plus a continuation. Following
pages is finite; exceptionally large repeated prefixes can reach the explicit
work refusal instead of pretending that the rest was searched.

## Cost and alternatives

No second method index or route-by-all-facts scan is introduced. First selected
query pays the existing lazy Reader method-directory construction: one admitted
fact pass, digest creation and in-place sort, retained slot reservation, and the
existing full-domain construction ceilings. Repeated same-Reader queries reuse
it; reopening rebuilds on demand. The cost DTO records construction separately
from request visits/comparisons. The mutex covers lookup and bounded position
copying; it ends before identity/response construction and all Source work.

Per request, global lookup and page each pay a digest binary search plus exact
range checks. Pagination revisits the prefix to its offset, and is charged for
that repeated work. Limits are 20,000 visits (including bounded coverage rows),
100,000 comparisons and 32 MiB hashed/compared labels. A 32 MiB scratch
reservation remains held through native serialization. Before copying raw
route evidence, count its encoded bytes against the requested wire bound.
Projection has at most 16 compact identities and at most 16 shrinking output
attempts. Raw route copies/serialization and fixed-identity copies are accounted
by scratch and bounded wire admission, separately from method-label counters.
These are conservative source-derived allowances, **not** measured heap, RSS,
CPU quota or performance results.

Reusing `method_lookup::{lookup,page}` avoids another retained index and keeps
static-method eligibility/lifetime in one owner. Prefix-only paging would falsely
imply uniqueness. A custom count/index or persistent cursor directory would add
construction, retention, schema and maintenance costs. Reconsider the existing
repeated-prefix strategy only with complete-job evidence showing its work refusal
or cost matters. Root owns reconciliation into shared development decisions and
package manifests; this source slice does not change those retained files.

## Evidence and next owner

Direct source-only stdlib checks: `ruby test/test_route_actions_reader.rb`,
`ruby map/test/route_actions_presenter_test.rb`, and
`ruby map/test/route_actions_navigation_test.rb`. They check forwarding, strict
navigation, full collection/search context, escaping and forged-witness refusals
using independent display witnesses. Native tests in `route_actions_tests.rs`
are authored **UNRUN**, including naming, late duplicate, singleton exclusion,
source absence, partial coverage, scope and byte/work refusal cases.

Root owns finite admission for the authored **UNRUN**
`map/test/route_actions_app_test.rb` (mocked App) and
`test/test_route_actions_installed.rb` (real installed producer/Reader/Map).
The latter must run from outside the checkout, without checkout `-I` paths, using
isolated installed Core/Map and Rails 8.1.4. Its driver copies the fixture, boots
the producer, saves A and an explicitly partial negative generation, changes
bytes and publishes CURRENT B, then launches fresh Rails-free consumer processes.
Handwritten `expected_cards.json` is independent of the implementation formula.
It requires a first-page ambiguity witness for the late reopened `show`, original
route constraints, multiple routes sharing a method, custom/missing/inherited/
class-only/Rack/redirect negatives, and exact A Source after CURRENT B. The Map
mode follows the actual rendered candidate href to selected physical Source rows
while retaining generation/search/investigation. This Rack response check does
not establish actual browser scroll, keyboard/no-JS/narrow-screen or person
usability acceptance. Root retains those served and human checks and one
independent source review. Leah retains applicable acceptance; PM retains planning.
