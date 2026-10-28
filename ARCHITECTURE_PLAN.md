# Thistle product architecture and launch plan

Exported from https://chatgpt.com/space/page_83d1d4a1a4ec81918d7310c21061c4e4 on 2026-10-28. This snapshot includes the owner's Rust requirement. See IMPLEMENTATION.md for actual implementation status; the plan's launch targets are not completion claims.

Design decision dated October 28 2026. The owner subsequently clarified that the core must be implemented in Rust; that requirement replaces the earlier conditional-Rust choice. Customer-outcome parity, Map reuse, independent evaluation and recognition-focused interaction remain the launch goals.

# Decision

Thistle is the working name for a new Ruby gem, or small set of gems, competing with Woods. Its first public launch must at least match the useful customer outcomes, evidence quality, coverage and supported operating modes of the agreed current-product baseline. It should then offer a measured reason to choose it: less time, effort or cost to make a correct change.

Thistle is free to redesign its tools, commands, APIs, file formats, screens and package boundaries. It has no obligation to support Woods' old tools. Build the extraction, analysis, publication and query engine from scratch. The owner explicitly permits reuse and optimization of Woods Map, including its UI, implementation, design assets and branding. Use that permission to avoid unnecessary UI redevelopment while improving how investigations work.

A narrow prototype is an internal milestone, never the parity launch. The old implementation is evidence about useful jobs and difficult Rails behavior, not an architectural template. Question every inherited design choice and compare the alternatives against real outcomes.

The product uses independent runtime identities and output roots and works without Woods installed or loaded. Established parser, storage, protocol and profiling dependencies remain allowed. Woods can be a development instrument and a black-box comparison product. The testbed independently judges both products through their own interfaces.

The central design objective is lower measured time to a correct, fresh, useful answer and a completed task. Word-finding effort, navigation, installation and recovery are part of that time. The improvement loop uses the accepted Thistle build to investigate itself, proposes small PRs, and retains only changes that pass independent evaluation.

# Challenge every inherited approach

The following are design questions and hypotheses, not claims that Woods has each listed defect. Confirm the baseline behavior before claiming an improvement. The best alternative may preserve a good existing technique. The three strongest launch bets are a shared trustworthy evidence model, a focused investigation/change workbench, and eliminating measured repeated work.

| Assumption to challenge | Better Thistle candidate | Missing consideration and proof |
|---|---|---|
| Product parity means copying tools and screens | Define jobs and evidence contracts; design new actions and projections | Test equivalent tasks; fewer controls cannot hide lost capability |
| Every feature needs its own extractor traversal | Shared inventory, parsed source and runtime/schema facts feed small independent producers | Instrument actual repetition first; shared caches need precise invalidation |
| Every question should receive a large source bundle | Progressive evidence with useful initial completeness and explicit full-source expansion | Task success and follow-up cost; compact text already has counterevidence |
| A graph edge is enough explanation | An evidence record links the relationship to source, runtime observation, version and limits | Avoid invented confidence and proof of execution; test why an edge exists |
| Facts, UI, agents and CI need separate models | One versioned evidence contract with fit-for-purpose projections | Different disclosure and latency budgets still apply; no giant universal response |
| A codebase browser is the best primary interface | A persistent investigation starting from a question, URL, symbol, file or change | Resume the user's place; compare answer correctness and total navigation effort |
| More graphs mean better understanding | Select the smallest useful view, with a list/table equivalent and source access | Graph literacy, keyboard access, large-graph cost and explicit truncation |
| Centrality equals relevance or change risk | Show centrality as one labelled fact; use task evidence and tested retrieval | False positives and unrelated hubs; no unvalidated ranking shortcut |
| Global freshness is a single green light | Show what is current for the served evidence and what is stale or unknown | Opaque boot state, multiple schemas, stale semantic overlays and partial capture |
| A fast in-memory query proves a fast product | Measure install, boot, refresh, cold start, reading and successful task completion | Background CPU/RAM, failed tasks, provider cost and multi-project contention |
| Native code is automatically the fastest route | Profile, estimate the maximum benefit, test a bounded kernel, then choose | Crossing/copying costs, support floors, startup, debugging and maintenance |
| On-demand work is always cheaper | Load large source views on demand, but complete global queries or refuse explicitly | Deferred work must be charged to first use; no fake speed from hidden incompleteness |
| A resident daemon should always be running | Optional residency with idle shutdown and aggregate budgets | Many repositories and branches can multiply resource use |
| The same index can follow every workspace | Bind facts and caches to app, source epoch, dependency set and worktree | A fast answer from the wrong branch is incorrect |
| Human convenience means silent automation | Suggest relevant actions, preserve user control and make state changes legible | Attention cost, surprise refreshes, lost focus and mistaken confidence |
| Short commands are inherently easier | Common stable words, visible choices, approximate search and home-row shortcuts | Recall, speech input, keyboard layout and ambiguity matter as much as keystrokes |
| Self-analysis proves self-improvement | Use evidence to propose a bounded change; let an independent evaluator decide | Feedback loops overfit; retain failed experiments and untouched confirmation |
| More packages create a cleaner product | One installable core, optional UI only where dependency/lifecycle warrants it | Release coordination, conflicts, install weight and diagnostic complexity |

Test the workbench as one thin workflow early: start from a changed controller, see the relevant source and resolved filters, follow a job/mail/template path, inspect test evidence and unknowns, save the investigation, then resume after another edit. This combines existing useful capabilities rather than inventing a new feature catalogue. Success means less effort at equal or better correctness.

Do not optimize the artifact users see at the expense of the task they complete. A home-row alias that is hard to remember, a shorter answer that misses a callback, or a graph that loses source provenance is a failed improvement even if its local metric improves.

# What launch must match

The baseline has two parts. Published Woods 2.1.0 is the released minimum; useful implemented behavior in the pinned current Woods and Map revisions is also a launch target. Woods main documents unreleased 2.2.0, so an older released comparison cannot silently lower the bar. Public documentation identifies capabilities; installed behavior and independent fixtures establish what those capabilities actually do. [C1–C4]

Freeze a versioned capability ledger before major implementation. Each row records the customer job, current release/development/experimental status, source and artifact identities, input and supported environment, expected evidence and limitations, equivalent candidate workflow, owner, test and result. Expand broad rows into actual behaviors, optional configurations and failure paths. The table below is an inventory seed, not the final test inventory.

Classify each capability as required equivalent, excluded by the user's direction, already deprecated, or not implemented in the comparison baseline. Every useful supported customer outcome is required unless an explicit product decision changes scope; incidental implementation behavior is not. A costly feature cannot be relabeled baggage during implementation. An unresolved row blocks launch; an experimental promise does not become a shipped obligation merely because a document mentions it.

