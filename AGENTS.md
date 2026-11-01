# Thistle agent guidance

Use one bounded issue, an isolated branch/worktree, and a reviewable PR for each
implementation task. The current owner request and actual repository state take
precedence over dated handoff snapshots.

Follow the canonical [mission](docs/MISSION.md) and the
[public/private configuration boundary](docs/development/agent-configuration.md#public-contracts-and-private-values).
Read applicable policy explicitly; a link does not establish runtime autoloading.

For reusable assignments, use the [agent team](docs/development/agent-team.md):
five role prompts and shared Plan, Build, Review, Check, and Hand off procedures.
Assign the role and load the needed skill explicitly. The existing workflow owns
authority; the team pack adds no approval stage or automatic host/provider access.

## Read before work

1. Read the assigned issue, its dependencies, active claims, linked PRs, and the
   current branch/base commits. Check whether another agent already owns the work.
2. Read the mission and configuration boundary above, the assigned role/skill,
   and the workflow's [claim protocol](docs/development/agent-workflow.md#claim-protocol)
   and [status/acceptance rules](docs/development/agent-workflow.md#status-and-acceptance).
3. Use the routing below for relevant sections of the current README, contracts,
   and policies. Role/skill references to a policy follow this same routing;
   they do not require reading every section or historical handoff on every task.

| Task | Additional reading before the affected action |
| --- | --- |
| Scope or product planning | [Project scope index](docs/PROJECT_SCOPE.md), affected [ledger rows](docs/capability-ledger.md), current Linear task and dependencies. |
| Implementation | README's affected interface, the changed boundary's contract under `docs/development/` or `map/docs/`, [PR flow](docs/development/pr-ci-release.md#pr-flow) and [affected CI lanes](docs/development/pr-ci-release.md#ci-execution-model). |
| Review or QA | Assigned contract, [review standard](docs/development/pr-ci-release.md#review-standard), and [artifact policy](docs/development/pr-ci-release.md#artifact-reuse-and-evidence) when inspecting package/qualification claims. |
| Delegation, handoff or stateful verification | Applicable [workflow sections](docs/development/agent-workflow.md#multi-agent-operation) and [team procedure](docs/development/agent-team.md); verify execution controls before launch. |
| Signing, provider setup, hooks or private evidence | Relevant [configuration sections](docs/development/agent-configuration.md) and existing authority before access or mutation. |
| Release or evaluation | Applicable [qualification](docs/development/pr-ci-release.md#independent-qualification-contract), [release](docs/development/pr-ci-release.md#release-flow) or [experiment policy](docs/experiment-001.md), plus the exact candidate's retained evidence. |
| Restoration or historical experiment investigation | [Historical sources](docs/PROJECT_SCOPE.md#historical-design-and-evidence); inspect newer dispositions before acting on an old next step. |

Baseline restoration and Experiment 001 landed through PRs #1 and #2; the current
CI flow landed through PR #26. Review integrated source and issue #20 checks
before claiming more restoration work. The completed experiment workflow is
retired from active Actions; its provenance is in
`docs/development/retired-workflows/README.md`. Check current PR/branch state;
do not start another import or benchmark because an old handoff says it has not
happened.

## Product constraints

- Rust owns the core; Ruby supplies the gem/Rails boundary and the C extension
  bridges them. Thin Ruby means bounded responsibilities, not shallow Rails
  knowledge: it may faithfully observe substantial Rails semantics while Rust
  remains the engine owner. Preserve exact ownership across the native boundary.
- Reimplement the engine without Woods engine code. The owner permits Woods Map
  and branding reuse with provenance and license attribution. Legacy interfaces
  need not be preserved; useful customer outcomes must at least match for launch.
- Console, a REPL, and arbitrary evaluation endpoints are outside scope.
- Keep Find, Source, Links, and Check recognizable. Preserve optional home-row
  shortcuts, text/IME input, keyboard focus, explicit uncertainty, and no-JavaScript
  paths. Do not infer that read-only UI needs no access control.
- Preserve all 17 launch requirements until their declared outcomes and support
  scope have accepted evidence. A working slice does not qualify the ledger.

## Claim, implement, and hand back

- Select Ready work whose prerequisites are satisfied. Record the actual agent
  task URL or provider/task identifier, branch, base SHA, owned files/interfaces,
  acceptance owner, and next checkpoint in the issue. A prepared prompt or branch
  does not prove a task is running.
- Use a dedicated worktree. Start from the agreed base and avoid unrelated edits.
  Coordinate shared files before writing; one agent integrates overlapping work.
- Parallelize independent reads and code work, with one explicit writer for each
  shared mutable resource: browser sessions/project settings, files/worktrees,
  native interfaces, and benchmark hosts. Separate browser tabs share automation
  state. Coordinate and release UI ownership before another agent acts; prefer
  a capable API for atomic changes when available.
- Focus on two primary outcomes. Allow named, bounded, genuinely disjoint work
  with explicit file/resource claims under the
  [multi-agent workflow](docs/development/agent-workflow.md#multi-agent-operation).
  Protect measurement windows and release host claims promptly.
- Open a draft PR when a coherent change is reviewable. Run the smallest checks
  that resolve the change's risk, followed by the required affected CI lanes.
  Broaden testing for a concrete risk or declared gate, not to repeat evidence.
- At review, handoff, integration, or a change to the proposed head/base,
  dependency, blocker, or acceptance result, reconcile the PR's current summary,
  issue next action/claim, and project stage against current remote state.
  Remove cleared blockers from current summaries; preserve dated attempts and
  their evidence identities. Record a specific access gap when reconciliation
  cannot be completed; avoid command-by-command status comments.
- Batch and deduplicate notifications before acting. Check current state, retire
  watches whose obligations are complete, and suppress stale-event updates.
  Keep the coordinator focused on integration; delegate bounded implementation,
  evidence collection, and administrative execution to named owners.
- Hand back in Review or Check when acceptance is outstanding. Resolve concrete
  findings; preserve unresolved findings and their dispositions. Reconcile other
  agents' changes instead of overwriting or force-pushing them.

## Review for lasting quality

Verify human and automated findings against the current code, user outcome, and
threat model. Fix demonstrated defects; explain inapplicable findings or bounded
follow-ups. A severity label or suggested remedy alone does not establish a new
requirement or justify more infrastructure.

Every code review must actively seek substantive improvements. Functional
correctness is necessary, but insufficient. Flag avoidable work, non-performant
algorithms or allocations, fragile ownership, unclear design, and haphazard
implementations. Consider long-term and downstream consequences even for small
changes. Apply the [review standard](docs/development/pr-ci-release.md#review-standard).

Review the relevant complexity, memory/allocation, FFI, lifecycle, cache
invalidation, concurrency, error-path, packaging, and maintenance costs. Require
measured evidence and explicit budgets for material performance claims; do not
invent a speed result or substitute a microbenchmark for a complete user job.
State improvement findings and their consequences, or explain why no material
issue was found in the reviewed scope. Resolve blockers before acceptance; link
bounded follow-ups for useful improvements that do not block the current outcome.

Keep tests efficient and purposeful. Use targeted, reasonably sized PR checks,
broader main-branch checks, and thorough release qualification. Prefer a focused
regression at the lowest meaningful boundary; avoid duplicated assertions, noisy
timing gates, and broad reruns without a concrete risk or required gate.

## Choose tools and versions deliberately

Evaluate maintained existing tools before writing a replacement. Reuse needs a
current fit assessment, not just precedent; custom code needs a concrete benefit
that outweighs its ongoing maintenance and test cost. Record the alternatives,
decision, operating cost, limitations and conditions for reconsideration in
[the development decisions](docs/development/decisions.md). Greenfield choices
must reflect the intended product and current upstream support.

Use `.github/ci-policy.json` for routine Ruby/Rails cohorts. Historical accepted
packages and frozen experiments keep their recorded environment; their versions
do not become the development default automatically. Inspect deprecation and
security annotations as well as pass/fail results. Verify action release,
declared runtime and runner compatibility before updating full-SHA pins; a
known repository and a green check alone are insufficient maintenance evidence.

Add a unique [changelog fragment](docs/development/changelog.md) for each
noteworthy change in the affected package. Ordinary parallel PRs do not edit
shared `CHANGELOG.md` files. One release-preparation owner consolidates notes
with the pinned Towncrier tool; note preparation does not authorize publication.

## Checks and experiments

Candidate CI is development feedback. A separately versioned evaluator is useful,
but a second directory, agent, or workflow sharing candidate authority does not
establish protected independence. Missing, cancelled, timed-out, failed, or
inconclusive required evidence cannot pass qualification.

Reuse accepted evidence only for its exact artifact/support tuple. For changed
packages, run the current installed contracts, native/parser and reader-boundary
regressions, and the relevant Map integration/smoke checks. Preserve earlier
attempts; record new candidate evidence rather than relabeling an old report.

Experiment 001 uses the accepted installed gem to inspect its own packaged source.
Preserve its selected baseline, frozen policy, primary complete-session metric,
semantic equality, memory guardrails, A/A calibration, attempt history, and scope.
Review the existing experiment branch and its recorded verdict before running
another campaign. A completed experiment can reject the optimization.

## Authority and delivery

Board status is an index to decisions and reports, not a release authorization.
Task completion, experiment disposition, capability qualification, and publication
are separate decisions. The authoring agent cannot independently accept its own
qualification claim.

Run candidate build/install code without release or evaluator-policy credentials.
Keep metadata automation separate from candidate execution. Do not execute
untrusted PR code in a privileged workflow, weaken required gates, change frozen
policy to obtain a pass, or promote an unqualified cache/artifact into publishing.

For administrative proofs and other stateful verification workflows, follow the
[lifecycle and failure procedure](docs/development/agent-workflow.md#stateful-verification).
An expected refusal is still a mutation attempt; verify its actual effects.
Enforce subprocess failure propagation and dependent mutation stops in executable
code; prose instructions do not establish those properties.

Prepare and review changes autonomously within the assigned scope. Merging,
publishing, new credentials, and security-sensitive permission changes require
the applicable owner authorization; existing session authorization still applies.

<!-- entire-agent:begin -->
Read .entire/agent-guide.md for this repository's workflow, source inspection, and verification guidance.
@.entire/agent-guide.md
<!-- entire-agent:end -->
