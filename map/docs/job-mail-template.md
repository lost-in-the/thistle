# Investigating a saved mailing job

Source-only LOS-148 checkpoint: the dedicated presenter is implemented; the
Core Reader/capture hooks are now wired in source; App/View route wiring and the
actual installed/served journey remain Root-owned and **UNRUN**. This document describes the intended supported path and
does not advertise a currently working route on main.

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
generation state. Root supplies the actual projection-route adapter; until then,
family links say “projection route not integrated” rather than guessing routes.

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
[the Core contract](../../docs/development/job-mail-template.md). Pure presenter
checks cover escaping, same-generation refusal, Root navigation delegation and
typed continuation. They do not prove the integrated server, browser usability,
keyboard focus or accessibility. Desktop/narrow screenshots and real keyboard/
no-JS follow/back tasks remain UNRUN; use the authored served journey after
Root's actual route/server/package admission.

Broader mail defaults/callbacks, HAML/alternate template languages, historical
changes, test relevance and full Passage remain explicit parent obligations.