Before release-candidate qualification, review newly published Woods changes and reconcile material current-product changes. Record any baseline update and rerun affected comparisons. Keep primary trials frozen while they run. Publish the exact comparison versions and scope rather than claiming parity with a moving unspecified target.

Parity means equivalent customer outcomes, coverage, evidence semantics and supported operation. It does not require identical class names, a matching extractor count, legacy filenames or copied internal layering. There is no backward-compatibility requirement for Woods tool names, MCP schemas, Ruby APIs, filenames or URLs. Provide new interfaces for the equivalent jobs; comparator adapters belong in the testbed. A user may deliberately change their integration to adopt Thistle.

The current documentation itself illustrates why counting features is insufficient: some overview pages list 14 Index tools, while the detailed current reference lists 15 packaged-default tools including diagrams. Resolve registration, callable behavior and conditional wiring from the installed artifacts rather than adopting either headline as the acceptance criterion. [C2, C5]

The support inventory starts from verified comparator-supported Ruby/Rails combinations, database capabilities, installation environments and deployment jobs. It cannot pass by silently declaring a smaller matrix. The current Woods promise is Ruby 3.0+ and Rails 6.0–8.x using compatible Ruby/Rails pairs; optional features can have explicitly separate floors. Verify these obligations in runnable artifacts. A deliberate support change needs a visible product tradeoff, not a hidden dependency upgrade. [C2]

# Launch capability matrix

| Area | Required launch outcome | Acceptance evidence |
|---|---|---|
| Installation and support | Normal Gemfile/Bundler/Rails setup, clear validation and diagnosis, supported Ruby/Rails/database and packaging environments, Docker and linked worktrees | Clean installs, first useful query, wrong-path/provider/boot failure recovery and documented setup exercised on the declared matrix |
| Runtime Rails facts | Schema, indexes, associations, callbacks, concerns, inheritance, routes and relevant configuration reflect the loaded application | Independent booted fixtures, exact typed facts, source ownership, multi-database and failure cases |
| Application breadth | All useful evidence coverage represented by current extraction families and configurations; Thistle can organize producers differently, beyond the initial models/controllers cohort | Per-family positive, negative, missing-dependency and mutation cases; no aggregate score hides an omitted family |
| Source and identity | Original source, effective class/context, stable typed identity, physical source spans, installed framework/gem versions, unresolved targets and provenance | Ambiguous names, concerns, namespace wrappers, renames, encoding and source-location fixtures |
| Discovery and lookup | Exact typed lookup; name, path, source and metadata search; scope filters; explicit completeness and bounded results | Known-answer search tasks, complete enumeration/pagination, no false not-found from truncation |
| Ranked retrieval | Useful lexical and semantic workflows, full-source access, explicit compact/outline choices, context budgets and honest provider readiness | Held-out relevance and agent tasks, source follow-ups, missing/stale/partial embedding cases |
| Graph and flows | Dependencies, dependents, structure, flow evidence, centrality/clusters, structural reports and review diagrams with their confidence limits | Typed edge expectations, traversal/filter/budget cases, cycles, ambiguous targets, supported report equivalence |
| Change evidence | Recent changes, Git history/co-change, supported snapshot comparison, pre-change and retained-change impact, relevant tests and machine-readable checks | Independent versioned fixtures and known change sets; no unobserved behavior represented as proven absence |
| Lifecycle | Full extraction, incremental and targeted refresh, watched and managed maintenance, supported client hooks, live-reader refresh and recovery | Edit-to-fresh-query through persistent consumers; delete/rename/schema/branch/overflow/crash scenarios |
| Observed runtime evidence | Supported scoped trace/session workflows and limits; evidence stays distinct from static inference | Configured and unconfigured cases, supported store/transport wiring, known observed calls and honest missing coverage |
| Storage and providers | Current useful local/offline, hosted, shared-reader and durable retrieval deployments; usable provider/backend integrations or equivalent paths with no lost deployment job | Restart, publication, source/vector alignment, provider failure, portable snapshots and operation in each required deployment cohort |
| Programmatic consumers | Ruby reader/query access, a new query/tool/resource API over stdio and authenticated remote transport, machine-readable exports and validation | Fresh external client tests, version refusal, read-only consumption, generation retention, embedded conditional capabilities |
| Exports and sharing | Supported Markdown/Obsidian and diagram/report workflows; reproducible evidence links and portable snapshots | Export contents, backlinks, source references, sensitive-data policy and offline readback |
| Human reading | Find code by name/path/content, inspect original and effective behavior, follow references and file ownership, understand schema/lifecycle/routes/history | Equivalent browser journeys across required units; fewer navigation steps are welcome, lost evidence is not |
| Human investigation | Start from a URL/action/change; follow synchronous and asynchronous passage; inspect application boundaries, external systems, database relationships and hotspots; assess impact/tests/history; collect, resume and share an investigation | Job scenarios spanning existing Map reading, Landscape, graph/list/ERD, range views and Trail; no requirement to retain the same tabs or URLs |
| Contextual help | Optional provider-backed assistance through Thistle's own read contract, with streaming, cancellation, budgets and source provenance | Thistle-only installed bundle and real declared live-provider journey; a fake endpoint alone cannot qualify this job |
| Operation and documentation | Coherent status/readiness, diagnostics, secure defaults, switching instructions and trustworthy capability reports | Install and investigation runbooks executed with fresh users/agents; errors lead to actionable recovery |

The current extractor reference describes 42 families and 47 unit types, spanning core Rails, UI/frontend, data structures, API/authorization, infrastructure, tests and source. Treat this as a discovery checklist; independently verify the actual mapping and behavior. The released product already has broad coverage, so a small extractor subset cannot qualify by matching a few popular examples. [C6]

The required inventory includes framework and installed-gem source; GraphQL types, operations and resolvers; views and components; policies; engines/packages; I18n; channels; scheduling/rake; migrations, tables and database views; events/state machines/cache; factories, tests and test support; configuration, library, documentation and frontend source where currently supported, plus declared external table consumers and external-service catalogue/call evidence. This names families rather than implying every Ruby or JavaScript construct is resolved. Preserve useful supported limits explicitly. [C6]

Conditional tools need their own rows. A schema that is never registered is not a usable feature; a custom builder with session, pipeline, temporal or feedback collaborators can still reveal a real customer workflow. Preserve the useful job through Thistle's own contract; reproducing the old builder or wiring is unnecessary. Deprecated Notion and Unblocked integrations do not become new launch work; supported Markdown export does. [C2, C5, C7]

