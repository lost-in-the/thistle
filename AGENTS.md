# Thistle agent guidance

Use one bounded issue, an isolated branch/worktree, and a reviewable PR for each
implementation task. The current owner request and actual repository state take
precedence over dated handoff snapshots.

## Read before work

1. Read the assigned issue, its dependencies, active claims, linked PRs, and the
   current branch/base commits. Check whether another agent already owns the work.
2. Read [the project and agent workflow](docs/development/agent-workflow.md) and
   [the PR, CI, and release flow](docs/development/pr-ci-release.md).
3. Read the current README, applicable implementation contract, capability-ledger
   rows, and experiment policy. Restored source uses `docs/handoff/CODEX_HANDOFF.md`,
   `docs/handoff/IMPLEMENTATION.md`, `docs/handoff/EVALUATOR_HANDOFF.md`, and
   `docs/handoff/ARCHITECTURE_PLAN.md`. Check `docs/handoff/RESTORATION.md` and
   `docs/handoff/BASELINE_ACCEPTANCE.md` for newer evidence and dispositions.
   Only an older bootstrap checkout keeps those four handoff files at the root;
   use the paths present in the actual checkout rather than restoring old copies.

Baseline restoration landed in main through PR #1. Review its integrated source
and current issue #20 checks before claiming more restoration work. Experiment
PR #2 remains separately reviewable against main. Check current PR/branch state;
do not start another import or benchmark because an old handoff says it has not
happened.

## Product constraints

- Rust owns the core; Ruby supplies the gem/Rails boundary and the C extension
  bridges them. Preserve exact ownership across the native boundary.
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
- Keep at most two implementation issues active by default. Parallelize bounded
  work and independent reviews; serialize noisy benchmarks on shared hardware.
- Open a draft PR when a coherent change is reviewable. Run the smallest checks
  that resolve the change's risk, followed by the required affected CI lanes.
  Broaden testing for a concrete risk or declared gate, not to repeat evidence.
- Update the issue at meaningful transitions or a blocker. Record what actually
  ran, exact identities and evidence links, remaining limits, and the next action.
- Hand back in Review or Check when acceptance is outstanding. Resolve concrete
  findings; preserve unresolved findings and their dispositions. Reconcile other
  agents' changes instead of overwriting or force-pushing them.

## Review for lasting quality

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

Prepare and review changes autonomously within the assigned scope. Merging,
publishing, new credentials, and security-sensitive permission changes require
the applicable owner authorization; existing session authorization still applies.
