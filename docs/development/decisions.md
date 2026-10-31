# Development tooling and cohort decisions

## Saved model source comprehension (PR 120 / LOS-147)

Reuse the existing Rust saved-method directory with an additive bounded
candidate-position page, the existing recorded-label directory and pinned Reader
identities. The previous unique/ambiguity witness stops at the second match and
cannot enumerate all saved alternatives. A second owner index or Ruby resolver
would duplicate semantic authority, retention, invalidation and maintenance cost.
See the [Core contract](source-comprehension.md) and
[Map contract](../../map/docs/source-comprehension.md).

The chosen page preserves duplicate candidates and physical spans, charges every
visit/comparison/label byte through Work, and releases the directory mutex before
Source I/O or projection. Directory construction remains lazy whole-domain
validation/visit/sort work, not zero-scan retrieval. Positional pages repeat their
bounded prefix traversal and charge it again. Reader open, lazy build and request
work remain separate costs; no speed, RSS or full native heap result is claimed.
Reconsider the cursor/index shape only if measured complete investigations show
material repeated-prefix cost, preserving identity and ambiguity rather than
raising limits or promoting a prefix to a complete answer.

The caller explicitly supplies already loaded classes and a stop boundary. Bound
builtin Module/Class/UnboundMethod reflection observes direct/effective descriptors
without application getters, autoload, discovery or method execution. Rust strictly
validates/adopts the DTO and owns selection. Executing inspected source or adding
a general Ruby method analyzer would add authority and cost without proving
source/runtime coherence. Observed owner order and descriptor hints do not bind a
saved body to a loaded registry; unsupported precedence stays unknown. Reconsider
the observer only for a changed supported reflection contract or a concrete
customer question beyond this bounded model/concern slice.

Map reuses the existing highlighter, attributed Field Guide tokens/reading pattern
and single NavigationContext.url authority, rather than a new renderer or URL
framework. It requests one bounded projection and exposes explicit supporting
family/reference actions. Selected pinned files reserve aggregate 64 KiB before
deduplicated Source reads. Exact response identity/digest/byte count and aggregate
2000 display lines are checked before highlighting/HTML; an over-line file is
wholly not admitted and keeps its byte reservation. Manifests have no line counts,
so lines are a post-response display guard, not pre-read eligibility. Body and
envelope limits charge expanded markup/URLs; existing Native Source scratch remains
Core-owned. The operating cost includes one pinned manifest pass, bounded source
hash/line checks, highlighting and copied display output. Reconsider pre-read line
metadata only if actual investigation evidence justifies its capture/storage cost.

Both packages explicitly include their source-comprehension guide; package selectors
and installed-manifest assertions share the same exact doc sets. Cross-package
guide links use explicit pinned source URLs instead of escaping installed roots.
Native, installed/served, independent investigator and person acceptance remains
pending. This source increment does not qualify L04/L14 or complete Field Guide
discovery, all Rails annotations, schema/graph/history/Trail or optional Guide.

## Saved-model Markdown presentation (PR 118)

