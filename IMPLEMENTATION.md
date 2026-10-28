# Thistle implementation handoff

**Status: implementation frozen for transfer to Codex. A private bootstrap repository now exists at https://github.com/lost-in-the-agent/thistle. Task launch must be verified separately in Codex.**

The current source is committed at `23ca426d8b2cc1da052492115748b60641ee4241`. Its latest complete local build and Ruby suite passed **28 tests / 237 assertions, with no failures, errors or skips**. The current local native binary is `24d42578b938bd5498c476f43e5a1239bf41f3760035d30630d8a11b8d451f7b`. That compiled binary is not included in the transfer; rebuild from source. The included historical gem predates JSON-depth, interrupted Reader construction and empty-path hardening. Its earlier installation pass does not qualify the current source. The first Codex task is to build and independently qualify a new hardened baseline. See [Codex handoff](CODEX_HANDOFF.md), [evaluator handoff](EVALUATOR_HANDOFF.md), [current test log](evidence/current-checkout-tests.log) and [ownership review](evidence/thistle-core-adversarial-review.json).

Independent review closed both reproduced ownership blockers. Three permanent regression tests passed with 20 assertions; the preserved pre-fix constructor failed both relevant negative-control tests as intended. The ownership-specific probe used native hash `67a6a685c18d4ab6fe7957f1bb7229dc2624c2cea8a1900c384f80966d20da02` before the final rebuild above. No performance candidate or optimized result exists. The independent evaluator is committed separately at `b81f5adc2c647083b6ce8688234012c6d2da0ee4`.

Thistle now has a Rust evidence engine distributed through a Ruby gem, explicit Rails observations, an optional Map gem using approved Woods Map presentation code, and a separate installed-artifact evaluator. The verified slice captures source, publishes a generation, finds facts, recovers exact captured files, preserves uncertainty and renders the evidence in a browser. Full launch parity and a comparative speed advantage remain unqualified. [Core contract](thistle/IMPLEMENTATION_CONTRACT.md) · [Full launch ledger](thistle/docs/capability-ledger.md)

Paths below are relative to the delivery bundle root: `thistle/`, `thistle-eval/` and `evidence/`. This handoff is outside the gem sources so completing the delivery record does not change a tested gem's bytes.

## What is implemented

| Part | Responsibility and boundary | Source |
|---|---|---|
| Rust core | Static capture using established Prism bindings; fact/source validation; generation publication; indexed identity lookup and bounded lexical queries. Ruby declarations and unresolved relationships are evidence, not a complete dynamic call graph. Rust files can be captured as exact source without a claim of Rust semantic analysis. | [Engine](thistle/engine/src/lib.rs), [capture](thistle/engine/src/capture.rs), [store](thistle/engine/src/store.rs), [schema](thistle/engine/src/schema.rs) |
| C bridge | Copies request bytes before releasing Ruby's GVL, calls Rust without touching Ruby objects, and frees response/input buffers through an ensured cleanup path. | [Native bridge](thistle/ext/thistle_native/thistle_native.c) |
| Ruby facade and CLI | Supplies the gem interface and literal `capture`, `find`, `source`, `links`, `check` and `version` actions. Explicit Rails capture observes an already booted trusted application. The initial runtime family is routes; source/runtime coherence stays unknown. | [Ruby API](thistle/lib/thistle.rb), [CLI](thistle/lib/thistle/cli.rb), [Rails capture](thistle/lib/thistle/rails_capture.rb) |
| Optional Map gem | Find → Source → Links/Check with generation-preserving links, accessible source scrolling, visible action labels and optional letter shortcuts. It consumes the Thistle reader and reuses the approved Map highlighter, token sheet and presentation structures. | [Map guide](thistle/map/README.md), [reuse provenance](thistle/map/docs/REUSE.md) |
| Independent evaluator | Installs supplied gem artifacts into a fresh gem home, runs outside the implementation checkout, and compares results with independently written expectations and failure controls. It can become a separate test repository or move into the independently controlled testbed. | [Evaluator guide](thistle-eval/README.md), [controller](thistle-eval/evaluate.py), [expected facts](thistle-eval/fixtures/ruby/expected.json) |

