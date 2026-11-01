# Thistle Map

Optional read-only views of a saved Thistle generation. This private implementation milestone contains **Find, Source, Links and Check**. It is an early integration slice, not the complete replacement for Woods Map.

The Source view reuses Woods Map's lossless syntax-highlighting component and token system. The Rails engine, Woods reader, Guide, historical tools and old endpoints are not dependencies. See [reuse provenance](docs/REUSE.md).

## Use

Both gems require Ruby 3.4 or later; the native Thistle source build supports Linux and macOS. Follow the [platform setup guide](https://github.com/lost-in-the/thistle/blob/main/docs/development/platforms.md), then build and install the sibling `thistle` gem and this gem from local artifacts. Registry names are working names; nothing has been published. Prepared release notes live in [CHANGELOG.md](CHANGELOG.md).

```ruby
require 'thistle/map'

reader = Thistle::Map::App.new(store: '/absolute/path/to/captured/store')
# Mount `reader` explicitly in a Rack-compatible host, behind its authorization.
```

For a private local Rack server, the included `examples/config.ru` reads the operator's `THISTLE_STORE`. Choose and install the Rack server separately, bind it to `127.0.0.1`, and open its loopback URL. The default gate requires both a loopback peer address and a loopback Host header. Forwarded headers do not bypass this gate. Do not deploy it behind a reverse proxy under default local settings.

For a host that already authenticates users, pass an explicit authorization callback and an exact allowed-host list:

```ruby
reader = Thistle::Map::App.new(
  store: '/absolute/path/to/store',
  allowed_hosts: ['code.example.test'],
  authorize: ->(env) { env['my_app.authorized_code_reader'] == true }
)
```

The callback must return `true` for the authenticated request. Use a trusted server-side environment key, not a client header. This app does not supply an identity service, sessions or TLS; the host owns those boundaries. Its read-only mode does not isolate it from the authority of its host process.

An optional `reader_factory` is a trusted adapter, not a sandbox. It must preserve generation and fact identities and validate source bytes, digests, and byte/line positions as the native reader does. Map checks display shapes and budgets; it cannot authenticate evidence invented by an adapter. For a structured Links page, Map reads at most one source file after checking the manifest byte budget, verifies its generation, fact and digest, and checks call positions against its bytes. Legacy links need no source read. Adapters must expose integer `manifest["schema_version"]` equal to 2 or 3 for compact call metadata, matching the saved generation. Both contexts use semantic Core Reader output; adapters do not decode tagged storage rows. Missing schema context is treated as legacy schema 1, where version 2 remains unavailable. Schemas 2 and 3 also accept version 1 metadata.

## Reading and interaction

- Search by a known class, method, route or file name. Each response shows evidence type and the saved capture identity.
- Open exact Source to read the captured file with real line numbers and the selected declaration's span. Exact Source beyond 256 KiB or 10,000 lines is explicitly refused by this view; the core source command remains the full-file path.
- Links labels unresolved symbolic references without presenting them as proven calls. Files beyond the web byte or newline budgets show a command fallback instead of a source anchor. Source also checks the complete file when opened. Lists page in groups of 50. Search shows at most 50 matches and asks the reader to narrow the query.
- Check exposes coverage and uncertainty. The UI never claims a saved capture establishes present working-tree or live application freshness.
- Every internal link and search carries the selected generation. A missing or invalid generation fails instead of silently switching to the newest one.
- Standard links, forms and focus behavior work without JavaScript. Optional letter shortcuts are disabled initially. Enable them using the visible checkbox: F Find, S Source, G Links, J/K results. They are focus-scoped and inactive during text entry, composition, modifier chords or text selection. Browser session preference is the only local state.

Source, labels and query text are escaped. A strict self-only script/style policy, no inline script, no-referrer and no-store headers apply. Only GET and HEAD are accepted. There is no filesystem path endpoint, command execution endpoint or mutation endpoint.

For saved model/class comprehension, Source reading links open
`/comprehension/contributions` or `/comprehension/methods`. Code comes before the
owner outline and progressive schema/association/callback/reference follow-ups.
The routes retain generation/search/investigation through the shared navigation
authority. They show identified contributions, not a concatenated effective runtime
class; duplicate definitions, precedence and source/runtime binding can remain
unknown. Runtime-model Source uses this surface when the capture includes the
optional explicit loaded-class ownership family; default captures are unchanged.

Each page requests up to eight Core row/candidate slots with a 32 KiB response
limit. Empty/generated/unknown rows cost one slot; duplicate candidates each cost
one. A compact outline and Core continuation retain the exact suffix. Anonymous
or repeated owner labels stay unknown without blocking later owners. Selected
files reserve a total of 64 KiB before deduplicated reads, then validate exact
identity/digest/bytes and at most 2000 aggregate display lines before highlighting.
An over-line file is wholly not admitted; missing source is a separate state.
Shared-file contributions use one code block with their span highlights and
physical in-page anchors, plus exact Source follow-ups.
These and the finite HTML body limit are display controls, not RSS or complete
native heap bounds. See the [source comprehension contract](docs/source-comprehension.md).
Native, installed/served, independent task and person acceptance for this new
journey remains pending; source wiring and pure checks do not qualify it.

## Saved job, mailer and template investigation

The source-wired journey follows declared inherited/local retry, discard and
rescue policy → potential mailer/action → explicit literal ERB template, variable,
partial and helper evidence. Start from a saved job registry or a supported typed
Source/Links anchor. Registrations and source options remain separate; ambiguous
or unloaded targets, dynamic selection, coherence, invocation and delivery stay
explicitly uncertain. ERB is escaped inert Source and is never evaluated.

Routes are `/job-mail/overview`, `/job-mail/registrations`,
`/job-mail/declarations`, `/job-mail/policy`, `/job-mail/handoff` and
`/job-mail/template_references`. Each page queries one Core family and follows
typed same-generation descriptors through the existing NavigationContext. The
default is eight rows/32 KiB; long witness URLs can reduce display-admitted rows
within the 64 KiB presenter budget. Native supplies all cursor positions. Existing
4096-byte/nine-field/full-24-ID collection, search-drop notice, access/GET/HEAD
and Reader close controls remain. Overview does not fan out to Source or parsing.

See the installed [job/mail/template contract](docs/job-mail-template.md).
Mocked source checks are not native, installed or served acceptance. A real
saved A/CURRENT B/fresh Reader/served Map task, desktop/narrow screenshots,
keyboard/no-JavaScript and applicable person checks remain pending. Broader mail
defaults/callbacks, alternate/HAML templates, history and full Passage remain
parent scope; this increment does not establish complete Woods replacement.
First installed cards pin Rails 8.1.4. Bare ERB names are local-or-helper candidates;
other receiverless calls are call-or-helper candidates. Worker contention returns
503/Retry-After:1 with explicit retry-page text; the page is not missing evidence.
Conventional implicit mail/template_name-only/positional render resolution is a
prioritized parent follow-up.

## Recorded route action candidates

Choose **Inspect controller/action candidates** from recorded route evidence.
The `/route-actions` page preserves original constraints and distinguishes
conventional static candidates, ambiguity, missing evidence, unsupported naming
and incomplete discovery. Follow an exact saved Source witness to its physical
line while retaining generation, search and the investigation collection. A
candidate is not proof of dispatch, invocation or request reachability.

The typed page makes one bounded Reader query and uses existing navigation;
the original route Source-context page retains its identity/condition display
and inherited full-fact read. No live controller lookup or route execution is
performed. See the installed [route/action guide](docs/route-actions.md).
Native, installed and served/person acceptance for this slice remains pending.

## Selected-action request Passage

Choose **Inspect potential request Passage** from saved route evidence, then
explicitly choose an action definition. `/passage/sequence` shows registered
filters and that action's source operations as a list. Only a supported direct
root-qualified create witness can admit a related potential save contribution;
index/helper actions do not inherit a generic model lifecycle. Registry order,
source order, applicability and execution remain distinct. Async and unknown
binding edges stop the narrative and offer labelled evidence links.

`/passage/export` uses the same selected action and typed page, with its own
continuation. One bounded Reader operation supplies each page; existing saved
generation/search/collection, Source, authorization and no-JavaScript navigation
remain in use. See the installed [Passage guide](docs/passage.md). This is a
source candidate; real installed/served/person acceptance remains pending.

## Repository validation

From the core project root after installing development dependencies:

```sh
bundle exec ruby -Ilib -Imap/lib -e 'Dir["map/test/*_test.rb"].sort.each { |f| require File.expand_path(f) }'
```

Tests exercise the actual reader integration, source bytes, generation pinning, malformed queries, source escaping, default and explicit authorization, DNS-rebinding-style Host mismatches, forwarded-header spoofing, read-only methods, bounded source and paged links.

Installed documentation includes [model presentation](docs/MODELS.md), [source comprehension](docs/source-comprehension.md) and [reuse provenance](docs/REUSE.md). The local browser checks and exact executed version tuple remain in the [historical repository validation record](https://github.com/lost-in-the/thistle/blob/f376e6b2ee8024a77d6ed1e0864e23406e8aff27/map/docs/VALIDATION.md). Unit/request checks do not establish accessibility or intended-user usability. Full Map job coverage, the richer investigation workbench, assistive-technology testing, performance qualification and launch parity remain open.

