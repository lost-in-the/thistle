# Collect and resume saved evidence

Open a fact in Source or Links and choose **Collect in investigation**. The
Investigation page keeps an ordered selection from that one saved generation.
Choose **Remove … from investigation** to remove an item. Find and the visible
navigation remain available. No JavaScript is needed for these actions: they are
ordinary GET links, and the Find form retains the collection. Keyboard focus,
Skip to evidence, optional letter shortcuts, text/IME handling and the existing
narrow-page wrapping styles are retained. Actual browser usability still needs
the applicable human check; source and mocked checks do not establish it.

Keep the **Reopen this investigation** focus URL. Closing and reopening it selects
the same generation and IDs, including after CURRENT advances. It carries no
access token and grants no access: the recipient needs an authorized Map mount
with the same retained capture. A missing or invalid generation refuses; Map
never switches the collection to CURRENT. A missing fact remains visibly missing
and stays in the focus URL until removed. Source and Links destinations from the
collection carry its generation and selection; Source loads the saved bytes only
when followed. Facts without captured source offer Links without inventing a file.

The route is `/investigation?generation=GENERATION&selection=ID,ID`. Both
generation and each fact ID are 64 lowercase hexadecimal digits. An empty
selection is allowed with an explicit generation. Order is significant;
duplicates, malformed fields and unknown fields refuse. Investigation URLs accept
only these two fields. No notes, free text, paths, credentials, bearer tokens,
cookies or session identity are added. Search keeps its existing literal query
contract on Find and evidence pages; it is omitted from the focus URL.

The server saves no collection. There are no browser notes in this slice, no
local-storage content, synchronization, mutation endpoint, provider or analysis
framework. The standard peer/Host/origin/host-authorization gate runs before
Reader construction. GET/HEAD-only handling, no-store/no-referrer and the strict
CSP still apply. URLs may be logged by the host or shared by the user; even
opaque fact IDs and generation IDs can disclose a selection. They do not contain
captured names, paths or notes.

## Budgets and operating limits

| Boundary | Limit and refusal |
| --- | --- |
| Request | 4096 encoded query bytes; at most 24 distinct IDs. Malformed state returns 400; a selection budget refusal returns 422 before Reader construction. |
| Identity work | At most 24 `Reader#fact_identity` indexed ID lookups in supplied order. Each call reserves its full 32 KiB encoded-response allowance before lookup, including missing or failed items: at most 768 KiB total response allowance. No retry or fallback to `fact`, `facts`, `references`, source, candidates or Ruby analysis. |
| Rendering | At most 256 KiB rendered investigation content and 320 KiB complete HTML page. Escaping expansion counts. Refusal returns 422 with no successful partial collection page. |
| Navigation | Retain saved generation and the complete collection within 4096 query bytes. Drop optional Find context first and explain that omission. Refuse if mandatory navigation cannot fit. No silent selection truncation. |
| Lifetime | One Reader per authorized request; App closes it on success, HEAD, missing evidence and refusal. No session cache or growing server collection. |

These bounds cover collection work after Reader opening. Opening a Reader still
validates the saved capture and creates its existing ID index under Core budgets;
it is not constant-cost whole-request work. At most one compact identity is
retained for rendering at a time alongside the bounded growing HTML string. The
32 KiB native response cap is independent of the rendered byte budget. Actual
installed/native cost and browser behavior require exact-candidate evidence.
Each row's evidence and remove links carry the complete selection. That repeated
URL cost is bounded by 24 rows and the query ceiling, and is included in the
rendered byte budget; it is not treated as free markup overhead.

Identity says which saved fact was selected, with kind, evidence origin, optional
captured file/line and full ID. It does not project arbitrary attributes or infer
analysis. Capture coverage can be partial or unavailable; empty or missing
selections do not establish absence of behavior. Check remains the coverage
destination. Existing specialized detail presenters keep their own pinned
generation links; use the focus URL or browser Back to return to a collection
when following a detail destination that does not carry collection state.

## Fit and maintenance decision

The [pinned Woods Map Trail product contract](https://github.com/lost-in-the/woods-map/blob/29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9/docs/design/notes/trail.md)
informs the identifier-only focus URL, small ordered selection and separation
from notes. This is conceptual precedent, with no copied Trail source or engine
code. Existing authorized Map component attribution stays in
[REUSE.md](REUSE.md) and its MIT notice. Thistle deliberately refuses a missing
generation rather than following that precedent's fallback behavior.

Existing `URI`/ERB helpers, Rack routing, layout, CSS and bounded Reader seam fit
this small state better than adding a router, query-state package, session store,
workspace framework or JavaScript controller. There is no new dependency or
asset. The maintenance cost is a small immutable URL parser, identity-budget
adapter and escaped presenter plus narrow App/View/Find URL wiring. Consider a
different state format only if the explicit 24-ID outcome changes; do not add
compression or persistence simply to bypass the declared request budget.

`Reader#fact` was considered and rejected because it expands outgoing link data.
`references(limit: 1)` was also rejected: resolving even one relationship can
build/sort the full recorded-name directory. The supporting Core
`fact_identity` operation projects six compact fields using the existing ID
index, without relationship selection, attribute expansion or inventory scans.
Core owns that seam and its native tests. Map must refuse an older Reader that
lacks it, rather than widening reads to approximate it.

Pure-helper and mocked source tests are development feedback. Native/request
journeys, installed Map bytes and actual no-JavaScript keyboard/narrow-page
checks remain separate gates. This collection slice does not qualify L15 or any
of the 17 launch capabilities.