Map's current coverage notes are broader than its README milestone line and mix implemented behavior with design/qualification status. Use them to discover jobs, then verify them. They include route investigation, files/ownership, architecture and external-system views, whole-database exploration, change overlays, cross-unit history, and investigation trails. Reuse the useful components; a better unified workflow may replace many existing pages. Internal Guidelines/component boards are reusable design assets, not independent customer launch features. [C26]

Do not inherit unproven status as a passing test. Map's Guide notes explicitly leave a real-provider journey unqualified. Thistle must qualify its own declared live-provider configuration, separately from fake-provider contract tests; this does not create an unlimited provider-support promise. [C27]

# Competitive position and choices

The strongest proposed position is reliable Rails evidence with less total effort to complete a correct change. The product should make it easier to find the relevant code, understand what Rails assembled, assess impact, choose tests and verify that the evidence is current. Its launch case needs measured improvement in a meaningful workflow, not only feature parity.

Three candidate advantages deserve investment. First, reduce edit-to-trustworthy-answer time through coherent incremental updates and cheaper query startup. Second, reduce investigation and review effort through source-linked evidence shared consistently by agents, humans and CI. Third, reduce setup and ongoing resource cost without reducing capability or source access. Each is a hypothesis to test against Woods: freshness, MCP, local retrieval and graph exploration already exist there and are not novel on their own.

Keep the source of advantage in accurate Rails behavior, a growing independent test corpus, reliable operation and measured outcomes. Rust, SQLite, tool count, a diagram, and the phrase self-improving are not customer benefits by themselves. There is no market-demand or willingness-to-pay evidence in this review; user interviews and representative task sessions must validate positioning before broad commercial claims.

Simplify implementation and choices where the same jobs remain possible. Do not inherit old migrations, obsolete compatibility branches, accidental file layouts, duplicate tool wrappers or a large configuration matrix merely for resemblance. Conversely, do not remove semantic retrieval, human exploration, exports or remote use because they complicate an elegant core.

Existing evaluations give concrete reasons to resist easy performance stories. A small lexical comparison over 28 queries and 62 units traded precision and first-hit rank for recall and lower warm in-process latency; the timing excluded extraction, snapshot construction and live provider costs. A compact-source experiment passed 4 of 6 task attempts versus 5 of 6 with full source while returning much less text. Optional context-hook trials did not establish a task-quality or efficiency gain. These samples do not establish general superiority or inferiority, but they rule out treating token reduction or a warm microbenchmark as sufficient evidence for a new default. [C8]

Offer provider-free structural discovery immediately and retain lexical and semantic choices. Retain full-source follow-up and clear evidence-mode selection. Decide defaults through fresh held-out task evaluation. A unified status model and smaller configuration surface are worthwhile only if actual setup and recovery become easier.

# Naming and interaction for recognition

Treat reduced word-finding and recall burden as a product requirement. Thistle is the working brand; keep feature labels literal and familiar rather than extending a flower/forest metaphor into every action. Use one stable word for a concept across the UI, CLI, docs and agent schemas. Aliases belong in search and help rather than constantly changing visible labels. W3C cognitive guidance supports familiar language and visible labels; these principles guide the design, while usability with intended users determines whether it helps in practice. [C28–C30]

Use short canonical verbs and nouns with concrete examples. A proposed vocabulary is Ask, Find, Source, Links, Changes and Check. It is a prototype vocabulary, not a frozen API. Keep technical exactness in typed parameters and evidence fields, and expose explanations for terms that remain necessary. Do not invent cryptic all-home-row words merely to avoid reaching another key.

Home-row access is a parallel interaction layer. The QWERTY example below is a starting point; layouts and mappings are configurable. Existing visible controls remain usable with pointer, keyboard navigation, assistive technology and speech input.

| Visible action | Optional key candidate | Recognition support |
|---|---|---|
| Ask | A | Example questions and current subject; explain versus search is visible |
| Find | F | Match name, path, description or approximate wording; group suggestions |
| Source | S | Show the selected source with a stable return to the investigation |
| Changes | D | Show the selected comparison; the visible label remains Changes |
| Links | G | Show relationships as a graph or list, with the meaning explained |
| Previous and next | K and J | Visible navigation and standard arrow/Tab alternatives |
| Back and forward | H and L | Preserve reading position, subject and history |

The mnemonic is optional; a person should not need to remember G or D to find Links or Changes. For CLI/API use, retain readable words rather than single letters. A short convenience alias can be configurable, but global shell command collisions and package-name availability must be checked before publishing.

The palette should accept synonyms, partial words, spelling errors, filenames and natural descriptions, show a small grouped set of choices, and display recent/pinned investigations. Distinguish approximate discovery from exact identity lookup: never silently change a code identifier, target or action because a fuzzy match seems likely. For an ambiguous request, show recognizable choices with examples and preserve the original text. [C31]

Use labels beside icons, consistent positions, a visible current subject, breadcrumbs/history and stable focus. Keep the important action and meaning visible instead of relying on a tooltip, hidden hover or icon alone. Preserve a draft question and reading position across views and recoverable errors. Give a short plain-language result, its evidence and a way to expand it; terse symbols or color alone cannot carry correctness/freshness.

Single-character shortcuts must be disabled in text/editing/dictation contexts, scoped to the relevant focused component, and turn-off/remap controls must be easy to find. Do not use timed multi-key sequences as the only route. Support browser/OS shortcuts and input methods. W3C's character-shortcut criterion requires turn-off, remapping or focus-only activation to avoid accidental input; Thistle should deliberately exceed the minimum where practical. [C29]

Evaluate task completion, mistaken actions, help requests, time to rediscover a function, recovery after interruption, and subjective effort with intended users, including word-finding and motor/input needs. Automated accessibility checks supplement keyboard, screen-reader and speech/dictation trials. Do not infer medical effectiveness from guideline conformance, and do not require users to disclose a diagnosis to personalize the interface.

The technical action catalogue is independently designed. Prototype a small discoverable set of typed intents behind the same vocabulary, rather than preserving the old tool list or collapsing everything into one opaque natural-language endpoint. Structural use remains deterministic and usable without a language-model provider. Optional language assistance can translate or explain choices; it must not invent authoritative facts or turn an ambiguous request into arbitrary execution.

# One product with minimal packaging

Begin with one working-name thistle gem containing a Rust analysis, indexing, storage and query engine, a thin Ruby facade for Rails runtime facts, the native package assets, and a coherent command interface. Native executables or extensions are package assets, not automatically separate gems. Keep the independently controlled evaluator and improvement tooling in a development repository/bundle.

Use one optional thistle-map gem for the reused web explorer if that keeps UI dependencies, assets and web lifecycle out of headless installations. If a single gem delivers the same optionality with less installation and maintenance cost, one gem is acceptable. The product architecture must not depend on the marketing/package split.

