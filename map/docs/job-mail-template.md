# Investigating a saved mailing job

Source-only LOS-148 checkpoint: Core and Map routes/presentation are wired in
source, composed with published LOS147 Map checkpoint
`43b2bca7555b8b62f970bc9751939226a274f4ef`. Actual native/framework/installed/served
execution and acceptance remain **UNRUN**. This does not advertise an accepted
or currently deployed route on main. Root owns review, packaging and finite
execution; Leah owns applicable acceptance.

Start with a saved job registry. Inspect registrations to read recorded exception
labels, opaque handlers and shared superclass rows. Follow declarations to the
captured local class, superclass policy and perform-method candidates. Read
`retry_on`, `discard_on` and `rescue_from` syntax separately from registrations.
An inherited declaration can be inspected in its actual superclass source;
an opaque registered Proc does not reveal its retry parameters or prove a
source registration association.

From a saved perform method, inspect handoff evidence. A constant receiver and
action call may lead to one or several saved method candidates. An unloaded
target has no captured candidate; that does not prove the call cannot happen.
Duplicate declarations remain ambiguous. Calls to `deliver_later`/`deliver_now`
are source-potential delivery requests, not evidence of invocation or delivery.

From a supported mailer method, inspect explicit literal template selection.
Follow the saved ERB file to variable reads, helper candidates and explicit
slash-qualified partial candidates. ERB is inert source: neither it nor its
helpers are compiled/evaluated/dispatched. Variable values, helper binding,
dynamic template selection, implicit defaults and runtime dispatch stay unknown.

The presenter consumes typed bounded `Reader#job_mail` answers. All candidate
identities and continuation descriptors originate in Rust. Each generation must
match the explicitly pinned Reader. Map never computes selection, candidate
positions, template paths or semantic answers. Source/Links witnesses go through
the existing injected NavigationContext, which owns normalized query/selection/
generation state. View supplies the admitted projection-descriptor adapter to
that same authority. The presenter has no independent URL or selection policy.

Actual source routes are `/job-mail/overview`, `/job-mail/registrations`,
`/job-mail/declarations`, `/job-mail/policy`, `/job-mail/handoff` and
`/job-mail/template_references`. Family is in the path. Destination fields are
only saved `id` and optional native `cursor`, plus the existing generation,
selection and bounded search state. Unknown fields/routes or a malformed,
wrong-generation/id/family `recorded-v1` cursor refuse before ReaderFactory.
Cursor scope is exactly `['job_mail',id,family]`; Ruby computes no next positions.

Each page makes one public `job_mail` call and uses its compact root identity.
The default is eight rows/32 KiB; display admission can request fewer rows when
long full-collection witness URLs would exceed the existing 64 KiB rendered
presenter budget. Native still supplies the actual continuation. The public
Reader ceiling stays 16 rows/64 KiB; web parameters do not override admission.
Encoded-envelope, generation/root/family, row type, typed candidate descriptor,
unknowns and continuation are validated before presentation. No Source/parsing
fanout occurs in overview and no expanded `Reader#fact` fallback supplies job-page
identity. Missing Reader/native APIs or output limits explicitly refuse.

Source and Links offer progressive policy/handoff/template actions for supported
typed anchors. Job registry Source uses `fact_identity` after source-unavailable,
never an expanded fact fallback; without compact identity it refuses. Model
source-comprehension contributions can link their actual captured class/method
anchors. An untyped file-reference Source URL does not invent a file fact ID;
open the saved ERB file fact to inspect its template references. Merely reading
Source/Links does not automatically query any job family.

All generated links preserve the selected saved generation and up to 24 collected
IDs within the existing 4096-byte/nine-field limits. Search is dropped atomically
with the existing visible notice when it cannot fit; collected IDs are retained.
Access, same-origin/host checks, GET/HEAD behavior and Reader ensure-close remain
unchanged. Markup stays a plain String with escaped values, no `html_safe`/`raw`.

Pages expose coverage, omissions and explicit continuation. Reaching the end of
a page domain does not prove complete capture or execution. A missing/oversized/
unsupported source explanation is unknown, not an empty successful policy. Source
hints without captured identity do not turn into verified Source links.

Presentation uses the existing escaped semantic HTML, notice/table/list/reading
patterns and token stylesheet already attributed in [REUSE.md](REUSE.md), pinned
to Woods Map `29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9`, MIT notice retained in
`map/LICENSE.woods-map.txt`. No new upstream asset/engine/index/runtime was copied.
No new JavaScript is required for the presenter. Root's served path must preserve
Find/Source/Links/Check, keyboard focus, narrow screens, IME input and no-JS links.

The independent fixture cards and exact native/shared DTOs are in
[the pinned Core source contract](https://github.com/lost-in-the/thistle/blob/0630045a9b1d2ff7cf77e2148878d7187f540dd7/docs/development/job-mail-template.md). Pure mocked
source checks pass: job/mail navigation 3 tests/75 assertions, isolated mocked
routes 16/32, presenter 2/21, and existing LOS147 navigation 4/41. They cover typed
followups, explicit Source/Links entry actions, no family fanout, safe ERB source
escaping, before-factory scope refusal, unsupported APIs, malformed envelopes/
descriptors, HEAD/close, full collection and search-drop notice. Reader/highlighter
are doubles; no Native, Rails, store, real server or browser is loaded by those
probes. Ruby/node syntax checks also pass. They do not prove installed integration,
browser usability, keyboard focus, IME or accessibility. Desktop/narrow screenshots
and real keyboard/no-JS follow/back tasks remain UNRUN; use the authored served
journey after Root's finite package/server admission. The installed Rack script
now uses the actual source route `/job-mail/overview`; a Rack call is still
separate from a served browser task.

Broader mail defaults/callbacks, HAML/alternate template languages, historical
changes, test relevance and full Passage remain explicit parent obligations.
