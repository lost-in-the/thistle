# Thistle project and agent workflow

The [Thistle Linear project](https://linear.app/lost-in-the/project/thistle-9bc9a3494d6d)
owns active planning, task contracts, priorities, claims, dependencies, and
acceptance tracking. Use the [migration crosswalk and working handoff](https://linear.app/lost-in-the/document/github-linear-migration-and-working-handoff-ccb79f3278cd)
to locate the existing Linear issue before starting or creating work.

GitHub remains the home for source, PRs, reviews, CI, original discussions, and
original evidence. The former GitHub project and imported issue checkpoints are
historical planning records; do not maintain a second active backlog there.
Versioned reports own detailed evidence and retain their original identities.

The PM owns Linear issue bodies, states, priorities, assignments, relationships,
and acceptance tracking. The technical integration owner owns implementation,
technical reviews, integration, signing, resource claims, and PR summaries.
Workers record bounded technical claims and evidence on the assigned Linear issue;
they do not silently take over PM metadata. Leah retains substantive product and
authority decisions. Evaluation work can share the plan while retaining its
separate policy and execution authority.

The [mission](../MISSION.md) is the canonical product intent. Use the
[configuration guide](agent-configuration.md) for shared rules, private values
and verified instruction-loading boundaries.

## Views

| View | Layout | Contents and purpose |
|---|---|---|
| [Now](https://linear.app/lost-in-the/project/thistle-9bc9a3494d6d/view/now-397e64d578dd) | Board by Status | Open bounded work, excluding capability parents. PRs link to their work issue rather than duplicating it as another card. |
| [Review](https://linear.app/lost-in-the/project/thistle-9bc9a3494d6d/view/review-962863cb10ee) | Work awaiting review or checks | Inspect linked PRs, current diffs, exact evidence, and outstanding decisions. |
| [Launch](https://linear.app/lost-in-the/project/thistle-9bc9a3494d6d/view/launch-af8a3de0356b) | Capability view | The 17 capability parents, acceptance owner, Evidence, affected support scope, and remaining gaps. |
| [Plan](https://linear.app/lost-in-the/project/thistle-9bc9a3494d6d/view/plan-7114799aeac7) | List by native milestone | Outcome phases, bounded children, dependencies, and completed history. Add dates only for an actual planning commitment. |

Views reuse the same issues. A separate gem or agent does not need another backlog.
The evaluator must retain its own repository permissions and policy authority even
when its issues appear in the same planning project.

## Fields

| Field | Values | Rule |
|---|---|---|
| Status | Backlog, Ready, Doing, Review, Check, Done | Current workflow position; show the main remaining step when work overlaps. |
| Priority | Urgent, High, Medium, Low | Urgent is a concrete blocking or time-sensitive issue, not a default. |
| Area | Core, Gem, Map, Eval, Delivery | Primary ownership. Security, performance, and accessibility can cross areas. |
| Phase | Capture & read, Explain behavior, Track change, Use & share, Qualify launch | Native project milestone; preferred delivery order with overlap when inputs and ownership permit. |
| Target | Imported historical classifications | Preserve source classification; do not use it as a second current phase or status field. |
| Evidence | Needed, Pass, Fail, Unclear, Stale | Primarily capability and release-check issues. Every result needs a linked scope and report. |

Use native Linear assignee, priority, parent/sub-issue, blocking, and related
relationships. Parent means containment; blocked-by means an actual prerequisite;
related links connect shared interfaces or evidence without preventing work.
Use the labels `capability`, `experiment`, and `release-check` for issue roles,
and `security`, `performance`, or `accessibility` for relevant concerns.

GitHub issue forms remain an intake surface. Their historical project binding
does not make the GitHub board canonical. The PM reconciles intake with an
existing Linear task or creates one bounded task when necessary, sets its fields,
and verifies project membership. Link the Linear task from the technical PR.
Do not duplicate imported issues or infer a claim from an automatically added card.

Phases can overlap; they do not create phase-wide completion gates. Security,
accessibility, resource use, and maintainability apply throughout. Completed
children and milestone percentages do not qualify a launch capability.

## Status and acceptance

| Status | Entry condition | What moves it forward |
|---|---|---|
| Backlog | Work has been recorded. | Clarify scope, priority, prerequisites, and expected evidence. |
| Ready | The Todo queue: one bounded outcome, concrete inputs, clear boundaries, satisfied prerequisites, and a workable check plan. | A real agent/person claims and starts it. |
| Doing | Active task, branch, ownership, and next checkpoint are recorded. | A reviewable change or result exists. |
| Review | A reviewer can inspect the relevant diff/result and its evidence. | Findings are resolved or explicitly dispositioned; remaining checks are clear. |
| Check | Required artifact, integration, evaluation, or acceptance work remains. | The declared acceptance owner records the supported result. |
| Done | This issue's declared outcome and disposition are complete. | Preserve the record; new scope or candidate work gets an explicit follow-up. |

Use a native blocking relationship and a short reason rather than moving every
blocked item out of its stage. Waiting for access or an external decision also
needs an owner and next action. If a task stops, record its last commit, completed
checks, remaining work, and claim status; an abandoned agent must not look active.

An implementation issue is complete when its scoped change and checks are
accepted and integrated as intended. An experiment is complete when the frozen
procedure yields a recorded Keep, Reject, or Unclear disposition. A capability is
qualified only for the exact outcome and support scope covered by accepted
evidence. A release check concerns the exact candidate packages. These decisions
must not be collapsed into one green status.

Completing a component, proposal, or presenter does not establish a working
customer journey. Record which user question the integrated path answers, its
evidence and limits, and the remaining integration or acceptance work.

A valid experiment can be **Done / Reject**. A known failed requirement remains
visible in the capability record. Mark superseded evidence Stale for the current
candidate without modifying the original report. Completing all currently known
sub-issues does not itself qualify their parent.

## Issue structure

Give each issue one primary parent and link other affected capabilities. Keep the
hierarchy to outcome/capability parents and bounded work children initially.
Preserve ledger IDs L01–L17 in capability issues; scope changes require an explicit
product decision and a reviewed ledger update. Add detailed children for the next
target, rather than speculative tasks for every possible implementation.

A Ready issue records:

- Observable outcome and included/excluded scope.
- Relevant contract, capability, source, or baseline identities.
- Acceptance conditions and the smallest meaningful checks that establish them.
- Dependencies and a responsible acceptance owner.
- Expected deliverable: usually a draft PR or an immutable result record.

Use literal titles such as “Keep source pinned when a new generation publishes”
or “Reject snapshots that exceed the depth limit.” Prefer one clear outcome over
an arbitrary line-count target. Split changes when separate acceptance decisions,
owners, or risk boundaries make review easier.

## Claim protocol

1. Inspect the current Linear issue, dependencies, assignee, comments, linked PRs,
   and remote branch heads. Use the migration crosswalk for original GitHub issue
   references and search for existing work before creating a duplicate.
2. Claim one Ready issue. Record the actual agent task URL or provider/task ID,
   branch, base SHA, owned files/interfaces, reviewer/acceptance owner, and next
   checkpoint. If the task has not started, leave the issue Ready.
3. Re-read the issue before editing shared files. Assignment/comments are an
   advisory coordination mechanism, not an atomic lock. Resolve simultaneous
   claims with the integration owner; do not infer exclusivity from a stale card.
4. Work in an isolated worktree and keep changes within the agreed scope. Use
   `codex/<issue>-<short-name>` or an equivalent descriptive branch.
5. Open a draft PR when the first coherent slice is reviewable. Keep its base,
   dependencies, and current task record accurate.
6. Reconcile the current checkpoint on review, handoff, integration, or a change
   to the proposed head/base, dependency, blocker, or acceptance result. Refresh
   the remote state, PR summary, issue next action/claim and project stage together.
   Remove cleared blockers from current summaries while linking
   earlier attempts and evidence unchanged. Record any inaccessible surface;
   include the next action, not a stream of routine command output.

A compact claim/handoff comment is enough:

```markdown
Task: <actual task URL or provider/task identifier>
Branch / base: <branch> / <SHA>
Owns: <files, interfaces, or bounded responsibility>
Acceptance owner: <person or assigned role>
Current result: <what is implemented and checked>
Evidence: <exact run/report links and candidate identity>
Next action: <review, check, dependency, or resumed task>
Claim: active | released | blocked
```

Never invent task links, reviewer approvals, or run results to fill a field. A task
URL identifies work; it does not establish access to its transcript or live state.
When another session is inaccessible, coordinate through the canonical issue, PR,
and remote commits. State the visibility limit and distinguish the last recorded
claim from an observed running task. If Linear access is unavailable, preserve a
bounded technical handoff in the linked PR and report the access gap to the PM.
Do not resume GitHub-board maintenance or claim that Linear was updated.

## Notifications

Treat notifications as prompts to inspect current state. Batch deliveries and
deduplicate by repository/PR, head SHA, review/comment/check identity, and update
time. Read current state once per batch; refresh again before a consequential
action. Reassess substantive updated findings against the current candidate, but
do not replay an old approval or treat an edited bot summary as a new requirement.
Older-head feedback can still apply; reconcile it with the current diff.

Retire a watch when its tracked obligations are complete; retain an explicit
watch for required post-merge checks still outstanding. Do not post a separate
"no action needed" update for stale or duplicate events. Keep one current
checkpoint with decisions and next actions. If notification delivery is outside
the agent's control, suppress duplicate handling within the task; a new
notification service is not a prerequisite for useful product work.

## Multi-agent operation

Keep **two primary outcomes** in focus. This is not an absolute worker or issue
ceiling: named, bounded, genuinely disjoint fixture, review, diagnostic, or
integration work may proceed with explicit file/resource claims without routine
manager approval. Keep that work within the agreed work-in-progress scope.

A shared performance-host claim names the protected measurement window and an
explicit release condition. Block conflicting execution during that window,
rather than reserving the host for the entire PR lifetime. Release the claim
promptly when the window ends; a continuation names only the remaining checks.

Parallelize independent reads and code work; assign one writer to shared mutable
resources, including browser sessions/project configuration, shared files or
worktrees, native interfaces, and benchmark hosts. Separate browser tabs are not
isolated automation sessions. Explicitly coordinate and release UI ownership
before another agent acts, and prefer a capable API for atomic changes when
available.

Choose an integration owner for any parent outcome with concurrent children.
That owner records interface decisions, shared-file ownership, and integration
order. Other agents may review shared code read-only. Changes to contracts,
fixtures, FFI ownership, public schemas, or workflow names should be agreed before
parallel implementation depends on them.

Keep the coordinator focused on dependency decisions, review and acceptance
routing, and authorized integration. Delegate implementation, evidence collection,
and administrative execution to bounded, capable, named owners without transferring
credentials or expanding their authority. Keep ready implementation
streams moving within the agreed work-in-progress scope and batch board
maintenance at meaningful checkpoints. Direct implementation is reasonable when
a small correction is cheaper than delegation and does not stall integration. An
oversight agent reports through this owner; transfer integration ownership
explicitly rather than creating a competing coordinator.
When the coordinator implements, claim that writer scope and include it in the
agreed work-in-progress scope.

Each agent uses its own branch/worktree. Do not have agents concurrently edit one
working directory or push to one branch. Stack PRs only for a real dependency;
record the base PR/commit, then rebase or update the dependent branch after its
prerequisite lands and run the affected integration checks again. For every
blocker, name the exact prerequisite and the step it prevents. An integration
preference is not a technical dependency: continue independent implementation
and review while a separate qualification, infrastructure or owner decision is
pending. Avoid a permanent integration branch that accumulates unreviewed work.

Reviewer agents can examine architecture, security, or Map behavior independently.
Reviewers should identify concrete findings, severity, evidence, and disposition.
Consensus is useful, but cannot waive missing checks or substitute for an
independently controlled evaluator. An agent using the author's privileges does
not become a separate authority by using a different task name.

After corrections settle, the integration owner names the proposed head and
identifies changes since the last reviewed and tested commits. Obtain a scoped
review disposition for material corrections, then run the affected required
checks. Schedule expensive installed checks against that settled candidate;
changed package bytes cannot inherit earlier installed acceptance. Earlier reviews
and package results keep their original identities. A wording or fragment correction
does not automatically justify a full review or benchmark campaign; follow the
existing change routing and required gates. New changes reopen only the affected
review/check scope, without transferring old acceptance to changed bytes.

## Routine validation within a claim

When delegating ordinary implementation, include the focused harmless checks
needed for a reviewable handoff in the initial file/resource claim. State the
runtime and elapsed-time budget, permitted tools and inputs, protected-host
conflicts, and release condition. A source-only handoff is appropriate when a
real shared interface or resource prevents useful execution; record that exact
prerequisite and its next owner.

Within that authorization and budget, a worker may correct a deterministic
preflight or wrapper setup error and resume the affected harmless checks without
a new routine manager turn. Preserve each failed attempt and report whether the
test child actually started. A preflight failure is neither a test pass nor
evidence that the tested behavior failed. Stop when the budget, input/tool scope,
or ownership boundary is exceeded; do not retry unchanged commands indefinitely.

An explicit source-only grant, per-attempt limit, frozen procedure, protected
measurement window, or private-data boundary remains binding until its owner
changes it. This routine-validation rule does not authorize another fixed
full-workload attempt, a benchmark campaign, new credentials/dependencies,
external transmission, security changes, or publication. Do not reinterpret an
existing one-shot grant; define ordinary validation scopes to include bounded
setup repair when issuing or revising them.

## Stateful verification

Before an administrative proof or another stateful verification workflow, inspect the
current lifecycle and API preconditions of reused resources before allocating
temporary resources. Check whether a PR is open, which refs actually exist, the
current target/settings, and whether the intended transition is supported. Reuse
an existing applicable procedure; correct a known setup error before retrying.
Verify the intended API semantics against current primary documentation. Isolate
each control so unrelated pending checks cannot explain its result. Compare
effective settings semantically, accounting for documented service defaults;
do not discard an unexplained difference to make a restoration check pass.

For each control, name the exact disposable target, expected observable result,
possible successful side effects, and authorized containment/recovery. An expected
refusal can succeed, so its successful effects must also fit the authorized scope.
Read back actual state after the attempt. A generic refusal for the wrong reason,
a setup failure, or a check still settling does not prove the intended control.

Measurement wrappers must propagate the workload's exit status even when logging,
artifact collection, or cleanup succeeds. Stateful proof scripts must check each
operation and observed result, with explicit transitions that prevent dependent
mutations after a failed or ambiguous control. For a new or changed wrapper or
proof procedure, exercise failure propagation with harmless stubs before an
expensive run or settings mutation. Use a small check at this boundary, not another
orchestration framework: verify success, failure, and that dependent work does not
run after failure. Reuse this evidence while the execution contract is unchanged;
preserve the original failure alongside cleanup results.

Unexpected success or ambiguous effects stop the affected proof. Preserve the
command/result and identities, perform only authorized containment/cleanup, and
record the failed or inconclusive outcome rather than changing the expected
result afterward.
Revise the procedure and disposition the failure before another attempt or
promotion. Resume only the affected checks whose preconditions or evidence
changed, within the existing authorization; keep unrelated product work moving.

## Improve the cause at the right layer

Choose the smallest durable repair for the demonstrated cause:

- Clarify the canonical rule when ambiguity caused the failure; link it instead
  of adding competing instructions.
- Use a reusable procedure or skill when recurring judgment benefits from one.
  Do not create a skill for every incident or use instructions to mask a code defect.
- Add an executable guard at the lowest useful boundary for a deterministic
  failure, reusing the [stateful verification procedure](#stateful-verification)
  where applicable.
- Make a bounded, behavior-preserving structural fix when recurring workarounds
  cost more than repairing the design. Avoid aesthetic rewrites.

An investigation needs a concrete question and a stopping condition. Choose the
repair by expected benefit and ongoing cost, not instruction or agent count.
Apply the [existing review standard](pr-ci-release.md#review-standard); this adds
no approval layer. Record deliberate tradeoffs with scope, consequences,
evidence and conditions for reconsideration. A temporary compromise also needs
an owner and an exit condition. Neither silently qualifies a launch requirement.
Record tooling alternatives and decisions in the [development decisions](decisions.md).

## Current work and original evidence

Use the [Linear project](https://linear.app/lost-in-the/project/thistle-9bc9a3494d6d)
and [migration crosswalk](https://linear.app/lost-in-the/document/github-linear-migration-and-working-handoff-ccb79f3278cd)
for current acceptance criteria, claims, dependencies, and next actions. This
stable capability index does not duplicate the live work queue.

| Record | Canonical Linear parents |
|---|---|
| Gem launch requirements | [L01 / LOS-5](https://linear.app/lost-in-the/issue/LOS-5), [L02 / LOS-6](https://linear.app/lost-in-the/issue/LOS-6), [L10 / LOS-14](https://linear.app/lost-in-the/issue/LOS-14), [L12 / LOS-16](https://linear.app/lost-in-the/issue/LOS-16) |
| Core launch requirements | [L03 / LOS-7](https://linear.app/lost-in-the/issue/LOS-7), [L04 / LOS-8](https://linear.app/lost-in-the/issue/LOS-8), [L05 / LOS-9](https://linear.app/lost-in-the/issue/LOS-9), [L06 / LOS-10](https://linear.app/lost-in-the/issue/LOS-10), [L07 / LOS-11](https://linear.app/lost-in-the/issue/LOS-11), [L08 / LOS-12](https://linear.app/lost-in-the/issue/LOS-12), [L09 / LOS-13](https://linear.app/lost-in-the/issue/LOS-13), [L11 / LOS-15](https://linear.app/lost-in-the/issue/LOS-15), [L13 / LOS-17](https://linear.app/lost-in-the/issue/LOS-17) |
| Map launch requirements | [L14 / LOS-18](https://linear.app/lost-in-the/issue/LOS-18), [L15 / LOS-19](https://linear.app/lost-in-the/issue/LOS-19), [L16 / LOS-20](https://linear.app/lost-in-the/issue/LOS-20) |
| Delivery launch requirement | [L17 / LOS-21](https://linear.app/lost-in-the/issue/LOS-21) |
| Qualification authority and scoped preview | [LOS-25](https://linear.app/lost-in-the/issue/LOS-25), [LOS-27](https://linear.app/lost-in-the/issue/LOS-27) |

When recording a parent or blocker, the PM saves and verifies the native
relationship as well as the evidence link. This index does not assert a running
agent, current status, or qualification. Original GitHub #references below remain
historical evidence; use the crosswalk for their active planning records.

Baseline restoration [PR #1](https://github.com/lost-in-the/thistle/pull/1) merged
into main as `1b65f82ae8b8b693a8d7e8adb052b939b23bd5a9`. Issue #20 retains its
historical post-merge and candidate evidence; use mapped
[LOS-22](https://linear.app/lost-in-the/issue/LOS-22) for current planning and
acceptance. Source integration and qualification remain separate. Experiment
[PR #2](https://github.com/lost-in-the/thistle/pull/2) merged as
`b3a2985af3388ac4bc784bccf57d89e0ea569358`, after workflow PR #26 merged as
`ee247b0017e11dd9f20380e36d13fe8e2645f561`. Issues #21 and #22 completed adoption;
#28 records the resulting automation reconciliation. This paragraph is historical
provenance, not a list of unfinished tasks; read current issue status and head
commits before claiming work.

The restored main tree records a bounded accepted baseline and self-inspection
in `docs/handoff/BASELINE_ACCEPTANCE.md`; integrated source contains the
implementation and a recorded
[`retain_candidate` result](https://github.com/lost-in-the/thistle/blob/7ce504a9abff606370b5f55973ba7bd414fa4a0e/docs/handoff/experiment-001/RESULTS.md)
with its original artifact/environment scope. The completed one-off orchestration
is [retired from active Actions](retired-workflows/README.md). Preserve integrated
restoration work and historical evidence; do not replay a completed campaign.

The selected baseline and later repackages can have different package hashes even
when payload/native bytes match. Preserve the selected experiment artifact until
the evaluator owner explicitly changes that selection. A workflow success badge
does not establish that the optimization was retained; inspect its recorded
decision. All launch rows still require their broader acceptance evidence.

## Project automation

Linear is the active workboard. Keep new intake in Backlog until triaged and
promote only bounded work with satisfied prerequisites to Ready. A linked PR or
an assignee field alone does not prove that a worker is running. The Now view
excludes broad capability parents; Review links to the same work and evidence.

A linked PR merge moves its work toward Check; the PM records scoped acceptance
before Done. Keep parent/sub-issue auto-close and stale-issue auto-close disabled.
Completed children do not close capability parents automatically. Preserve old
attempts and accepted evidence, and retire completed watches promptly.

The former GitHub Project 2 configuration is historical. Do not add or reconcile
cards there as part of routine development. GitHub remains authoritative for
code, PR state, review, CI, and its original evidence.

Metadata automation may read event data and update bounded fields. It must not
execute candidate code, interpret issue text as shell commands, or receive
publication secrets. Project and repository access remain distinct; use only
the existing access needed for the work and keep sensitive evidence restricted.

## References

- [Canonical Linear project](https://linear.app/lost-in-the/project/thistle-9bc9a3494d6d)
- [Migration receipt, crosswalk, and working handoff](https://linear.app/lost-in-the/document/github-linear-migration-and-working-handoff-ccb79f3278cd)
- [PR, CI, and release flow](pr-ci-release.md)
