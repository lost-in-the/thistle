# Thistle

> **Very early alpha — not recommended for use.** Thistle is an experimental
> development project, not ready for production or general use. Its interfaces,
> storage formats and behavior may change. Results and supported environments
> are still being verified; do not rely on it for important decisions.

Thistle is a Rust evidence engine packaged as a Ruby gem, with a thin Ruby layer
for explicit Rails introspection. This is an early implementation
milestone of the [reviewed product plan](https://chatgpt.com/space/page_83d1d4a1a4ec81918d7310c21061c4e4).
It is not yet a launch replacement for Woods and makes no comparative speed claim.

The repository [mission](https://github.com/lost-in-the/thistle/blob/main/docs/MISSION.md) defines the governing product goals. Find the full launch scope, acceptance sources and live plan through the
[project scope index](https://github.com/lost-in-the/thistle/blob/main/docs/PROJECT_SCOPE.md). Contributors
and agents should use the [workflow](https://github.com/lost-in-the/thistle/blob/main/docs/development/agent-workflow.md) and
[portable configuration guide](https://github.com/lost-in-the/thistle/blob/main/docs/development/agent-configuration.md).

The engine handles static capture using Prism's established parser, validates
fact and source identities, publishes immutable generations, and answers queries.
It does not execute the inspected Ruby files. The Ruby bridge exchanges bounded
JSON batches, releases the GVL during Rust work, and always frees native response
buffers. There is no Ruby engine fallback.

Capture uses vendored Prism 1.9.0 in its guarded CRuby 4.1 compatibility
mode, independent of the host Ruby. Capture metadata records this mode and
parser policy; older manifests without those fields have an unknown grammar.
This mode does not establish complete Ruby 4.1 language or host support.

## Build the alpha source gem

Source development supports Linux and macOS with Ruby 3.4 or 4.0 and Rails 8.1 integration. The
primary and minimum CI pairs, including exact patches, live in
[`.github/ci-policy.json`](https://github.com/lost-in-the/thistle/blob/main/.github/ci-policy.json); the Gemfile reads that same
Rails default. See the [platform setup guide](docs/development/platforms.md) for
native macOS, Linux, a dedicated Docker environment and installation into a Rails
application. Both gems require Ruby 3.4 or later. Use Rust 1.90.0, a C compiler,
Ruby development headers and libclang 18. Cargo dependencies are vendored and
locked for offline source-gem builds. Public platform qualification and
precompiled gems remain launch work; passing these development cohorts does not
qualify other Ruby/Rails combinations or platforms.

The [CI policy decisions](https://github.com/lost-in-the/thistle/blob/main/docs/development/decisions.md) explain the selected
cohorts, their maintenance policy, and the separate historical experiment profile.
For repository contributions, use [one fragment per change](https://github.com/lost-in-the/thistle/blob/main/docs/development/changelog.md).

```sh
bundle install
bundle exec rake test native map
bundle exec rake installed
gem build thistle.gemspec
gem install --local thistle-0.1.0.pre.3.gem
```

If libclang is installed in a nonstandard directory, set `LIBCLANG_PATH` to its
directory. `THISTLE_CARGO` may identify a specific Cargo executable. Source builds
must use the locked vendored dependencies; a build that cannot find them fails.
This development package deliberately refuses public RubyGems publishing.

Installed packages include the platform guide and the tagged-call, loaded-model,
callback, Find, route-constraint, model-reference and Markdown report contracts in
`docs/development/`. Contributor policy, the launch ledger and historical
validation records remain in the repository; these packages do not qualify any
launch requirement.

## Inspect source

```sh
thistle capture ./my-app --output ./my-app/.thistle
thistle find OrdersController --store ./my-app/.thistle
thistle model-brief MODEL_ID --store ./my-app/.thistle --generation GENERATION_ID
thistle export-model-brief MODEL_ID --store ./my-app/.thistle --generation GENERATION_ID
thistle source FACT_ID --store ./my-app/.thistle
thistle links FACT_ID --store ./my-app/.thistle
thistle check --store ./my-app/.thistle
```

An explicit Ruby call can compare one saved file with a workspace supplied by the
operator:

```ruby
reader = Thistle::Reader.new(store, generation: generation)
begin
  result = reader.source_freshness("app/models/order.rb", workspace_root: workspace)
ensure
  reader.close
end
```

The result distinguishes matching, changed, unverifiable and not checked. Omitting
`workspace_root` performs no live filesystem access. Ordinary Source remains
saved-generation data, and Check still reports freshness as not checked. The
comparison checks the recorded digest; it does not validate the saved blob or
prove loaded-code coherence. See the [source freshness contract](docs/development/source-freshness.md)
for path, byte, race and work limits. The visible Map action is a later integration
step; this Reader operation does not add an implicit live read to Map.

For larger source trees, opt in to a higher traversal budget with
`thistle capture ./my-app --output ./my-app/.thistle --max-nodes 3000000` or
`Thistle.capture(root: path, output: store, limits: { max_nodes: 3_000_000 })`.
The default is 1,000,000 visited nodes and the provisional ceiling is 5,000,000;
other limits retain their defaults and ceilings. This counts nodes visited by
extraction after Prism parses each file, not all parser nodes. It is not a parser
stack or process-memory limit. A limit refusal publishes no new generation.
New captures record effective limits and visited nodes in their producer metadata;
older captures do not acquire this metadata retroactively.

New captures use snapshot schema 3, with `producer.call_target_schema: 2`
and `producer.link_encoding_schema: 1`. Capture and Reader APIs return semantic
call-link objects. Their `thistle_call` extension remains
`{version: 2, data: [kind, name, omitted_limit, safe_navigation,
[start_byte, end_byte, start_line, end_line], receiver_location_or_null]}`;
the receiver location uses the same four-coordinate tuple. On disk, schema 3
may encode an eligible static unresolved call link as `[0, target, data]`.
Other links retain their complete objects. The Reader retains stored rows and
materializes semantic objects only for requested responses. Call targets,
unresolved labels, grouping and captured source bytes retain their meaning.

Consumers must use the manifest's `schema_version` to interpret stored evidence.
Schema 1 treats extension versions other than 1 as opaque, including an otherwise
valid compact-looking version 2. Schema 2 recognizes strict metadata versions 1
and 2; schema 3 additionally recognizes the tagged storage rows. Producer metadata
never selects a format. See the [tagged-call contract](docs/development/tagged-call-encoding.md).

Explicit `Store#publish` uses the capture's `schema_version` selector. An absent
selector means legacy schema 1. Explicit schema-1/2 publication keeps its legacy
representation and generation identity rather than migrating it. Unsupported or
malformed selectors are refused. New readers retain old generations; engines
that support only schema 1/2 refuse schema-3 stores. Use the matching Core and Map
`0.1.0.pre.3` pair for new stores and call display.

Queries return JSON except `export-model-brief`, which writes bounded Markdown
to stdout. Errors return structured JSON on stderr and a nonzero exit.
`thistle help` describes the stable literal action names. Every query identifies
its generation; pass `--generation ID` to revisit the same captured evidence.
Missing generations are refused, never replaced silently with current results.

```ruby
require "thistle"
reader = Thistle::Reader.new("./my-app/.thistle")
begin
  facts = reader.find("OrdersController", limit: 20)
  source = reader.source(facts.first.fetch("id"))
  puts source.fetch("content")
ensure
  reader.close
end
```

`Source` returns the full captured file with its digest and the selected fact's
byte/line location. Links remain explicitly unresolved unless evidence resolves
them. `Check` verifies captured bytes; it does not assert live source or Rails
freshness. Coverage distinguishes unavailable and partial families from empty
successful results.

For a saved `rails_model` ID selected through Find, `model-brief` returns a bounded
investigation brief: recorded fields/associations, incoming/outgoing label references
and registered-callback candidates with source-supported potential requests. Pass
`--generation` explicitly; `--limit` defaults to 8 per family (1–16), and
`--max-bytes` defaults to 32768 (at most 65536, including the JSON newline).
Unknown binding, partial capture, omissions and unsearched evidence remain explicit.
Follow the returned fact IDs and source anchors using the same generation.
The [loaded-model contract](docs/development/loaded-model-evidence.md#model-investigation-brief)
describes its evidence and work limits. Ruby exposes the same operation as
`reader.model_brief(model_id, limit: 8, max_bytes: 32768)` on its pinned handle.

For a saved model or class, `reader.source_comprehension(model_id,
family: "contributions", limit: 8, cursor: nil, max_bytes: 32768)` returns
identified owner/declaration contributions; `family: "methods"` pages recorded
method-owner candidates. Each page has up to eight row/candidate slots by default,
including compact rows for generated methods or unknown anonymous/repeated owner
labels. Follow the exact returned continuation on the same Reader; unknown owners
do not hide later concern/superclass rows.
Duplicate definitions, unsupported precedence and source/runtime coherence remain
explicit unknowns. See the [source comprehension contract](docs/development/source-comprehension.md).

For a saved job/mail registry, class/module, method or ERB file fact,
`reader.job_mail(id, family: nil, limit: 8, cursor: nil, max_bytes: 32768)`
returns one bounded family. Use an explicitly generation-pinned Reader; `nil`
selects a parse-free overview. Families are `overview`, `registrations`,
`declarations`, `policy`, `handoff` and `template_references`. The public ceilings
are 16 rows/64 KiB. Follow Native's continuation on the same saved generation.
Registered handlers, source-declared options, potential mailer/template candidates
and execution are separate; duplicate/unloaded targets and dynamic selection
remain explicit unknowns. See the [job/mail/ERB contract](docs/development/job-mail-template.md).
Native, installed and served acceptance for this source-wired journey is pending.

For a recorded route, `reader.route_actions(route_id, limit: 8, cursor: nil,
max_bytes: 32768)` returns conventional saved controller/action candidates,
original route constraints and exact Source witnesses. Global ambiguity,
unsupported naming and incomplete discovery stay explicit; a unique static match
never proves dispatch or request reachability. Follow the returned cursor on the
same generation. See the [route/action contract](docs/development/route-actions.md).
The Map entry is **Inspect controller/action candidates** on recorded route
evidence. Installed, served and person acceptance for this new slice is pending.

For one recorded route, `reader.passage(route_id)` returns saved action choices
without choosing a definition. Pass an explicit saved `action:` ID to inspect its
registered filters, source operations and supported potential save/job/mail
boundaries; `family: "export"` returns the same page's evidence as bounded text.
An index or helper action does not acquire a model-save branch from unrelated
callbacks. Runtime binding, conditions and execution remain unknown. The default
is eight rows/32 KiB with Native continuation on the same generation. See the
installed [selected-action Passage contract](docs/development/passage.md).
Its real Rails-installed and served acceptance remains pending.

Use `export-model-brief` to share that saved model summary as deterministic
Markdown, with explicit uncertainty and generation-pinned literal evidence
commands. It requires the generation and embeds no captured source bodies or
store paths. `--max-bytes` separately bounds the selected JSON response and the
complete Markdown report; escaping can cause an explicit report refusal. See
the [Markdown report contract](docs/development/model-brief-markdown.md) for
limits, safe caller-owned redirection and what a recipient needs to resolve
the evidence. Exporting does not upload or publish the report.

## Observe an already booted Rails application

Run this explicitly in the application's trusted runner process:

```ruby
require "thistle"
Thistle.capture(root: Rails.root.to_s,
                output: Rails.root.join(".thistle").to_s,
                rails: Rails.application)
```

Rails observations inherit the application's authority. The current route batch
records observed runtime facts and unknown source/runtime coherence. It does not
fabricate source positions, prove immutable application boot, or claim that a
route is callable without constraints. Static capture never boots Rails itself.

To include model/concern ownership, explicitly supply already loaded classes and
a boundary; this optional family performs no class discovery or method execution:

```ruby
Thistle.capture(root: Rails.root.to_s,
                output: Rails.root.join(".thistle").to_s,
                rails: Rails.application,
                source_comprehension: { models: [Order], stop_before: ActiveRecord::Base })
```

The default `source_comprehension: nil` preserves the existing capture path.
Explicit context is also honored with `rails: nil`; it does not bind captured
source methods to the loaded registry. Native, installed and served acceptance
for this new journey remains pending.

Job/mail observation also requires an explicit already-loaded inventory and the
supplied Rails app. Template paths are explicit and root-relative:

```ruby
Thistle.capture(root: Rails.root.to_s,
                output: Rails.root.join(".thistle").to_s,
                rails: Rails.application,
                job_mail: { jobs: [ReceiptJob], mailers: [ReceiptMailer],
                            templates: ["app/views/receipt_mailer/receipt.html.erb",
                                        "app/views/receipt_mailer/_footer.html.erb"] })
```

Pass classes the application has already loaded; Thistle performs no descendant
discovery, autoload or APPLICATION-controlled getter/job/handler/mail delivery invocation
for this registration family. Rust reads declared ERB files through the existing
anchored inventory guards and stores inert bytes/spans; it never evaluates ERB
or helpers. `job_mail: nil` retains the prior capture path. This opt-in does not
prove source/runtime coherence or qualify broader Rails/mail/template behavior.
First installed job/mail cards require Rails 8.1.4; the 7.1.6 compatibility leaf guard
is present but unverified by this fixture. Application overrides stay unavailable.
A busy source-analysis worker yields a transient Map 503 with Retry-After:1; retry
the page explicitly. No automatic retry, queue or capture substitution occurs.

Controller-filter observation is also explicit: add
`controller_filters: [OrdersController]` with the supplied `rails:` app and root.
The guarded Rails 8.1.4 adapter records registration order, inherited method
ownership and action applicability without running filters or conditions. A
registration is not an execution step; `controller_filters: nil` keeps the prior
capture path. The [Passage contract](docs/development/passage.md) describes which
selected-action source witnesses can qualify a related save contribution.

For one saved `rails_model`, `reader.model_neighborhood(model_id)` returns
bounded named association/reference edges, evidence witnesses and candidate
continuations. Incoming/Outgoing and Association/Reference filters retain their
own cursor scopes. `family: 'columns'` preserves raw typed defaults, SQL type and
nullability; `family: 'database'` explicitly reports unrecorded physical database
constraints. A literal null does not prove a DEFAULT clause was declared, and
Rails association options are not physical foreign keys or ON DELETE evidence.
Map presents the same selected edges in an immediately named list and optional
server SVG, with direct **Columns** and **Database facts** actions. See the
[model neighborhood contract](docs/development/model-neighborhood.md). This
source increment has no new capture/schema, resolver, index or graph runtime;
its new installed/served/person evidence remains pending.

## Optional Map

Map can [collect and reopen a small investigation](https://github.com/lost-in-the/thistle/blob/main/map/docs/investigations.md)
using one saved generation and up to 24 selected fact IDs. Ordinary GET links
support collecting, removing and reopening evidence without JavaScript. The
focus URL carries only the generation and IDs and grants no access; recipients
need an authorized Map mount with that saved capture. Missing evidence and
uncertainty remain explicit. Source opens captured bytes at the pinned
generation even after CURRENT changes. This requires the matching Core with
the bounded [fact identity operation](docs/development/fact-identity.md).

Code-first model reading uses `/comprehension/contributions` and
`/comprehension/methods`, with generation/search/investigation retained by shared
navigation. Selected files reserve at most 64 KiB before reads; 2000 aggregate
display lines are checked on bounded responses before highlighting. Unknown
ownership and files not admitted for display remain explicit. See the
[reading contract](docs/development/source-comprehension.md) for limits and the
pending installed/served/person acceptance boundary.

Saved job/mail investigation uses `/job-mail/overview` and its explicit policy,
registration/declaration, handoff and template-reference family routes. Source
and Links offer supported typed entry actions without automatically parsing all
job families. Generation/search/collected IDs use the same navigation authority;
see the [job/mail/ERB contract](docs/development/job-mail-template.md). Actual
installed/served answers, keyboard/no-JavaScript/narrow-screen acceptance and
broader defaults, callbacks, HAML, history and full Passage remain outstanding.

`map/` contains an independent read-only companion gem. It uses Thistle's reader
API and an approved source-view component from Woods Map. It has no Woods runtime
dependency. Its [repository README](https://github.com/lost-in-the/thistle/blob/main/map/README.md) covers local mounting, access boundaries and keyboard use.

## Trust and lifecycle

Only one writer publishes a store at a time. Content and manifests are validated
before the atomic current-generation pointer changes. Failures before that change
preserve the last published generation. A directory-sync failure after the change
returns `commit_uncertain`: reopen the store because a new generation may already
be current, with crash durability unconfirmed. Store files use restrictive creation modes and
descriptor-anchored filesystem access refuses symlinks and non-regular files.
Readers pin immutable facts and verify source bytes when expanded or checked.

The current milestone retains generations and source blobs until the user removes
the entire store. Automated retention, quotas and recovery after power loss are
not yet qualified. Do not treat content digests as signatures or authorization:
someone who can replace a whole store can author another internally consistent
store. Protect it like source code.

The native reader registry has bounded handle and encoded-data budgets. These are
limits on serialized data, not a measured bound on native heap or process RSS. Close
readers explicitly. An engine inherited after `fork` refuses further use; start
Thistle in a fresh process. General fork support is a launch requirement.

## Evaluation and next work

The sibling `thistle-eval/` installs built gems into a fresh gem home and tests them
outside this source checkout against independently labelled fixtures, mutations,
and intentionally defective results. Local separation is not a hardened sandbox.
See the [repository capability ledger](https://github.com/lost-in-the/thistle/blob/main/docs/capability-ledger.md) for the broad unqualified launch jobs and the
evaluation/CI documents for external controller requirements.

This milestone is intended to make the architecture executable and reviewable.
Full customer-outcome parity, full reused Map integration, semantic retrieval,
incremental/watch behavior, platform distribution, user studies and comparative
launch qualification remain explicit gates in the reviewed plan.