Rust owns the core architecture following the owner's implementation clarification. There is no Ruby engine fallback. The current build route is a Linux source gem with locked, vendored Cargo dependencies, Rust 1.90.0, a C compiler, Ruby development headers and libclang. The executed local tuple is Ruby 3.3.13 on Linux x86-64; the runtime lane used Rails 7.2.4. Broader platform support and precompiled installs remain qualification work. [Build requirements](thistle/README.md) · [Installed baseline evidence](evidence/baseline-report.json)

## Run the implemented slice

From a checkout of `thistle/` with the prerequisites available:

```sh
bundle install
bundle exec rake test
cargo test --locked --offline --manifest-path engine/Cargo.toml
gem build thistle.gemspec
gem install --local ./thistle-0.1.0.pre.1.gem
```

Set `LIBCLANG_PATH` if libclang is outside the normal discovery path; `THISTLE_CARGO` can select a particular Cargo executable. The package's private publishing guard remains in place. [Source-build instructions](thistle/README.md)

Capture and inspect a project:

```sh
thistle capture ./my-app --output ./my-app/.thistle
thistle find OrdersController --store ./my-app/.thistle --limit 20
thistle source FACT_ID --store ./my-app/.thistle --generation GENERATION_ID
thistle links FACT_ID --store ./my-app/.thistle --generation GENERATION_ID
thistle check --store ./my-app/.thistle --generation GENERATION_ID
```

Use a returned fact ID and generation ID in the follow-up commands. Results are JSON; errors are structured JSON on stderr with a nonzero exit. `Source` returns the full captured file and its digest. `Check` checks the saved evidence and coverage; it does not establish that a live application or working tree is unchanged. [CLI contract](thistle/lib/thistle/cli.rb)

Runtime inspection is an explicit Ruby call inside the trusted application's runner:

```ruby
require "thistle"

Thistle.capture(
  root: Rails.root.to_s,
  output: Rails.root.join(".thistle").to_s,
  rails: Rails.application
)
```

For Map, install the matching core and Map artifacts, then mount the Rack-compatible application explicitly:

```ruby
require "thistle/map"

Thistle::Map::App.new(store: "/absolute/path/to/store")
```

The host chooses the server and authorization. The local default checks both the loopback peer and Host; remote deployment requires an explicit authorization callback and allowed hosts. The app accepts GET/HEAD, escapes source, uses a restrictive CSP and exposes evidence consumption. The [Map README](thistle/map/README.md) includes the mounting example and explains the host's authority boundary.

## Verified evidence

| Check | Observed result | Record |
|---|---|---|
| Independent installed core | Passing baseline verdict: installed package without Woods; independently expected declarations/source/links; repeat identity; edits and retained generations; refused invalid publication/IDs/limits; symlink escape; explicit syntax failure; corrupt source; real Rails route observations | [Baseline report](evidence/baseline-report.json) |
| Native parser regression | The installed core completed the required 10,000-nested-array case from a Ruby worker thread without process failure; the evaluator used a fresh worker-local Cargo home | [Baseline report](evidence/baseline-report.json), [probe](thistle-eval/parser_probe.rb) |
| Core-to-Map suite | 21 tests, 165 assertions, no failures/errors/skips, including real native capture, old-generation source, Rack response lint, escaping, access gates and reader cleanup | [Map validation](thistle/map/docs/VALIDATION.md), [Map tests](thistle/map/test/) |
| Browser checks | Find/Source/Links/Check at 1440, 960, 640 and 390 pixels: 16 combinations, zero reported axe violations; keyboard controls and no-JavaScript navigation passed | [Native browser results](thistle/map/docs/browser-native-results.json) |
| Installed core + Map | Installed source-to-UI smoke passed outside both checkouts; all loaded Thistle implementation files/native bytes came from the isolated gems, with Woods absent | [Installed Map report](evidence/map-installed-baseline-report.json), [smoke script](thistle/map/test/installed_smoke.rb) |

The browser run used Chrome for Testing 134.0.6998.35 and axe-core 4.10.3. Final source views were visually inspected at desktop and phone widths. Some axe contrast checks were marked incomplete; the record retains that limitation and a targeted colour-pair correction. Automated browser checks do not qualify intended-user accessibility or naming effectiveness. [Detailed validation limits](thistle/map/docs/VALIDATION.md)

The installed baseline's loaded native SHA-256 is `cb3870d86268099cc23dcd8010316f2c130047bff15bc92404bb3fcc786bff11`. Its successful repeated evaluation includes the added parser regression and Cargo isolation. Final delivered package identities belong in the pending selection record below; an earlier passing binary cannot qualify a changed one. [Baseline report](evidence/baseline-report.json)