Split a provider or other component only for a demonstrated dependency conflict, installation-weight benefit, independent lifecycle or authority boundary. A language boundary or source directory alone is not a reason to create another package. One gem can contain multiple processes, and two gems in the same process do not create security isolation.

The labels Thistle, thistle and thistle-map are working names approved for this design, not claims that registry/repository names are available or reserved. Retain useful Map branding or rename it consistently after a naming check. No repository, gem name or release has been created by this plan.

# Architecture and performance investment

Use a Ruby integration layer for the behavior that requires the Ruby and Rails runtime. It supplies coherent, bounded batches of plain facts to deterministic analysis stages. Keep source blobs separate from structural facts; construct expanded context on demand with exact source mapping. Use stable public typed identities, compact private IDs and versioned schemas.

The computation dependency graph determines what must be recomputed. The application relationship graph describes the user's code. They have different meanings and must not be conflated. Cache parsing, normalized facts, graph/search construction and derived reports by their actual inputs, rather than repeatedly rebuilding a monolithic output.

Start with a small executable Rust core and a thin Ruby gem/Rails boundary. Compare an indexed SQLite snapshot design with a simple immutable-file baseline on the actual read, copy, retention and update contracts. SQLite remains a storage candidate rather than a requirement that overrides portable or read-only workflows. A live WAL database must not be treated as a directly shareable immutable artifact; publication and network/shared-reader semantics require their own tested design. [C18]

Rust is the required implementation language for the core engine. It owns static source inventory and analysis, normalization, indexing, graph/search operations, validation, storage, publication and query execution. Ruby supplies runtime facts that require the Ruby/Rails VM and the small gem-facing interface. Prism already provides a native parser; use its established Rust bindings rather than rebuilding a Ruby parser. A small C ABI bridge may connect Ruby and Rust without making the engine a Ruby implementation. [C19]

Profile the Rust implementation and estimate the upper bound on each proposed optimization. Give algorithm, layout, caching and parallelism experiments a fixed effort budget and stop rule. Compare the same complete operation before and after, including boundary copying, peak memory, startup and installation cost. If Rails boot, reflection or database metadata dominates, optimizing a small Rust stage cannot create a large whole-workflow improvement. Keep VM-dependent work at the Ruby boundary and move reusable computation into the native engine.

| Decision | Admission evidence | Default without sufficient benefit |
|---|---|---|
| Native kernel | Same facts and failures, meaningful end-to-end gain, supported floors/platforms, bounded conversion and memory | Keep the simpler correct kernel |
| Native query executable | Cold startup, sustained query and complete resource gains with identical protocol behavior | Keep a Ruby MCP facade |
| Custom packed or mmap storage | Better complete workloads including publication, retention, recovery, compaction and portable reads | Keep the validated simple store |
| Resident probe/server | Interactive gains after idle memory, multi-project cost and lifecycle failures are charged | On-demand operation; residency explicitly optional |
| Narrow invalidation | Independent mutation corpus and full/incremental agreement | Broader invalidation or fresh extraction |
| Compact evidence or adaptive defaults | Better customer tasks within the same quality and cost contract | Explicit user choice and conservative defaults |

Native ownership has to be concrete before expansion: bounded batches, native-owned worker data, staged commit/abort, backpressure, cancellation, Ruby GC marking where applicable, valid Ruby/GVL entry, and explicit exception/panic conversion. Native workers do not retain unprotected Ruby objects or call the VM outside its supported rules. Test fork lifecycles, crashes, forced GC and cancellation before broadening the boundary. [C20]

Packaging is part of the performance decision. Validate clean precompiled installs on promised OS/CPU/libc/ABI combinations and supported source builds. Use portable CPU baselines and identify actual loaded extension and executable bytes. Do not silently raise the Ruby floor, require an external service for structural use, or hide an unsupported platform behind a fast benchmark. A fallback must satisfy its own declared capability and performance gates. [C21]

Keep one publisher initially, with finite queues, coalesced edits, bounded batch sizes, resource quotas, cancellation and idle shutdown where appropriate. Readers pin a complete generation for the operation or journey that needs consistency. Long-lived cross-request access requires explicit retained generations and leases; an indefinitely held SQLite read transaction is not the retention design.

The design supports later replacement of a slow store, transport or kernel because consumers use a versioned query contract. Do not build a distributed scheduler, custom database and full native protocol stack before demonstrating which one removes a measured bottleneck.

A shared source inventory and parse/reflection cache should feed small fact producers and derived views. There is no need for one independently traversing class per legacy extractor or one output model per screen. Measure actual parse counts, allocations and repeated schema/reflection work first: the number of Woods extractor classes does not prove that it repeats each operation. Preserve provenance and invalidation at the inputs actually read, so shared work does not create shared stale results.

# Coherent evidence and incremental correctness

Every fact identifies its application/package, typed unit identity, source content and locations where available, explicit absence when unavailable, extraction provenance and evidence category. Keep runtime-resolved structure, statically verified references, inference and observed execution distinct. Unknown, unresolved, incomplete and failed states are real outputs. An absent graph edge is not proof that code is unused, and a flow diagram is not proof of execution.

A dedicated capture owner controls boot, reload and observation. Strict reference extraction uses immutable fixture inputs and a fresh process. Resident operation records the input manifest associated with the loaded epoch, classifies changes, reloads or restarts when needed, captures, validates and publishes atomically. It must never attach newly read source to stale loaded classes.

Pre/post content equality alone cannot certify coherence: source can change A to B to A while Ruby loaded B. Certified captures need immutable/staged load inputs or a validated mutation sequence spanning load and capture. Watcher overflow, lost events and unverifiable intervals yield retry or explicit unknown freshness. Bound retries and retain the last complete generation accurately labelled. Rails reload coordination does not create a transaction across files, schemas and arbitrary initializer effects. [C22–C23]

Schema facts identify their connection and schema observation. Multiple databases have separately identified consistency scopes unless a coordinated guarantee exists. External services, mutable environment and opaque boot effects prevent claims of global currentness. Product status must distinguish latest successful capture, known source drift, verified scopes and unresolved freshness.

Incremental keys include source, directory membership, namespaces and missing targets, relevant configuration, dependency/runtime/parser versions and encoding policy. Track negative dependencies so a previously missing target can invalidate a result. On every recomputation replace the dependency read set, even when the semantic value is unchanged. Keep semantic-value fingerprints separate from observation/provenance identity.

Start with conservative acyclic stages; rebuild an affected stage or strongly connected component when necessary. Failed or cancelled work installs no successful cache entry. Renames, deletions, changed concern ownership, collisions, new namespaces, schemas, configuration and optional library changes are first-class fixtures.

