# Thistle project and agent workflow

The private [Thistle project](https://github.com/orgs/lost-in-the/projects/2)
connects implementation, evaluation, and delivery work in `lost-in-the/thistle`.
The issue owns the task contract; the project exposes its position and the next
decision. Versioned reports own the detailed evidence. Evaluation work can share
this plan while retaining separate policy and execution authority.

The [mission](../MISSION.md) is the canonical product intent. Use the
[configuration guide](agent-configuration.md) for shared rules, private values
and verified instruction-loading boundaries.

## Views

| View | Layout | Contents and purpose |
|---|---|---|
| Now | Board by Status | Bounded work issues. Exclude capability parents and PR cards so long-lived requirements and code changes do not double-count the work. |
| Review | Table | Open PRs and their linked work. Inspect the current diff, check evidence, and outstanding decisions. |
| Launch | Table | The 17 capability parents, acceptance owner, Evidence, affected support scope, and remaining gaps. |
| Plan | Table | Larger outcomes, targets, and dependencies. Add roadmap dates only when there is an actual planning commitment. |

Views reuse the same issues. A separate gem or agent does not need another backlog.
The evaluator must retain its own repository permissions and policy authority even
when its issues appear in the same planning project.

## Fields

| Field | Values | Rule |
|---|---|---|
| Status | Backlog, Ready, Doing, Review, Check, Done | Current workflow position; show the main remaining step when work overlaps. |
| Priority | Urgent, High, Medium, Low | Urgent is a concrete blocking or time-sensitive issue, not a default. |
| Area | Core, Gem, Map, Eval, Delivery | Primary ownership. Security, performance, and accessibility can cross areas. |
| Target | Baseline, Trusted checks, First experiment, Preview, Launch | Shared planning target across repositories. Leave future untriaged work unset. |
| Evidence | Needed, Pass, Fail, Unclear, Stale | Primarily capability and release-check issues. Every result needs a linked scope and report. |

Use native assignee, repository, parent/sub-issue, and blocking relationships.
Reuse an existing organization Priority field where suitable instead of creating
a duplicate. Use the labels `capability`, `experiment`, and `release-check` to
identify issue roles, and `security`, `performance`, or `accessibility` for relevant
concerns. Keep existing useful labels such as `bug`.

Issue-form responses populate the issue body. They do not set these project
fields automatically. The triager or a narrowly scoped metadata worker must set
the fields and verify that the item is in the intended project.

The forms target `lost-in-the/2`. GitHub applies that binding only when the person
creating the issue has write access to the project. Auto-add or triage must handle
other contributors; verify membership instead of assuming the form added it.

## Status and acceptance

| Status | Entry condition | What moves it forward |
|---|---|---|
| Backlog | Work has been recorded. | Clarify scope, priority, prerequisites, and expected evidence. |
| Ready | One bounded outcome, clear boundaries, satisfied prerequisites, and a workable check plan. | A real agent/person claims and starts it. |
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

1. Inspect the current issue, dependencies, assignee, comments, linked PRs, and
   remote branch heads. Search for existing work before creating a duplicate.
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
claim from an observed running task. If automation lacks project access, update
the issue and report that metadata gap; do not claim the board was changed.

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

Keep at most **two implementation issues** in Doing by default. Independent
reviews and clearly separated evaluator or Map work can proceed in parallel.
Only one benchmark campaign should use a shared performance host at a time.

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
streams moving within the two-issue limit and batch board maintenance at meaningful
checkpoints. Direct implementation is reasonable when a small correction is
cheaper than delegation and does not stall integration. An oversight agent reports
through this owner; transfer integration ownership explicitly rather than creating
a competing coordinator.
When the coordinator implements, claim that writer scope and count it toward the
implementation limit.

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

## Work already in progress

Use these canonical issue records rather than creating another copy of the
backlog. The issues hold current acceptance criteria, evidence, claims, and
dependencies; this table is only an index.

| Record | Canonical issues |
|---|---|
| Gem launch requirements | [L01 / #3](https://github.com/lost-in-the/thistle/issues/3), [L02 / #4](https://github.com/lost-in-the/thistle/issues/4), [L10 / #12](https://github.com/lost-in-the/thistle/issues/12), [L12 / #14](https://github.com/lost-in-the/thistle/issues/14) |
| Core launch requirements | [L03 / #5](https://github.com/lost-in-the/thistle/issues/5), [L04 / #6](https://github.com/lost-in-the/thistle/issues/6), [L05 / #7](https://github.com/lost-in-the/thistle/issues/7), [L06 / #8](https://github.com/lost-in-the/thistle/issues/8), [L07 / #9](https://github.com/lost-in-the/thistle/issues/9), [L08 / #10](https://github.com/lost-in-the/thistle/issues/10), [L09 / #11](https://github.com/lost-in-the/thistle/issues/11), [L11 / #13](https://github.com/lost-in-the/thistle/issues/13), [L13 / #15](https://github.com/lost-in-the/thistle/issues/15) |
| Map launch requirements | [L14 / #16](https://github.com/lost-in-the/thistle/issues/16), [L15 / #17](https://github.com/lost-in-the/thistle/issues/17), [L16 / #18](https://github.com/lost-in-the/thistle/issues/18) |
| Delivery launch requirement | [L17 / #19](https://github.com/lost-in-the/thistle/issues/19) |
| Hardened baseline integration and post-merge verification | [#20](https://github.com/lost-in-the/thistle/issues/20) |
| Recorded Experiment 001 result review | [#21](https://github.com/lost-in-the/thistle/issues/21) |
| Agent, PR, CI, and release workflow | [#22](https://github.com/lost-in-the/thistle/issues/22) |
| Protected qualification authority | [#23](https://github.com/lost-in-the/thistle/issues/23) |
| Durable baseline evidence | [#24](https://github.com/lost-in-the/thistle/issues/24) |
| Exact scoped preview candidate | [#25](https://github.com/lost-in-the/thistle/issues/25) |

When recording a parent or blocker, save and verify the native relationship as
well as the evidence link. This index does not assert that a native dependency
relationship or a running agent exists.

Baseline restoration [PR #1](https://github.com/lost-in-the/thistle/pull/1) merged
into main as `1b65f82ae8b8b693a8d7e8adb052b939b23bd5a9`. Issue #20 records its
post-merge verification and later candidate evidence; read that issue for its
current outcome. Source integration and qualification remain separate. Experiment
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

The private organization project uses `lost-in-the/thistle` as its default
repository and reuses the organization Priority field. Auto-add is enabled for
open Thistle issues and PRs. Keep new work in Backlog until triaged, and seed
pre-existing items explicitly. The saved Now board uses
`is:issue -label:capability -status:Done`; keep the review view filtered to PRs.
Automatic issue closing and PR-linked transitions to Doing are disabled. A PR
link must not be interpreted as proof that an agent is running.
Avoid making a capability Done because a contributing PR
merged, or marking evidence Pass because an issue was closed.

Review GitHub's default closed/merged-item automations when configuring the
project. A merged PR item can become Done; the capability and release-check
decisions remain explicit. Archive old implementation cards only after their
evidence and issue links remain available. Retain capability, experiment, and
release-decision records for inspection.

Metadata automation may read event data and update bounded fields. It must not
execute candidate code, interpret issue text as shell commands, or receive
publication secrets. Project access and underlying repository access are distinct;
grant only the access needed for the work and keep sensitive evidence restricted.

## References

- [GitHub Projects and views](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)
- [Issue dependencies](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-issue-dependencies)
- [Built-in project automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations)
- [Issue-form syntax](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