### Defects found and corrected during integration

| Finding | Resolution and retained check |
|---|---|
| Whole-file byte/line coordinates disagreed at a trailing newline | Capture now reports the line at the exclusive byte endpoint. Strict source-coordinate validation stayed in place; native and real Map integration regressions cover the boundary. [Capture tests](thistle/engine/src/capture.rs), [Map integration](thistle/map/test/integration_test.rb) |
| Source-gem packaging omitted a vendored dependency's legitimate `src/target` files | The packaging exclusion was corrected. A fresh, offline installed-artifact run verifies the packaged source and dependencies rather than relying on the development checkout. [Gem specification](thistle/thistle.gemspec), [baseline report](evidence/baseline-report.json) |
| Deep parser/AST destruction could fail on a Ruby worker's stack | The native capture boundary was hardened, and the independent evaluator gained a deadline-bound installed worker-thread regression. This remains a specific regression case, not broad hostile-parser qualification. [Parser tests](thistle/test/test_parser_boundary.rb), [evaluator probe](thistle-eval/parser_probe.rb) |
| Map could retain native reader handles until garbage collection | Requests now close their reader in `ensure`, including failed reads. [App](thistle/map/lib/thistle/map/app.rb), [request tests](thistle/map/test/app_test.rb) |
| Browser checks exposed a missing landmark, a selected-comment contrast edge and incorrect UI-font specificity | The capture status moved inside the main landmark, selected comments gained adequate contrast for the checked pair, and human guidance uses the intended sans-serif role. Final browser checks passed. [Validation](thistle/map/docs/VALIDATION.md) |

Failed and inconclusive setup attempts are retained with the evaluator evidence. A harness invocation issue and navigation/stylesheet synchronization issues were corrected in the tests; they were not counted as product passes. [Evaluator records](evidence/) · [Map validation](thistle/map/docs/VALIDATION.md)

## Operational and security limits

Publication validates content before changing the current-generation pointer. Failures before that change preserve the earlier generation; a directory-sync failure after it reports `commit_uncertain`, because the new generation may already be current. Readers pin a generation and check expanded source bytes. Store access uses descriptor-anchored paths and rejects symlinks/non-regular files. Digests provide integrity checks, not authorization or signatures. [Store](thistle/engine/src/store.rs) · [Filesystem boundary](thistle/engine/src/fs.rs) · [Operational guide](thistle/README.md)

The current milestone retains generations and blobs until the store is removed; automatic retention, storage quotas and power-loss recovery are not qualified. Native registry limits count encoded data and handles, not measured process RSS. Inherited native state after `fork` is refused; general fork support remains open. Explicit Rails capture inherits application authority and does not certify an immutable boot epoch. [Operational guide](thistle/README.md)

The evaluator's sibling directory and clean gem environment provide reproducibility, not OS isolation. Protected CI still needs an independently controlled policy/verdict service and disposable constrained workers for build, install and execution. The checked-in CI workflow is development feedback: pinned actions, read-only permissions, no path filters and no publishing step. Hosted runs, required external checks, branch protection and release identities have not been configured by this milestone. [CI/security record](thistle/docs/ci-and-security.md)

## The launch bar is preserved

Every row remains **UNQUALIFIED for launch**. The complete baseline references, expansion inventory, acceptance-owner roles and required closure fields stay in the [launch capability ledger](thistle/docs/capability-ledger.md).

| Row | Required outcome still to qualify |
|---|---|
| L01 | Supported installation, configuration, diagnosis, containers and worktrees |
| L02 | Loaded Rails schema, associations, callbacks, concerns, inheritance, routes and configuration |
| L03 | Useful application/framework/package families and optional configurations |
| L04 | Original/effective source, identity, physical spans, versions and provenance |
| L05 | Exact discovery and bounded name/path/source/metadata search |
| L06 | Lexical/semantic ranking, complete source recovery, budgets and provider readiness |
| L07 | Dependencies, dependents, flows, structure, clusters, reports and diagrams |
| L08 | History, co-change, generation comparison, change impact and relevant tests |
| L09 | Full/incremental/targeted refresh, watching, reload, branch/crash handling and maintenance |
| L10 | Supported scoped runtime tracing/session evidence |
| L11 | Local/offline, hosted, shared-reader and durable retrieval deployments |
| L12 | Ruby, new stdio/remote interfaces and machine-readable checks/exports |
| L13 | Markdown/Obsidian/diagram/report sharing with reproducible evidence links |
| L14 | Complete browser reading of source/behavior/references/ownership/schema/routes/history |
| L15 | Action/change/flow/architecture/database investigations and collect/resume/share workflows |
| L16 | Optional contextual help with real declared providers, limits and provenance |
| L17 | Readiness, recovery, adoption/switching and secure documented operation |