Publish complete generations with source and query metadata that match. If vectors, rankings or other derived data lag, state their coverage/version explicitly rather than returning stale semantic output as current. Cursor and result identity include generation, relevant filter/ranking versions and scope; expired retained data produces an explicit refusal rather than silently reading a different generation.

Both semantic full-versus-incremental equivalence and independent expected facts are required. Two paths that omit the same callback or mislabel the same edge must still fail. Profile and query output must preserve errors and unknowns instead of turning them into empty successful results.

# Reuse Map and redesign the investigation

Reuse Woods Map's useful UI code, components, assets, interactions and branding with the owner's authorization. Start from what works and improve task flow. Thistle's human experience can be a renamed Map package, an optional engine in the main package, or another thin client over the same evidence contract. No compatibility with the old Woods tools is required.

The concrete integration still matters: current Map depends on Woods, invokes its Ruby reader and policy helpers, and defaults the Guide to a Woods executable. Remove or replace those dependencies in the Thistle distribution. Matching JSON while secretly using Woods to read it does not produce an independent product. [C3–C4, C32]

Prefer a small Thistle reader/query adapter and a separately installable reused Map engine when that keeps web dependencies optional. A dual Woods/Thistle provider system is unnecessary for this project; do not spend launch capacity maintaining it unless it proves cheaper than the Thistle-only distribution. Retained old-product support is not a Thistle gate.

Prove a clean installed bundle containing Thistle and its chosen UI package with Woods absent. Verify loaded features and actual subprocess commands, including the Guide. Exercise the customer jobs through the redesigned interface, not obsolete URLs, prompt tool names or API shapes. Publish the complete compatible package tuple; a local-only Map patch cannot satisfy launch.

The central UI experiment is a persistent investigation workbench: a question or selected change, relevant source, relationships, tests/history, known gaps and a small set of saved evidence. It should let a person move from a URL, file, symbol or change to understanding and a defensible next step without rebuilding context across many pages. Existing Impact and Trail features already cover parts of this; the proposed gain is a more coherent journey, not a novelty claim.

Preserve the useful breadth of reading, routes, passages, schema and whole-database exploration, architecture/external dependencies, graph/list views, history/co-change, impact, collection/resumption/sharing and optional help. The best view for a task can change. Keep stable location, focus, labels and navigation history so optimization does not continually rearrange the interface.

Use batching, bounded graph/report payloads, lazy source-blob loading and exact original-to-effective-source mapping to improve complete journeys. Existing generation pinning and Guide process reuse are baseline behavior, not new inventions. Measure server latency, response bytes, browser work, navigation effort and correctness of the user's answer.

Guide answers use only authorized Thistle evidence and bounded tools. They disclose snapshot identity, provider use and omitted evidence. Test a real declared provider as well as deterministic fake-provider failures. A read-only view or API does not sandbox embedded code: the engine still shares host authority. Where containment is required, use a separate minimal host over authorized snapshots rather than claiming a new tool name supplies isolation.

# Retrieval and deployment contracts

Semantic retrieval, lexical discovery and full-source inspection solve different tasks. Test vocabulary mismatch, exact symbols, scoped searches, ambiguous identities, cross-type collisions, source-empty units and framework/gem context. Measure both relevant evidence recovered and irrelevant evidence introduced; returning fewer facts must not appear to improve precision by abandoning recall.

Context assembly includes source/provenance, token/byte budgets, complete-source follow-up and explicit truncation or refusal. A compact response must identify omitted evidence. Maintain separate versioned derived indexes for ranking, embeddings and source representation, so a reader can determine exactly what corpus it is using.

The existing deployment inventory includes OpenAI and Ollama embedding workflows, local artifacts, shared-filesystem readers and external pgvector/Qdrant storage, along with documented job integrations. Use these as inputs to the deployment-job inventory. Exact old backend names and provider APIs are not binding. A new simpler backend can replace old mechanics only when it preserves the user job, privacy/deployment requirements, quality, scale and switching feasibility. Do not quietly replace an existing self-hosted workflow with a mandatory hosted service. [C9–C10]

Test restart, provider unavailability, partial embedding, changed dimensions/models, stale vectors, failed publication, read-only copies and remote/shared readers. Separate deterministic recorded-provider tests from live provider correctness and end-to-end cost/latency lanes. A fake embedding provider validates a contract, not semantic relevance.

For machine readers, publish Thistle's own versioned query/export schema and tested Ruby plus non-Ruby examples. Support portable complete snapshots with explicit retention and compatibility refusal. Internal storage can differ from Woods; new documented interfaces or exports must keep the useful CI, cop, report and offline-reading jobs usable; old client code need not run unchanged. [C11–C12]

Account for all work when comparing modes: extraction, parsing, embedding, index construction, hydration, network calls, repeated context, follow-up queries, background maintenance and amortization over a stated number of successful tasks. Provider and model prices must be dated inputs to a cost estimate; actual usage is distinct from estimated billing.

# Independent comparison and launch gates

Keep woods-testbed as an independently versioned evaluator repository that can consist of tests, fixture applications/generators, workloads and external-control tooling. It need not be another application product. Extend its installed-artifact pattern to accept both the Woods comparator and Thistle through separate job-level adapters. Those adapters translate the same user task to each product's native interface; they do not force Thistle to emulate old tools. No candidate source checkout is mounted as its runtime dependency. [C13]

The external controller owns workload selection, expected outcomes, thresholds, measured boundaries and verdicts. Candidate build/install scripts and runtime code execute in disposable restricted workers, without release secrets, evaluator write authority or persistent access to later trials. Read-only evaluator files do not establish independence if hostile candidate code shares the same controlling process or OS authority.

Build independent ground truth from hand-labelled source, fresh Rails reflection, controlled execution and hidden task verifiers. Define semantic projections for identity, fields, references, completeness, evidence categories, provenance, errors and unknowns. Normalize only declared nondeterminism; retain strict diffs separately. Woods is the comparison product, not the sole truth oracle. Correct historical defects without lowering coverage or copying false assertions.

Include deliberately defective candidates: the same omission in full and incremental output, stale content marked fresh, wrong evidence labels, wrong native asset/source, missing optional capabilities, withheld results and verdict tampering. The external mutation fence checks that the expected changed fact reaches the public client after an edit; self-reported freshness is insufficient.

Use multiple independent Rails applications and task strata, including substantial concerns/callbacks, multi-database/package behavior, optional UI/API libraries, a large app, a small app, Docker and worktrees. Generated stress cases supplement real workloads. Exercise every required family/configuration even if representative combined matrices use risk-based pairing rather than a full Cartesian product.