Present one bounded Rust-selected `model_brief` using the existing CLI and a
small allowlisted Markdown renderer. The [report contract](model-brief-markdown.md#fit-and-maintenance)
records the alternatives, operating cost and reconsideration criteria. A general
Markdown parser or serializer would add a dependency and richer output policy
for a fixed heading/list/code-span vocabulary. The renderer follows no source
or relationship pages and owns no persistent export state. Review its allowlist
when the response shape changes; richer formats may justify a maintained
serializer. The report and Reader have explicit encoded-byte limits, not an RSS
or speed guarantee. The installed Core guide documents evidence resolution and
caller-owned output; publication and capability qualification stay separate.

Reviewed **2026-10-28**. These are deliberate development choices, not permanent
defaults or launch qualification. Recheck the cited upstream state when changing
them. A historical baseline explains provenance; it does not justify a greenfield
default without a current fit, support and cost assessment.

## Ruby and Rails: current primary, one useful minimum

The exact pairs are owned by [`.github/ci-policy.json`](../../.github/ci-policy.json):

| Role | Ruby | Rails | Reason |
|---|---|---|---|
| Primary | 4.0.9 | 8.1.4 | Current stable Ruby and current stable Rails release; lead development on the environment the new project intends to serve. |
| Minimum | 3.4.12 | 8.1.4 | The other Ruby branch in normal maintenance; exercise its distinct Ruby/native boundary without an unnecessary Rails cross-product. |

Ruby's [downloads](https://www.ruby-lang.org/en/downloads/) and
[branch status](https://www.ruby-lang.org/en/downloads/branches/) identify Ruby
4.0 and 3.4 as normally maintained. Ruby 3.3 is security-only; Ruby 3.0 is EOL.
Rails announced [8.1.4](https://rubyonrails.org/2026/9/24/Rails-Version-8-1-4-has-been-released)
and explicitly described [7.2.4 as the final 7.2 release](https://rubyonrails.org/2026/9/24/Rails-Version-7-2-4-has-been-released).
The [Rails maintenance policy](https://rubyonrails.org/maintenance) lists security
coverage for 8.1 through October 10, 2027 and for 8.0 through November 7, 2026.
Starting a new default on 7.2, or adding a routine 8.0 row near its end of support,
has no demonstrated product benefit here.

Both gems now declare Ruby >=3.4. The Gemfile reads the primary Rails requirement
from the policy; an explicit `THISTLE_RAILS_VERSION` still selects a deliberate
test cohort. Exact patches make a run's intended inputs clear. Per-run locks and
manifests record actual resolution; this does not promise reproducible archives.
The current source-development routes are Linux and macOS; platform evidence
and remaining limits are recorded in the macOS/Linux decision below.

PRs ordinarily use primary. Workflow, dependency, policy and Ruby/native-boundary
changes also test minimum. Main runs primary plus the separate minimum job;
scheduled/manual broad checks run both. The Rust-only unit suite runs on primary
once; both selected Ruby rows compile their own bridge and run applicable Ruby
and Map tests. A failed, cancelled or missing selected row cannot pass the
required aggregate. Release preparation builds one package pair and installs
those exact bytes on both declared pairs.

This is an explicit proposed support boundary for new candidates. Existing
historical evidence remains scoped to its original versions. The full launch
support and platform requirements still need accepted installed evidence; merely
changing the matrix or gemspec does not satisfy them.

### Dependency locks: library compatibility feedback and exact tested resolutions

Keep the development `Gemfile.lock` uncommitted and retain exact primary and
installed-cohort locks with each candidate's evidence. RubyGems' current
[library guidance](https://guides.rubygems.org/faqs/#using-gemfiles-inside-gems)
explains that downstream applications resolve a gem's dependency requirements
independently of its developer lock. Fresh development resolution exposes
compatible-range dependency changes instead of silently narrowing feedback to
one old graph. The operating cost is dependency-change triage and preservation
of each tested resolution, not deterministic dependency resolution.

A committed root lock would stabilize developer resolution, but setup-ruby's
deployment behavior would freeze both CI cohorts and require explicit updates
plus a separate fresh-resolution lane. Separate committed primary/minimum locks
add selection machinery without a demonstrated need while both use Rails 8.1.4.
Retain the current per-run approach for this bounded library milestone. Do not
adopt the guide's literal `lockfile false`: Thistle needs ephemeral locks for
cache keys, manifests and evidence. Neither gem packages the development lock.

Record actual Bundler versions, lock digests and dependency gem hashes with
each primary/install tuple. Modern Bundler locks support
[checksums](https://guides.rubygems.org/security/#lockfile-checksums); these detect
byte substitution after locking, not safe authorship or reproducible archives.
Listed lock platforms are resolution variants, not tested platform support.
Separate cohort resolutions must not be presented as one universal installed
lock. Exact dependency/toolchain bytes are needed for a later replay attempt;
locks alone do not establish reproducible resolution, environments or packages.
Historical locks and frozen experiments remain untouched.

The installed driver uses the supported `BUNDLE_CACHE_ALL=true bundle cache`
configuration rather than the removed Bundler 4 `--all` option. This retains
path/git dependency caching for the installed worker without persisting another
configuration file or changing dependency versions.

### Why the original pair changed

The original source matrix used Ruby 3.3 / Rails ~>7.2. The hardened-baseline
commit `39f49d500ad941b01f9a839978f0fca599d812c6` pinned Ruby 3.3.13 / Rails 7.2.4,
and the [acceptance record](../handoff/BASELINE_ACCEPTANCE.md) records installed
checks and the selected artifacts on that pair. The first workflow draft reused
it for continuity without independently reviewing current support policy. That
was insufficient justification for this new project's routine default.

Keep Experiment 001's accepted packages, evaluator, policy and environment
identities. A current gem requiring Ruby >=3.4 cannot be substituted into its
Ruby 3.3 environment and called a replay. New work on the modern environment
needs new evidence; the earlier experiment's result is neither erased nor
silently broadened. The historical baseline workflow refuses current-policy
source before installing tools or compiling it.

The completed Experiment 001 workflow is
[retired outside active Actions](retired-workflows/README.md). Keeping its manual
dispatch with an exact historical-source allowlist was considered, but would add
preflight and failure-upload maintenance for a campaign that must not be replayed
as routine work. An inert copy plus exact original-source/run links preserves
provenance without a new executable guard or dependency. PR #27's maintained pin
updates remain separate from historical action identities. Reconsider an active
campaign only with a separately reviewed source/environment/policy decision.

## Changelogs: Woods' workflow, Towncrier's implementation

Keep the useful Woods model: each change owns a unique fragment; one release
owner consolidates notes. Use **Towncrier 26.9.0** for parsing, category grouping,
ordering, rendering and consumption. Its
[official documentation](https://towncrier.readthedocs.io/en/26.9.0/) supports
Markdown, explicit non-Python versions and independent packages sharing one
configuration. Core and Map have separate fragment directories and changelogs,
so preparing one package cannot consume the other's pending notes.

| Considered approach | Decision |
|---|---|
| Towncrier | Selected: established fragment workflow, configurable categories, explicit version/date, read-only preview, small Python tool environment already available to metadata CI. |
| Scriv | Capable, but broader dependencies and a looser authoring model do not improve this use case. |
| Changie | Good project support, but introduces a separate binary, YAML fragments and SemVer conventions that add adaptation to the current RubyGems prerelease spelling. |
| Reissue | Ruby-native, but build/version/commit hooks add coupling; its inspected fragment read/clear behavior needs substantive changes to preserve only-validated-input consumption. |
| Woods' implementation or a new custom fold | Adds ownership of parsing, history rewriting and deletion semantics without a demonstrated advantage over Towncrier. |

The inspected Woods policy is at
[`e7d69207...`](https://github.com/lost-in-the/woods/blob/e7d692072cce79220e2ea7efce0625003f9dd792/CONTRIBUTING.md#during-feature-work).
The adaptation keeps its ten useful categories and input-safety expectations;
Towncrier's native filenames are the new authoring format. Automatic folding of
old beta/RC history into a final section is not adopted: dated prerelease history
remains, and final-release notes are prepared explicitly.

Towncrier's inspected reader follows paths and replaces invalid UTF-8. A small
precheck therefore rejects non-regular/symlinked/nested inputs and invalid/empty
text before invoking it. This guard does not implement another renderer.
Always validate complete pending sets with strict draft rendering; the tool's
branch-presence `check` can intentionally skip when the consolidated changelog
changes, so it is not the sole validation gate.

The complete notes tool dependency set is pinned and hash-checked in
`.github/requirements-notes.txt`. It is development-only and ships in neither
gem. Measure installation and rendering cost before adding caching machinery or
claiming a speed advantage. See the [changelog guide](changelog.md) for commands,
package boundaries, staging behavior and release-readiness checks.

## GitHub actions: maintained runtime, immutable revision

The original pin check confirmed authoritative commit objects but missed obsolete
Node 20 declarations. GitHub's successful run still carried forced-Node-24
warnings. Passing CI was insufficient maintenance evidence.

| Action | Chosen release | Declared runtime |
|---|---|---|
| actions/checkout | v7.0.1 | Node 24 |
| actions/upload-artifact | v7.0.2 | Node 24 |
| actions/download-artifact | v8.0.2, existing pin retained | Node 24 |
| ruby/setup-ruby | v1.335.0, existing pin retained | Node 24 |

The [pin registry](../../.github/scripts/action-pins.json) records full SHAs,
versions and source metadata. The observed hosted runner 2.338.0 exceeds Node
24's 2.327.1 minimum. Keep `persist-credentials: false`, read-only permissions,
immutable artifact-ID downloads, digest mismatch failures and manifest checks.
Do not use a runtime-override flag to conceal an outdated action declaration.

## Rust and native dependencies: retain the declared contract for this change

Rust 1.90 is the explicit `rust-version` minimum and the pinned vendored build
contract. Preserve it and libclang 18 during this Ruby/Rails transition so that
failures have a bounded cause. The C extension uses public Ruby APIs; it has no
Magnus/rb-sys runtime dependency that forces the older Ruby cohort. Vendored
Prism 1.9 supports modern Ruby syntax, so no parser upgrade is required merely
to run on Ruby 4.0.

This is not a claim that Rust 1.90 produces the fastest possible build or binary.
Revisit it for an upstream security issue, a dependency/MSRV requirement, or a
measured build/runtime improvement in a separately reviewed change. Keep the
minimum compiler install contract distinct from performance claims.

## Capture parser grammar policy

Capture retains vendored ruby-prism 1.9.0 and its supported `parse()` interface.
Its null options select Prism's latest compatibility mode, currently CRuby 4.1;
a compile-time assertion against the public sys constants makes an alias change
or removal fail the build for explicit review. The direct sys dependency is
exactly pinned and already vendored. This guards the current behavior without
adding unsafe wrappers or modifying vendor checksums. Producer, Ruby coverage,
and syntax diagnostics report the effective policy; producer metadata binds it
into generation identity. Older manifests lacking it remain readable as unknown.

Host CI Ruby 3.4 and 4.0 are separate from source grammar. Compatibility mode
does not prove complete Ruby 4.1 language coverage. Alternative explicit typed
options in maintained Prism 2.1 would require a broader upgrade involving arena,
location, API and eager-error-vector changes; that cost is disproportionate to
this policy fix. An unsafe adapter to 1.9 private options would add ownership and
ABI maintenance risk. The retained guard requires reviewing parser upgrades and
checking upstream default semantics as well as the constants; it is not a runtime
negotiation or a configurable target. Reconsider for security fixes, needed syntax
features, supported explicit options, or a changed upstream default, with fresh
artifact and compatibility evidence.

## Agent session capture: Entire with a private checkpoint repository

Adopt [Entire](https://docs.entire.com/) CLI **0.12.2** to capture Claude Code
and Codex sessions as checkpoints linked to commits. The default `git-refs`
backend pushes checkpoints to `origin`, which is public here. Checkpoints hold
prompts and assistant text; default redaction covers secrets, not PII. The
project setting therefore fails closed with `push_sessions: false`. It still
names the private `lost-in-the/thistle-checkpoints` repository: entire.com reads
checkpoint settings from the default branch. Owner machines opt in to pushing
through the gitignored `.entire/settings.local.json`.

The checkpoint repository name is public by design, a reviewed exception to the
[private-reference rule](agent-configuration.md#public-contracts-and-private-values).
It reveals that a private repository exists, not its contents; GitHub
permissions protect those. Entire reads no environment variable, repository
secret or variable for this setting, so committing the name is the only way
entire.com can locate the checkpoints.

| Considered approach | Decision |
|---|---|
| Pushing off by default; owners opt in locally to a private GitHub repository | Selected: keeps GitHub as the forge, shares context across owner machines and never publishes from a fork or new clone. |
| Committed `checkpoint_remote` only | Rejected: Entire ignores an inherited `checkpoint_remote` when the push target has another owner, so a fork push falls back to the public fork. |
| Entire defaults, checkpoints pushed to `origin` | Rejected: publishes transcripts from a public repository. |
| Entire-hosted (`et/`) repository as `origin` | Rejected: changes the forge; it never forwards pushes to GitHub. |
| Entire's GitHub mirror as `origin` | Not needed: a mirror forwards pushes to GitHub, but every fetch would depend on the `entire://` helper. |
| Local-only checkpoints (`push_sessions: false`) | Rejected: context stays on one machine and hosted search cannot index it. |

Operating cost: every clone installs Entire's Git hooks once, Codex needs hook
approval on each machine, and owners write the local opt-in in every worktree,
including linked worktrees. On an
owner machine, each push to `origin` also pushes outgoing checkpoint refs to the
checkpoint repository. Observed on 2026-10-29, before these settings reached
the default branch: hosted search indexed commits but not sessions from the
separate checkpoint repository. Limitations: a worktree with neither settings
file captures nothing; a branch older than this configuration also lacks the
committed agent hooks, so a local file alone does not capture its agent
sessions. Refs deleted from a public repository may persist in existing clones
or caches.

Reconsider if this repository becomes private, if Entire's hosted index cannot
read the separate checkpoint repository, or if hook latency or failures
measurably slow normal Git use. Setup steps are in
[agent configuration](agent-configuration.md#agent-session-capture-entire).

## Agent context: Entire Brain

Adopt the Entire Brain plugin (**0.4.0**, with entire-graph **0.6.0**) as an
optional, per-machine memory layer. It indexes code, history, documentation and
captured sessions, and distills sessions into recalled facts. `AGENTS.md` points
agents at `.entire/agent-guide.md`, and agents fall back to direct source
inspection when Brain is unavailable. `CLAUDE.md` imports `AGENTS.md`: Brain
setup creates `CLAUDE.md`, and Claude Code skips `AGENTS.md` whenever a
`CLAUDE.md` exists.

| Considered approach | Decision |
|---|---|
| Brain wired into agent instructions; index and memories local; distillation opt-in | Selected: agents use recorded decisions and history without sending sessions anywhere by default. |
| Brain with default backfill and watcher for everyone | Rejected: distillation sends session content to the agent CLI's model provider without an explicit choice. |
| No Brain; checkpoints and `entire why` only | Rejected: context exists but agents are not told to retrieve it. |
| Brain without agent instructions | Rejected: setup reports agents as not wired, and agents rarely query it unprompted. |
| Brain with hosted Brainstore sync | Deferred: sends memories to a hosted service; revisit when cross-machine memory is needed. |

Brain's index and memories stay on the machine. Fact distillation, through the
setup backfill or the watcher, runs the configured agent CLI and so sends session
content to that CLI's model provider. The documented default is therefore
`entire brain setup --no-backfill --no-daemon`; distillation is an explicit
opt-in per machine. The owner's development machines opted in on 2026-10-29.

Operating cost, measured on one macOS machine: the agent guide adds about 1.3k
tokens per session, and the Claude Code pre-edit hook ran in 140 to 270 ms per
edit. When opted in, the backfill distills up to 25 sessions per pass, and the
watcher runs at most one gated distill per 24 hours, both on a low-effort model.
Brain setup does not modify Git hooks.

The pre-edit hook deviates from the generated command: it prefers the managed,
pinned plugin binary, falls back to an `entire-brain` on `PATH`, exits silently
when neither exists, and is bounded by a 5-second timeout. It sets
`ENTIRE_PLUGIN_DATA_DIR` as Entire's plugin dispatcher does, so both binaries
read the same facts. Without a terminal, as in a hook, a bare `entire brain`
call exits 1 when the plugin is missing; interactively, Entire offers to install
it. A setup rerun was
verified to keep this command. Limitations: the hook returns context only, not
`updatedInput`, so its facts cannot change the edit that triggered them; agents
query `entire brain brief` before editing. Memories are per machine without
Brainstore. Brain 0.4.0 generates `.entire/agent-guide.md` describing hybrid
vector search, but its `query` ranks with BM25 only and `--semantic` is a
compatibility alias. Setup regenerates the guide and reverts edits, so it stays
as generated until upstream corrects it; treat query results as lexical.

Reconsider if per-edit latency or session token cost grows materially, if
upstream Brain fixes the missing-plugin exit or the guide's search description,
or if cross-machine memory needs hosted sync.

## Reusable Rails host: one Thistle fixture owner — LOS-139

Own the minimal Rails app, versioned schema/seed/answers and five-command
controller together under `testbed/`, outside shipped gems and runtime
dependencies. Reuse Python stdlib/subprocess, rootless Podman's process/resource
mechanisms, Rails migrations/reflection and Puma/Rack's existing server/request
mechanisms. A Compose/orchestration framework or fork adds configuration,
credential and review ownership without helping the single retained fixture.
See the [operating contract](reusable-rails-host.md) for exact inputs and limits.

The inspected [woods-testbed README at fe29e4f6](https://github.com/lost-in-the/woods-testbed/blob/fe29e4f616fe8eef985b631c26cff9edd5b04182/README.md)
supplies conceptual precedent for per-profile apps and persistent dependency
volumes. Its Rails 6.0/7.2/8.0 variants and Woods extraction/Console do not define
Thistle cohorts. No code was copied; the pinned root LICENSE lookup returned
404, so no license grant is inferred. Importing assets later needs exact
files/adaptations/provenance and license review. Woods Map's Rails engine and
Woods index dependency do not fit Thistle Map's saved Reader/Rack boundary.

A separate maintained testbed repository would require coordinated app/runner
pins, two-repo updates, review and compatibility execution for each fixture or
interface change. Thistle alone owns those updates. The existing
independent-evaluator authority remains separate; a fixture inside the candidate
repository supplies development evidence, not protected qualification.

First prove local retained reuse on the explicitly named public Rails7.1
compatibility profile (Ruby3.4.12/Rails7.1.6/public mysql2 0.5.7/ConnectorC3.4.9/
MySQL8.4.13). This does not change maintained CI policy. Exact image/artifact/
lock/ABI cache identities avoid version-only reuse; missing cached server/client
inputs refuse rather than acquire or rebuild them. Operating cost is one small
app plus a Python lifecycle guard and Ruby known-answer programs; retained
generations/evidence grow per attempt. There is no measured speed or memory
benefit and no fresh-machine/other-platform proof. Reconsider a second repo,
framework or portable archive only for demonstrated independent consumers,
multi-profile lifecycle complexity or an admitted reproducibility requirement.

The R1 correction uses Puma 8.0.2's private Unix listener and maintained host
socat UNIX-CONNECT in the bounded loopback scope. The pinned official binder
and hash-verified Puma archive were inspected by Root: Unix peers initialize as
127.0.0.1; the runtime must still verify the actual peer and Host. Explicit
0700 session directories and 0600 socket/umask077 protect the socket. This
removes a Python/Go/Podman-exec chain per connection; increasing its task/memory
budget would keep unnecessary startup and failure cost. Net::HTTP's response
framing is reused for the internal Unix probe; no generic HTTP/proxy framework
or arbitrary target is added. Four parallel host requests plus assets and actual
resource measurements remain a runtime gate, not a demonstrated speed result.

Custody stops writers before copying, verifies a frozen current-session snapshot,
then removes compute and seals its actual absence receipt. Current artifacts
share indexed bytes rather than copies per attempt; old failed/partial bundles
remain history. Admission hashes the selected source/cohort, while monitoring
samples current-session/cache disk at two-second intervals. These monitored
ceilings are not filesystem quotas. Reconsider only for a measured complete-job
cost, missing upstream API, or separately declared support/retention requirement.

## Maintenance rule

Every tool/version update records upstream maintenance/runtime status, actual
compatibility, CI resource/latency impact and why each retained cohort matters.
Inspect annotations as well as job conclusions. Dependabot proposes ordinary
action and notes-dependency updates; agents still review the release/runtime and
refresh the reviewed pin registry before accepting an action change.

Revisit Ruby/Rails policy when a new stable line appears, a dependency requires
it, or a selected line approaches the end of normal/security maintenance. A new
row needs a concrete supported customer pair or distinct failure risk. A custom
replacement needs measured or contractual benefit that justifies its ownership.
Do not carry a version forward just because a previous baseline used it, and do
not rotate a frozen experiment's inputs in place.

## Issue 41: explicit capture traversal budget

Keep the 1,000,000-node default and allow explicit `max_nodes` up to a provisional
5,000,000 ceiling through Ruby or the capture CLI. Rust validates all limits and
records effective values and visited nodes. Other ceilings remain unchanged. A
named large-app profile was considered; a single explicit limit avoids silently
raising unrelated budgets. The ceiling is an operational policy, not an RSS or
parser safety bound; Prism parsing precedes traversal. Reconsider it with
installed complete-workflow measurements and independent security/performance
review, including cases rejected by downstream budgets. Generated Canopy source
is an interim validation workload, not private-application confirmation.

Publication preflights the existing reader admission estimate before writing.
It builds and drops a search cache, so this adds a traversal and temporary
allocation; the estimate does not cover all retained or transient memory. It
does not reserve space in the shared reader registry. Occupied registries may
still refuse an otherwise admissible snapshot.

## Lexical call targets (issue 43)

The original issue-43 encoding uses the Prism method name as the target, with version 1 receiver
syntax and parser locations in `attributes.thistle_call`. They remain unresolved:
these labels do not identify a runtime object, binding, dispatch target, or call
execution. Implicit, self, and named lexical receivers group repeated calls in a
fact and retain the earliest representative location; opaque receivers and names
omitted at the limit retain separate sites. The producer records
`call_target_schema: 1`. Locations are half-open parser anchors into the captured
file, not a promise that a receiver's location encodes its complete value.

We reuse the pinned Prism parser and existing snapshot schema, validation and
source blobs. Full receiver text as a target drops oversized calls and repeats
source; whitespace normalization can alter literal meaning. A resolver or call
site database would add cost without proving runtime dispatch. This representation
adds metadata and can increase opaque link cardinality; it is not a performance
claim. Reconsider summary grouping if a separately scoped consumer needs all call
sites or binding-aware identities. Old snapshots retain their original targets;
unknown extension versions remain opaque. This changes new target semantics and
does not qualify L07 or provide reverse lookup.

## Borrowed publication ordering (issue 64)

After validation, sort references to the existing facts and serialize the sequence
with the existing serde_json serializer. This keeps the canonical array encoding
and local synchronous ownership while avoiding the owned fact-tree clone used
only for ordering. Retaining that clone is simpler but duplicates nested data;
reconstructing an owned JSON value would do the same. A custom writer or streaming
store adds format and failure-path maintenance without a demonstrated need.

The reference vector has O(n) capacity, stable sorting may use O(n) scratch,
and the original capture and growing serialized byte buffer still coexist.
Serialization grows that buffer before the existing 64 MiB length check rejects
oversized facts; the check bounds accepted output, not peak allocation or buffer
capacity.
On error, local allocations are dropped before return. Reader admission and its
temporary search cache remain separate costs. The 100,000-fact and 64 MiB encoded
limits do not themselves bound total process RSS. Issue 60 attributed at least
209,195,000 bytes (43.03%) of one intercepted heap peak to clone stacks; that is
neither an RSS saving nor a measured improvement. Reconsider the approach if
canonical serializer behavior changes, or controlled complete-workflow evidence
shows a material regression or identifies a better bounded alternative.


## Compact call metadata and explicit snapshot context (issue 70)

Use the existing locked serde_json serializer with a fixed six-slot call tuple,
constructed before capture admission accounting. Snapshot schema 2 explicitly
selects recognition of compact extension v2 and strict legacy v1. Schema 1 keeps
strict v1 and opaque other versions, even when a v2 payload exactly resembles the
compact shape. Every publication/open/Source/Check path carries that context.
New captures select schema 2 and producer call-target schema 2; explicit publish
with no selector stays schema 1, without producer inference or migration. Invalid
selectors fail before filesystem mutation. Readers retain stored compact values
and decode one borrowed view through named fields; no second v1 dataset is built.
Map decodes only displayed links using the manifest context. New Core/Map versions
are paired exactly at 0.1.0.pre.2, so old engines refuse the new snapshot format
instead of silently losing recognized receiver display.

Fixed tuples preserve every flag, name, coordinate and grouping distinction with
uniform arity and explicit null/default values. Defined-default named-field
elision is also lossless under a new contract; it offers readability at the cost
of omission/default rules and less encoded reduction in the issue-69 model.
We chose tuples for uniform validation and the larger demonstrated inert byte
reduction, not because default elision is inherently lossy. Dictionaries, codecs,
custom serializers, broader grouping and source-derived metadata add maintenance
or semantic costs outside this change. No dependency or C-ABI change is needed.
Named borrowed decoding centralizes positions and avoids an owned normalized
fact tree. Capture sorting still compares borrowed call keys; it does not cache
another dataset. Existing source copies and reader search allocations remain.

The single early full retained-workload source check still refused the unchanged
64 MiB capture-evidence budget with the existing 5M node override. There was no
published generation or downstream reader/Map result, and completed totals are
unknown. Smaller records are neither a full-app remedy nor a process-memory or
speed claim. Keep the original failure; subsequent exact-pair checks belong to
the integration owner. Reconsider representation only under a new bounded scope
with complete-job evidence. Limits, separator accounting, source-file copying,
frozen evaluation policy and all launch qualification requirements are unchanged.


## Loaded model observation boundary (issue 73)

Use the supplied application's Rails 8.1.4 reflection and raw schema-cache APIs
for already loaded model descendants. The Ruby boundary observes bounded
framework metadata; Rust normalizes, validates, identifies, admits and stores
it. A textual macro extractor would not establish effective reflection metadata
and would lose through/STI/runtime distinctions; loading targets or evaluating
scopes/default procs would invent execution evidence. Neither is part of this
slice. Names remain labels and runtime/source coherence remains unknown.

The observation is a bounded native-normalized batch. Its request contains only
model observations and current admission counters, never existing source/facts;
Ruby appends the engine's returned records. Actual full-capture validation stays
at native publication, whose existing transport/storage limits still apply. Pool
connection failures are remembered by identity within this capture only,
including lazy primary-key reads; unrelated table errors do not poison a pool.
No persistent application cache, new Cargo dependency or runtime gem dependency
is added. The existing booted SQLite fixture supplies independent schema-known
answers and unsafe-default canaries; it does not qualify every adapter. The
installed runner reuses it outside the checkout with installed production code.

Admission sizing reuses the maintained JSON encoders with counting writers:
serde_json in Rust and a fresh `JSON::State` with an IO sink in Ruby. The
[JSON 2.9.1 state implementation](https://github.com/ruby/json/blob/v2.9.1/lib/json/ext/generator/state.rb)
already accepts that sink. This preserves normal generation defaults and avoids
retaining a second full encoded observation or writing a custom size/escape
encoder. Encoding work and bounded generator buffers remain; no measured memory
or speed improvement is claimed. Recheck this fit if the supported JSON generator
or its streaming behavior changes. Qualification attempts use fresh output
directories so a retry cannot overwrite retained failure receipts.

Reconsider the version allowlist only after checking changed Rails metadata
APIs, and broader semantics/adapter or source-binding claims only with their own
bounded accepted evidence. Callback/execution analysis and generic static macro
extraction are separate customer slices. See the [model contract and sources](loaded-model-evidence.md#library-fit-and-maintenance).


## Evidence search index and matcher

Issue 74 selects one immutable, verified captured-source corpus per Reader and
one first literal match per file. There is no persistent postings format or
writer lifecycle. [Tantivy 0.27](https://docs.rs/tantivy/0.27.0/tantivy/indexer/struct.IndexWriter.html)
provides maintained indexing, but its indexing queues, segments, commits and
merge-thread lifecycle introduce ownership, memory-accounting and offline
packaging work beyond this single-literal, generation-local slice. That is a fit
decision, not evidence that Tantivy is slow or unsuitable for richer retrieval.

For matching, [memchr 2.8.3 memmem](https://docs.rs/memchr/2.8.3/memchr/memmem/index.html)
finds exact byte substrings; it is not a drop-in ASCII-insensitive matcher.
[Aho-Corasick 1.1.5](https://docs.rs/aho-corasick/1.1.5/aho_corasick/struct.AhoCorasickBuilder.html#method.ascii_case_insensitive)
supports the required ASCII-only case folding with original byte offsets. It is
a viable maintained alternative, already transitively vendored, but adopting its
automaton would require an explicit build/memory charge and a bounded scan/work
admission rule. Neither API exposes the current per-comparison stop counter.
The selected small matcher compares original byte windows, folds ASCII only,
and stops within the shared 32 Mi comparison/line-count work allowance. It needs
no folded whole-file copy or query automaton; its worst case is O(text bytes ×
literal bytes), so partial results are an intentional limitation, not a speed
claim. Source verification/cache construction has separate bounded accounting.

The maintenance cost is the custom comparison loop and its Unicode/offset,
work-exhaustion and completeness tests. Retained corpus memory and cold Map
requests remain material costs; no new shared cache or process service is
introduced. Reconsider Aho-Corasick with pre-admitted scan bounds if observed
complete user jobs show comparison exhaustion or search cost is material;
reconsider Tantivy when accepted retrieval requirements justify indexed/ranked
or multi-term search. Preserve honest partial coverage and exact pinned Source
through either change. See the [Find contract and operating budgets](find-evidence.md).

## macOS and Linux source development — 2026-10-29

Issue #81 adds native macOS development alongside Linux and a dedicated Linux
container. Reuse the existing descriptor-relative POSIX implementation and
vendored [errno 0.3.14](https://docs.rs/errno/0.3.14/errno/) for thread-local errno
access. A hand-written cfg/ABI wrapper would duplicate maintained platform code;
the direct dependency adds no new vendored files or allocation on reset. Keep
store ancestors symlink-free, including system aliases; use physical temporary
fixture roots instead of weakening the store trust boundary. Darwin export flags
expose only the Ruby initializer. Linux retains its existing linker policy.

The container combines the Ruby core team's
[Ubuntu-based images](https://github.com/ruby/docker-images) and the maintained
[Rust toolchain image](https://github.com/rust-lang/docker-rust), pinned to
multi-architecture digests. This avoids a custom Ruby compiler/bootstrap installer
and keeps libclang 18 aligned with Ubuntu CI. Upstream describes the Ruby image
service as experimental; exact pins, a runtime policy check and real build/install
checks bound this choice. Reconsider if its patch availability, maintenance or
architectures stop meeting the development policy. OS packages and Ruby dependencies
still resolve at build time, so the image is not claimed reproducible. Update pins
with policy changes and retain tested locks rather than using another application's
image or exposing private host mounts. A copy-based container costs a rebuild for
edits but avoids stale cross-OS objects; native macOS remains the fast local loop.

Use one primary Ruby/Rails cohort on each macOS architecture, not the full
Ruby-by-OS cross-product on every PR. The existing Linux minimum lane remains.
This adds two product jobs and installed source-gem compilations; observe their
hosted cost before broadening the matrix. GitHub documents the
[macos-15 and macos-15-intel runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
Candidate feedback and matching package receipts are not general Unix support,
precompiled distribution or independent launch qualification. Darwin cannot enforce
the existing RLIMIT_AS test bound: retain CPU/wall limits and state that difference
rather than silently treating the Linux memory guard as tested there.

## macOS PR versus main selection — 2026-10-30

[LOS-60](https://linear.app/lost-in-the/issue/LOS-60) records the owner's direction
to move Intel tests to main CI instead of ordinary PRs. This narrowly supersedes
the every-product-PR architecture selection in the 2026-10-29 decision above;
its historical evidence and platform limitations retain their original scope.
Product PRs require Apple Silicon (`macos-15`); main pushes, explicit full/manual
CI and merge groups retain Apple Silicon and Intel (`macos-15-intel`). Docs-only
PRs still skip product work, while docs-only main pushes exercise both.

Reuse the existing event-aware Python planner to emit one runner list and the
native GitHub Actions
[`fromJSON` matrix output](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#fromjson)
to consume it. A native event expression would avoid an output but obscure the
selection from the retained plan and its existing routing tests; a second runner
policy framework would add duplicate authority and maintenance cost. The small
output adds no dependency or extra job. Selected macOS work remains required by
the always-run aggregate, with fail-fast disabled and no failure waiver.
Linux cohorts, product commands, release/qualification support and branch rules
retain their existing policy. Review this selection if owner direction or the
declared development coverage changes. No hosted time saving or launch
qualification is claimed.

## Registered save callback storage boundary — 2026-10-29

The Rails 8.1.4 adapter observes the registered save chain without dispatching a
model's overridable `_save_callbacks` or `__callbacks` accessor. It reads the
private class-attribute value closure only when its MRI instruction-sequence
identity matches a fresh Rails-generated reader on an isolated plain class.
A custom getter or unrecognized VM/layout yields unavailable chain metadata.
Source-location strings are not used as proof that a method is safe to invoke.
Callback registrations and source hints still do not prove execution or coherence.

Use Rails' maintained registry and class-attribute implementation instead of
copying its callback engine or interpreting Ruby bytecode. Textual macro parsing
cannot establish the effective inherited/skipped chain; ordinary getter dispatch
can execute application overrides. The guard costs one temporary probe class per
observer and a method/code identity check per loaded model. It retains no global
model registry and evaluates no callback bodies or conditions. Reconsider this
narrow adapter for a new Rails/Ruby implementation or a maintained nonexecuting
metadata API. Broader Ruby-engine or monkeypatched-framework support is unqualified.


## Explicit installed-document lists — LOS-58

Use the existing RubyGems `spec.files` and `Dir` selectors to distribute deliberate
user/build contracts. Core retains `platforms`, `tagged-call-encoding`,
`loaded-model-evidence`, `callback-evidence`, `find-evidence`, `route-constraints`
and `model-references` under `docs/development/`; Map retains `docs/MODELS.md`
and `docs/REUSE.md`. The Reader/Links/coverage contract added after the LOS-57
research baseline belongs in the installed set. Missing named documents refuse
specification loading rather than silently shrinking the package.

Broad document globs silently admit new administrative material; directory-wide
exclusions would drop useful installed contracts. Git-based selection adds a Git
requirement without deciding audience; Rake FileList or a custom generator adds
machinery the existing selectors do not need. Literal lists need deliberate review
when a new offline contract is added, with a focused disposable selector/link
regression and an actual-manifest assertion on the install helper's already-built
pair. No additional package build or runtime dependency is needed for that assertion.
Existing complete vendor equality checks remain authoritative for vendor bytes.

Keep readmes, changelogs, licenses, third-party notices, all non-document selectors
and the complete vendored tree, including hidden checksums and legitimate
`target`/`docs` source paths. Administrative policy, launch requirements, historical
validation and retired workflow files stay canonical in Git. Repository and
cross-gem links use explicit URLs; same-package contract links stay local.
This narrowly supersedes the earlier choice to ship the inert Experiment 001
workflow as future payload; its repository bytes, selected artifacts, evaluator,
frozen corpus, receipts and original decision remain unchanged.

Whole retained contracts still include dated evidence and can still cause payload
churn. This is a distribution/maintenance boundary, with no measured compression,
capture-byte, timing or RSS benefit and no reproducible-package claim. New package
bytes require their own affected installed evidence; all 17 launch requirements
remain unqualified. Reconsider the lists for a concrete supported offline job,
new public contract, changed upstream build/license requirement, or measured
usability/churn cost that warrants separating mixed user/history documents.

## Reuse captured calls for callback potential effects — LOS-62

Use the maintained Prism producer's existing method descriptors and representative
typed calls, the borrowed `SemanticLinkView` decoder and the Reader/schema's
saved-byte verification. Alternatives were parsing callback macros, reparsing
method bodies, adding an effect graph or observing callbacks by execution. Those
would add parser/graph/lifecycle authority and maintenance while still failing to
prove effective runtime dispatch or source coherence. The selected bounded query
answers one useful operation (`constant.perform_later`) without a dependency,
schema or observer change. Rust owns matching/analysis; Ruby only forwards and
Map renders escaped evidence.

The operating cost is one bounded O(F log C) declaration scan plus O(C²) descriptor
and path grouping, at most 16 manifest scans, one read/validation per selected
source file and two charged visits per admitted link. A 32 MiB aggregate scratch
reservation, 128 KiB output ceiling and explicit unknown/omitted reasons bound
request work without a retained index. See [the exact contract](callback-evidence.md#source-supported-potential-effects-los-62)
for all caps and source/dispatch limitations. No performance/RSS improvement is
claimed. Reconsider only for another independently specified effect form or
observed exact-artifact workload evidence that justifies another bounded
representation; expanding runtime observation or schema needs its own scope.


## Saved callback method positions beyond the all-fact query boundary (LOS-64)

Use a lazy, Reader-owned fixed-key directory of static instance-method fact
positions. The existing open-time indexing pass counts eligible methods/key bytes;
first demand separately reserves actual slot/container capacity from the existing
aggregate admission budget, then explicitly charges complete construction and
in-place std sorting. Exact borrowed labels still resolve digest collisions;
incomplete/unresolved declarations still prevent false unique binding. Publish
only complete directories, retry transient refusal, and release the narrow lock
before source I/O. Each fresh Reader rebuilds and charges its own retention.

The maintained sha2 crate and std Vec/sort primitives already fit this narrow
in-memory need; no new dependency or general indexing framework is justified.
The old bounded scan has the lowest maintenance cost but cannot reach a known
saved method after ordinal 20,050. Existing by-file lookup misses duplicates in
other paths. Raising caps or filtering for free hides work; resumable scans add
uniqueness/session state across short-lived Readers. Fixed digests/positions avoid
retained label/Value copies at the cost of one full construction and O(D) slots
per demanded Reader. Recorded counters/capacities are not RSS or speed evidence.
Reconsider if measured complete open/reopen cost, concurrent retention, or refusal
rates prevent useful customer outcomes. Keep current capture/query/source limits,
strict evidence guards and unknown runtime coherence; all17 remain unqualified.

## Native PR events and bounded takeover/review — LOS-70

Reuse native T3 PR events and the existing skills rather than importing `pr-wait`
or polling; this adds no runtime, dependency or scheduler. The
[pinned adaptations and MIT notice](attribution/tstack.md) record the selected
mechanics and alternatives. The operating cost is maintaining small procedures
against the existing review, signing and delivery gates.

Native PR watch ends on merge/close; the
[post-merge handoff](../../.agents/skills/thistle-hand-off/SKILL.md#pr-watch-ownership)
names the outstanding-check owner and explicitly records any native-event wake
gap without claiming acceptance or blocking disjoint source work. Reconsider
only for concrete tool-contract or workflow changes.

## Selected saved investigations (PR 119)

Use a bounded generation-and-ID focus URL and ordinary Map navigation, with no
new state framework, server collection, notes channel or dependency. The
[investigation contract](../../map/docs/investigations.md#fit-and-maintenance-decision)
records alternatives, repeated-URL/output budgets and maintenance boundaries.
The supporting [Core identity projection](fact-identity.md) uses the Reader's
existing ID index; asking for one relationship would also demand optional
whole-domain name-directory work. Reader open retains its existing validation
and indexing cost. Reconsider the state format only for a changed selection
outcome, rather than bypassing its 24-ID/query ceilings. These bounds are not
whole-request latency/RSS evidence or capability qualification.