A launch decision also needs independent correctness, task quality, total cost, full-workflow resource/performance evidence, recognition-focused interaction, security/privacy and exact final-artifact qualification. A narrow passing slice or one successful optimization cannot close these gates. Old interfaces need not be preserved; useful customer outcomes remain the comparison bar. [Ledger and cross-cutting gates](thistle/docs/capability-ledger.md)

## Next bounded implementation work

Each item is a separate reviewable change, with further platform/family expansion split into later PRs. This queue does not replace the full ledger.

| Next PR-sized slice | Required acceptance evidence |
|---|---|
| Put the evaluator under separate repository/controller ownership and bind an external required check to package/head/evaluator identities | Deliberately defective artifacts fail; candidate workflow/path changes cannot suppress the check |
| Qualify one precompiled Linux/Ruby artifact route | Install the exact artifact without a compiler, exercise core + Map, record native identity; retain the source-build route |
| Add one real runtime schema/association family | Independently labelled configured, missing, failed and mutation cases; no invented source positions or coherence |
| Establish one immutable runtime-capture input path | Source changes during boot cannot be labelled coherent; unverifiable intervals remain explicit |
| Add bounded generation retention and reader leases | Active pinned readers remain valid; expired generations refuse; byte budgets and recovery cases are measured |
| Add one incremental static-file path | Full and incremental outputs agree under add/edit/delete/rename and negative-dependency cases |
| Expose the first typed external query protocol | A fresh non-Ruby client can Find/Source/Links/Check with version refusal and identical generation/evidence semantics |
| Extend one Map action-to-source investigation and test it with intended users | A coherent task works across route/source/links, with stable focus, clear unknowns, recoverable input and measured word-finding/navigation effort |

Broader families, semantic retrieval, deployment/provider cohorts, history/impact and complete human journeys continue through the ledger. Estimates should be revised from these completed slices and their integration/review costs; this handoff makes no launch-date commitment.

## Deferred to Codex: introspective experiment and final artifact selection

**No final optimized artifact has been selected. These are explicit next tasks, not missing results that should be inferred.**

Experiment 001 registers a source-informed hypothesis: prepare immutable normalized search records once when a reader opens, then reuse them across queries. The accepted baseline is to inspect its own packaged source and preserve source/generation/native/build identities. The independent policy charges complete process-until-results time, single and repeated sessions, memory, semantic equality and A/A calibration. Its synthetic workload and acceptance thresholds are frozen before candidate results. [Experiment hypothesis](thistle/docs/experiment-001.md) · [Independent policy](thistle-eval/policies/experiment-001.json) · [Comparison controller](thistle-eval/compare.py)

| Final field | Status |
|---|---|
| Baseline self-inspection evidence and exact source/native/build identities | Not run. Rebuild and qualify the hardened baseline, then inspect its packaged source using that exact installed gem. |
| Candidate quality report and exact artifact identities | No optimized candidate built or evaluated. |
| Frozen paired experiment report, descriptive results and failed attempts | No candidate comparison run. The retained A/A smoke validates the harness only. |
| Retain/reject decision under the predeclared policy | No optimization decision made. Retain the hardened baseline if a future candidate fails or is inconclusive. |
| Selected core gem, Map gem and loaded native SHA-256 tuple | No final selected tuple. Historical package identities and current source/native identities are recorded separately in EVALUATOR_HANDOFF.md and the ownership review. |
| Installed core + Map smoke for that exact selected tuple | Required after the hardened baseline and any selected optimization. Only the historical pair has passed. |
| Final source/archive manifest and review disposition | Transfer contains MANIFEST.json, SHA256SUMS, both Git bundles, current audit and historical design reviews. Those historical design reviews predate the owner’s mandatory Rust amendment and are not implementation approvals. |

Any result is a bounded development experiment on this early implementation. It does not establish a Woods comparison, general speed advantage, population confidence bounds or automatic production self-improvement. A completed cycle would demonstrate that captured source informed a bounded patch which an external evaluator accepted or rejected.