Compare published Woods, pinned current Woods/Map and the candidate on equivalent scopes. Include normal source-search/editor use for customer-task value. Match app and dependency revisions, input data, model/client versions, task prompts, budgets, hardware, concurrency, cache state and network policy. A richer baseline cannot be timed against a feature-reduced candidate and called slower.

| Gate | Required result | Blocking condition |
|---|---|---|
| Functional parity | Every required capability row passes in its supported cohort, with independently correct evidence | Missing, untested or reclassified useful capability; false confidence or coverage loss |
| Runtime independence | Thistle and its reused UI work in an installed bundle without Woods code or executables | Hidden transitive dependency, require, default launcher or successful co-installation only |
| Task quality | Predeclared paired evaluation shows no worse observed outcomes and satisfies the independently approved uncertainty rule | Required stratum regression, uncertainty beyond the decision limit, or altered labels/budgets |
| Performance and resources | Meets absolute usability budgets and comparator regression limits for cold/warm/update/full-task workloads | Speed gained through less work, stale evidence, failed attempts omitted, resource or maintenance debt |
| Cost | Total cost per successful task and ongoing operation meets independently approved budgets and comparator limits, with stated amortization | Missing embedding/model/background cost, omitted failures, or token volume substituted for total cost |
| Interaction and naming | Required jobs work without exact command recall; visible actions, consistent language, keyboard/pointer/speech paths and recovery pass defined usability checks | Shortcut-only functionality, accidental key activation, ambiguous action outcomes or material task-effort regression |
| Setup and operation | Successful clean installs/recovery, workable supported deployments, no undisclosed new service requirement | Supported-platform failure, hidden prerequisite, unusable diagnostic or consumer path |
| Security and privacy | Installed access and disclosure contracts pass adversarial tests; candidate/evaluator authority stays separate | Critical capability escape, secret/source leakage, unsafe reader/parser or release authority |
| Differentiation | A meaningful customer workflow or operating metric improves under matched quality | Only microbenchmark, tool-count or token-volume gains; an unsupported marketing claim |
| Release readiness | Exact final packages, consumer/provider tuples, docs, support matrix and switching rehearsal qualify | A local-only integration, missing required lane or artifacts differing from those tested |

Set acceptable harm and the minimum useful benefit from customer consequences before inspecting candidate comparisons. An independent owner fixes any task-quality non-inferiority margin in absolute success points and implied failure frequency. A pilot estimates baseline rates, variability and sample size; it does not relax that margin to make a result pass. Deterministic functionality and critical evidence allow no missing required behavior. For a finite, predeclared set of consequential job strata and the aggregate, observed Thistle success must be no lower and paired uncertainty must exclude loss beyond the approved margin. A lower observed score fails that chosen floor; adequate point estimates with insufficient precision are inconclusive. Apply appropriate control to simultaneous claims and selected superiority tests without treating every extractor/platform combination as a separate stochastic stratum. Claims state the margin and workload; strict superiority requires its confidence bound to exceed zero. Unset, failed or inconclusive required gates block launch.

Measure cold first extraction including boot, incremental edit-to-fresh-client output, cold server startup, warm throughput/latency and complete customer tasks. Report p95 only with adequate tail sampling. Count all owned processes, native workers and services in CPU/memory/IO/disk accounting, with an explicit method for shared/file-cache memory. Charge sustained churn, retained generations and compaction/maintenance debt. Do not sum unrelated per-process peak RSS values as a simultaneous total.

Use paired randomized trials, fresh independent worker units and application/task-aware uncertainty. Preserve timeouts, crashes, retries and failed attempts. Cost per successful task includes failed attempts and a declared indexing amortization horizon. Run A/A calibration to expose benchmark bias.

Keep a frozen holdout and a campaign-wide exposure ledger. Select the final candidate before confirmation; repeated confirmation attempts require a predeclared limited-attempt/error-budget rule and fresh evidence where appropriate. The optimizer cannot repeatedly probe the same holdout until it passes. Publish the scope, artifact identities, distributions, errors and limitations of any comparative claim.

# Introspective improvement as development practice

Use the accepted gem as an instrument throughout development. Initially Woods may help inspect the newly written Ruby code and fixture apps; ordinary profilers and compiler tooling supply the native evidence it cannot see. As soon as the candidate supports the necessary source contracts, use its accepted build to inspect its own repository and the Rails workloads.

Self-inspection needs language-neutral source identities and performance attribution. A Rails reflection path does not explain a standalone gem's Ruby code, and Ruby-only maps do not explain Thistle's Rust engine. Provide useful static Ruby source views plus exact native source/profile attribution through established tooling; a custom polyglot analyzer is not required. Link selected CPU/allocation or other profiles to the optimized artifact that actually ran. Unsupported Rust symbols, macro expansion, call relationships and dynamic Ruby resolution remain explicit gaps.

Tie the gem digest, loaded extension/executable hashes, source revision, debug symbols, compiler options, dependency locks and runtime/ABI to each profile. Diagnostic and release builds are different artifacts. Verify that optimized inlining/symbolization still yields useful evidence; otherwise native acceleration has created a self-inspection blind spot.

The loop is bounded: record a customer-visible bottleneck or correctness failure; inspect source and profile evidence; form a falsifiable hypothesis; make a small PR; build an immutable candidate; run independent behavior and performance gates; accept or reject it. Keep unsuccessful experiments as evidence. A candidate cannot update its own acceptance policy.

Before launch demonstrate at least one complete cycle in which the candidate's own evidence informs a patch and an independent evaluator verifies the resulting artifact. This proves the development mechanism operates. It does not prove that agents are more productive or that the product autonomously improves after installation. Such productivity claims need a separate controlled comparison against ordinary profiling/review with matched model, tools, time and cost.

The shipped gem remains versioned software. Runtime adaptation, where justified, is restricted to bounded configuration choices with stable limits and reproducible results. Automatic production self-modification is not a launch requirement.

# PR workflow CI and core security

Each implementation PR owns a bounded capability or failure case. Each optimization PR adds the profile, hypothesis, unchanged semantic contract, complete artifact measurements, tradeoffs and rollback/switching implications. An agent may prepare code and evidence; independent reviewers own capability classification, evaluator policy, security decisions and release authorization.

CI selects the protected evaluator and required lanes outside the candidate's control. Candidate-authored path filters cannot omit a gate. Expected-result changes and new benchmark thresholds are separate reviewed evaluator changes, demonstrated against intentionally defective implementations. A new head or relevant merge invalidates prior evidence for the affected exact artifact tuple.

| Lane | Trigger and purpose |
|---|---|
| Public contracts and package independence | Every implementation PR: clean installed gem, tool registration, query schemas, required facts, explicit refusals, absence of Woods runtime dependency |
| Runtime and mutation | Extraction, source, schema, lifecycle and index changes: real booted Rails, independently labelled facts, persistent readers, full/incremental equivalence and failed-publication isolation |
| Retrieval and tasks | Ranking, source representation, budgets, provider or prompt/default changes: relevance/coverage plus paired customer tasks and full-source recovery |
| Consumers and reused UI | Thistle API, publication or adapter changes: installed Thistle-only bundle, new Ruby/non-Ruby readers, redesigned browser/Guide/report jobs and version refusal |
| Native and distribution | Binding/parser/build changes: promised Ruby/ABI/platform routes, precompiled/source installs, GC/cancellation/fork cases, fuzz and sanitizer regressions |
| Security and privacy | Baseline on every PR plus affected deep tests: source authorization, HTTP origin/authentication, malicious inputs, path handling, Guide bounds, disclosure and CI isolation |
| Controlled performance | Optimizations and architecture promotions: matched complete-workflow measurements on controlled workers |
| Release qualification | Exact final package tuple: full declared support/feature matrix, soak/recovery, docs/setup and switching; scheduled-only coverage is insufficient |

Candidate code runs with minimal tokens, bounded network access, isolated caches and no production or release credentials. Keep privileged workflows separate from untrusted PR checkouts; never execute untrusted code in a secret-bearing privileged PR context. Pin third-party CI dependencies and protect policy/workflow changes. Release credentials belong to a separate protected publication process, with artifact provenance and actual package verification. [C24–C25]

Published source, schema defaults, profiles and logs may contain sensitive information. Application extraction boots trusted application code and inherits its authority; an offline reader is a different boundary. Minimize captured fields, make provider transmission explicit, protect snapshots and reports, and use access/retention rules appropriate to source data. Do not collect locals, process dumps or sensitive record values by default.

Test malformed/corrupt snapshots, length/offset overflow, native memory failures, path/symlink escape, oversized inputs, stale identities and resource exhaustion. Map and diagrams must escape untrusted source and identifiers, preserve CSP and access rules, and remain usable with keyboard and constrained viewports. Guide content cannot grant extra tools or controller authority.

Required checks that are missing, cancelled or timed out do not pass. Quarantine or rerun rules are predeclared and retain failure evidence. Scheduled fuzzing, scans and soak tests supplement exact-candidate qualification; they do not retroactively qualify a changed release.

# Implementation sequence and estimate discipline

The prior demonstrator and pilot figures are not Thistle launch estimates. They covered a narrow cohort and omitted much of the product. This plan replaces those ranges with work packages and explicit estimate gates; no invented multiplier can make the old numbers credible.

| Work package | Outcome | Dependency or sizing evidence |
|---|---|---|
| W0 Product and interaction contracts | Required customer jobs, evidence coverage, support/deployment baseline, simple action vocabulary and comparison rules | Fresh public inventory, installed comparison, observed investigation and naming tasks |
| W1 Independent evaluator | Job adapters, expected facts, mutations, hostile-candidate tests, baseline quality/performance/cost | W0; begin fixture work while inventory finishes |
| W2 Delivery foundation | Independently named gem, executable/Rails facade, package identity and chosen optional UI packaging | Clean install on floor/current and high-risk promised platforms; Rust engine, Ruby/native boundary and native package qualification |
| W3 Evidence foundation | Capture, identity/provenance, shared inputs, publication and a complete source-to-query slice | W1–W2; two dissimilar evidence families and an early reused-Map journey |
| W4 Coverage completion | All useful current Rails/application/source/graph evidence jobs | W3; size per semantic difficulty and observed family throughput, not old extractor count |
| W5 Queries and deployments | Thistle's own action/query contract, retrieval modes, provider/deployment jobs, history/impact, exports and CI reading | W3–W4; real provider/storage and quality evidence |
| W6 Coherent operation | Incremental/watch/reload, source/vector freshness, retention, recovery and resource limits | W3; mutations grow with W4–W5 |
| W7 Reused UI and naming | Full human job coverage through a simpler workbench, home-row access, word-finding support and optional Guide | Early W3 seam; complete with W4–W6; real provider and user task evaluation |
| W8 Introspective improvement | Source/profile linkage and an independently judged improvement cycle | W1 plus useful W3/W6 evidence; Ruby and Rust source/profile attribution |
| W9 Setup and support | Fresh install, Docker/worktrees, diagnosis, disclosure, switching and documentation | Starts W2; completes after required W5–W7 paths |
| W10 Launch qualification | Every required job closed, baseline drift reviewed, exact release tuple tested and benefits confirmed | W1–W9 and no unresolved required gates |

Begin with a bounded discovery/feasibility timebox whose exit is an executable Rust architecture and a costed plan, not public release. First establish actual baseline jobs and support promises, package independence, one coherent fact/query flow, an evaluator that rejects defective results, and one real reused-Map path. Profile the installed native artifact before selecting further optimizations. These results cannot establish full parity, scale, all UI jobs or a launch date.

After two dissimilar capability families and the installed UI seam, estimate each remaining work package from observed throughput and remaining semantic risk. Include evaluator work, integration rework, documentation, support qualification and an explicit contingency. Publish optimistic/likely/adverse assumptions. Track engineering effort, elapsed critical path, CI/service capacity and independent review capacity separately.

The critical path is agreed jobs/support → viable installed package and evidence/UI boundaries → complete coherent evidence → complete retrieval/operation/human jobs → comparative qualification. Some coverage, interface and evaluator work can proceed in parallel after their shared contracts stabilize.

Use a lean Rust implementation first. A custom storage or residency design, additional native services, or broader parallelism may be funded when it removes an observed launch bottleneck and passes the same quality/install/operation gates. The Rust requirement does not justify complexity without evidence or dropping useful jobs. Re-estimate the work packages to include native packaging, source/profile attribution and the Ruby/native boundary.

Deliver small vertical PRs linked to job and evidence rows: contracts/evaluator; independent package; evidence slice and reused UI seam; coverage families; lifecycle and retrieval; investigation/naming; complete support; measured optimization; exact release qualification. The first public launch follows W10, not the first attractive demo.

# Launch decision and switching

The public launch decision is a conjunction: complete required functional coverage, independent correctness, demonstrated task quality, acceptable complete-workflow performance and cost, supported installation/deployment, full Map integration, security qualification and exact artifact readiness. A high average score cannot compensate for a missing capability or failed required cohort.

Use a separately named candidate bundle and separate indexes throughout comparison. Do not mutate Woods output in place or require users to surrender their previous working setup. Provide a concise task-oriented adoption guide for Thistle's new commands and configuration. Users may change their workflow and integration; there is no promise of drop-in old-tool compatibility.

Switching trials install the candidate from released-style artifacts, build its own index, connect Thistle's clients and reused UI through its own contract, validate expected evidence and exercise a return to the previous pinned user setup. This is product switching support, not maintaining the old gem's implementation or release line.

Publish the supported capability matrix, actual dependency requirements, comparison versions, measured benefits and limits. Avoid global fastest, complete-call-graph, zero-setup or autonomous-self-improvement claims unless their meaning and evidence truly support them. The intended launch is a better way to accomplish the useful work, with no hidden loss of capability.

# Review decisions

Three fresh independent agents reviewed customer-outcome parity, competitive strategy and delivery/evaluation, challenged the integrated proposal and approved the same final candidate. The approved substantive revision has SHA-256 0be7dbb21f69390254bd16a9bf12625094c0916d0ceed386b8c493b7fbf2556e. Only approval-status metadata changed afterward. No identified blocking design or planning findings remain. That hash identifies the original plan before the owner's Rust requirement. The Rust amendment above is an explicit owner direction; implementation reviews and measurements must identify their own exact artifacts rather than inheriting the earlier plan approval.

| Review | Verdict | Scope |
|---|---|---|
| Product parity | APPROVE | Customer jobs, evidence breadth, human investigations, deployment outcomes and real-provider qualification |
| Competitive strategy | APPROVE | First-principles alternatives, meaningful differentiation, naming/usability, measured technology investment and quality/cost gates |
| Delivery and evaluation | APPROVE | Minimal packaging, independent Thistle/Map operation, exact-artifact CI, work packages, estimate discipline and launch gates |

| Finding | Resolution |
|---|---|
| Earlier proposal was a prototype rather than a competitive launch plan | Full useful outcome parity is mandatory at launch; incomplete prototypes are internal milestones |
| Compatibility planning risked recreating Woods | Old tools, APIs, schemas, formats, URLs and dual-product support are not requirements; comparison translation lives in the testbed |
| Map's documented surface and dependencies were understated | Reuse its useful code and assets, cover the broader customer jobs, remove Woods runtime dependencies and qualify a real Guide provider |
| Technology choices could become goals themselves | Profile and estimate benefit before bounded native/storage/residency experiments; retain simpler implementations when evidence is weak |
| Token or query improvements could hide worse answers | Functional/evidence gates are exact; task quality, complete-workflow performance and total cost have independent decision rules |
| Statistical equality could create an unusable gate | Customer consequences set any acceptable stochastic margin; pilots size evidence; deterministic capability and critical correctness are never relaxed |
| Naming could optimize keystrokes while worsening recall | Stable literal labels, visible choices, approximate discovery and optional remappable home-row shortcuts receive usability qualification |
| Prototype effort ranges could be mistaken for launch estimates | Withdraw those ranges; cost W0–W10 after inventory, dissimilar capability slices and installed UI evidence |

The owner has authorized the working name Thistle, reuse of Map and branding, and independent interfaces in one or a small set of gems. This plan supersedes the earlier rewrite proposal. Approval establishes design coherence; the installed-package, accessibility, performance, security and release evidence specified above is still required.

# Sources

Sources describe the comparison product or technical contracts; proposed choices and estimates are engineering judgments.

- C1 [Published Woods 2.1.0](https://rubygems.org/gems/woods) and [release notes](https://github.com/lost-in-the/woods/releases/tag/v2.1.0).

- C2 [Pinned current Woods README](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/README.md) and [documentation index](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/README.md).

- C3 [Pinned Woods Map README](https://github.com/lost-in-the/woods-map/blob/29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9/README.md).

- C4 [Pinned Map package dependencies](https://github.com/lost-in-the/woods-map/blob/29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9/woods-map.gemspec).

- C5 [MCP public and conditional capabilities](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/MCP_SERVERS.md).

- C6 [Current extractor reference](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/EXTRACTOR_REFERENCE.md).

- C7 [Markdown export](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/MARKDOWN_EXPORT.md).

- C8 [Evaluation methods and bounded experimental results](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/EVALUATION.md).

- C9 [Retrieval guide](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/RETRIEVAL_GUIDE.md).

- C10 [Backend matrix](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/BACKEND_MATRIX.md).

- C11 [Published Ruby reader and change checks](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/PUBLISHED_INDEX.md).

- C12 [Machine-readable index and retention contracts](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/INDEX_LAYOUT.md).

- C13 [Independent installed-artifact testbed](https://github.com/lost-in-the/woods-testbed/blob/25d46983115ed507e38b33af33a08ca58b023f46/README.md).

- C14 [Source freshness](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/SOURCE_FRESHNESS.md).

- C15 [Scoped Ruby runtime tracing](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/RUNTIME_TRACING.md).

- C16 [Client hooks](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/CLIENT_HOOKS.md).

- C17 [Current configuration and integration reference](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/CONFIGURATION_REFERENCE.md).

- C18 [SQLite isolation](https://sqlite.org/isolation.html) and [WAL publication and deployment constraints](https://sqlite.org/wal.html).

- C19 [Prism parser](https://ruby.github.io/prism/).

- C20 [CRuby thread and GVL API](https://docs.ruby-lang.org/capi/en/master/d6/dfb/include_2ruby_2thread_8h.html).

- C21 [RubyGems specification and extension packaging](https://guides.rubygems.org/specification-reference/).

- C22 [Rails threading and execution](https://guides.rubyonrails.org/threading_and_code_execution.html).

- C23 [Rails autoloading and reloading](https://guides.rubyonrails.org/autoloading_and_reloading_constants.html).

- C24 [GitHub Actions security](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions).

- C25 [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/).

- C26 [Map coverage and job discovery](https://github.com/lost-in-the/woods-map/blob/29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9/docs/design/coverage.md).

- C27 [Guide qualification limits](https://github.com/lost-in-the/woods-map/blob/29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9/docs/design/notes/m7-guide.md).

- C28 [W3C clear words guidance](https://www.w3.org/WAI/WCAG2/supplemental/patterns/o3p01-clear-words/).

- C29 [W3C character key shortcuts](https://www.w3.org/WAI/WCAG22/Understanding/character-key-shortcuts.html).

- C30 [W3C clear visible labels](https://www.w3.org/WAI/WCAG2/supplemental/patterns/o4p06-clear-labels/).

- C31 [W3C friendly search](https://www.w3.org/WAI/WCAG2/supplemental/patterns/o2p06-search/).

- C32 [Map threat model and authority boundaries](https://github.com/lost-in-the/woods-map/blob/29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9/docs/THREAT_MODEL.md).
