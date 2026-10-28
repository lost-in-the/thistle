# Project setup and verification record

This snapshot records verified setup on **2026-10-28**. It is an operational
record; current issue claims, review decisions, and run identities remain the
authoritative work/evidence records. This snapshot distinguishes completed board
setup from pending workflow adoption and product qualification.

## Project and controls

The private organization [Thistle project](https://github.com/orgs/lost-in-the/projects/2)
is linked to `lost-in-the/thistle`, which is also its default repository.

| Control | Verified state |
|---|---|
| Project visibility | Private |
| Auto-add | Enabled for open issues and PRs from `lost-in-the/thistle` |
| Automatic issue closing | Off |
| PR-linked transition to Doing | Off; a PR link does not prove an agent is active |
| Priority | Existing organization field reused |
| Doing capacity | Saved column limit of two in Now; a visible coordination limit, not a security gate |
| Required-check rules, protected evaluator, release identity | Not established by this setup PR; separate authorized configuration and verification remain necessary |

Field definitions and all 23 issues' Status, Priority, Area and Target values are
saved. All 17 capability parents have Evidence = Needed. Coordination-only tasks
may leave Evidence blank; a blank value never means Pass.

| Field | Values |
|---|---|
| Status | Backlog, Ready, Doing, Review, Check, Done |
| Priority | Urgent, High, Medium, Low |
| Area | Core, Gem, Map, Eval, Delivery |
| Target | Baseline, Trusted checks, First experiment, Preview, Launch |
| Evidence | Needed, Pass, Fail, Unclear, Stale |

## Views

| View | Saved configuration |
|---|---|
| [Now](https://github.com/orgs/lost-in-the/projects/2/views/1) | Board grouped by Status; `is:issue -label:capability -status:Done`; six work issues; Doing limit two. |
| [Review](https://github.com/orgs/lost-in-the/projects/2/views/2) | Flat table; `is:pr is:open`; Title, Assignees, Status, Labels, Reviewers. Existing PR #2 and workflow PR #26 are both in Review. |
| [Launch](https://github.com/orgs/lost-in-the/projects/2/views/3) | Flat table; `label:capability`; 17 parents, each Backlog / Medium / Launch / Needed, with its appropriate Area. Columns: Title, Status, Priority, Area, Target, Evidence, Sub-issues progress. |
| [Plan](https://github.com/orgs/lost-in-the/projects/2/views/4) | Flat table; `is:issue`; grouped by Target, with the same columns as Launch. Baseline 2, Trusted checks 2, First experiment 1, Preview 1, Launch 17. Dates remain unset until commitments are credible. |

Filters and fields were inspected after saving and switching views; Launch was
also independently checked after a full reload. Adding existing PR #2 by its
canonical URL repaired missing membership without creating a duplicate.

## Canonical records

All **23 seed issues** were created and auto-added. The full ID-to-issue index is
in [Work already in progress](agent-workflow.md#work-already-in-progress); keep
criteria and evolving evidence in those issues rather than another backlog file.

| Record | Issue / existing PR |
|---|---|
| Launch requirements L01–L17 | Issues #3–#19 in order: L01 is [#3](https://github.com/lost-in-the/thistle/issues/3), L17 is [#19](https://github.com/lost-in-the/thistle/issues/19). All 17 remain unqualified. |
| Hardened baseline integration | [#20](https://github.com/lost-in-the/thistle/issues/20), Check / Needed after merged [PR #1](https://github.com/lost-in-the/thistle/pull/1); workflow adoption and post-merge verification remain. The primary product lane passed on the workflow candidate. |
| Experiment 001 result review | [#21](https://github.com/lost-in-the/thistle/issues/21), open [PR #2](https://github.com/lost-in-the/thistle/pull/2), now targeting main. The recorded bounded `retain_candidate` result awaits its separate review/integration decision. |
| Agent/PR/CI/release workflow | [#22](https://github.com/lost-in-the/thistle/issues/22), now Review with [PR #26](https://github.com/lost-in-the/thistle/pull/26). |
| Protected qualification authority | [#23](https://github.com/lost-in-the/thistle/issues/23). |
| Durable baseline evidence | [#24](https://github.com/lost-in-the/thistle/issues/24). |
| Exact scoped preview candidate | [#25](https://github.com/lost-in-the/thistle/issues/25). |

Native relationships were saved and independently read back from GitHub:

| Relationship | Verified issue metadata |
|---|---|
| L01 parent #3 | Children #20, #24, #25 |
| L05 parent #7 | Child #21 |
| L17 parent #19 | Child #23 |
| Preview #25 | Blocked by #20, #22, #23, #24 |
| Development links | #21 → PR #2; #22 → PR #26 |

The six work rows are #20 Check, #21 Review, #22 Review, #23 Backlog, #24 Ready,
and #25 Backlog. They are High priority except the Medium-priority preview. Their
Targets are Baseline (#20/#24), Trusted checks (#22/#23), First experiment (#21),
and Preview (#25). Their Areas are Eval (#21/#23) and Delivery (the rest).
No card is asserted to have a running implementation agent at handoff. Parent
closure, dependency satisfaction and qualification still require actual evidence.

## PR and review record

[PR #26](https://github.com/lost-in-the/thistle/pull/26) delivers this workflow on
`agent/development-flow`. The initially verified PR head was
`458778a1de909cda6ac1fa1e1d490222d5e8f2bc`, against main/base
`317671367949111861a63d0c3635dec94533fc8e`. Later board/documentation snapshots may
advance the head; verify the current commit and its checks before integration.

At **14:38:06 UTC**, PR #1 merged and main advanced to
`1b65f82ae8b8b693a8d7e8adb052b939b23bd5a9` (tree
`b403a0706730c946ee0eb25bb222cf705159eef4`). This restored the runtime source and
moved the original handoffs under `docs/handoff/`. PR #26 integrated that main in
`1737e1b6b81eced268dee510f0d4fe284a05983e`, preserving the runtime and resolving
the `AGENTS.md` / `ci.yml` overlap. The first primary product lane passed; the
historical aggregate failed on a cosmetic automation error described below.
Keep #20 open for workflow adoption and its post-merge verification record;
source merge is not launch qualification.

See the [independent review record](review-record.md) for scoped findings,
dispositions, and validation limits. Every code review must follow the
[substantive improvement standard](pr-ci-release.md#review-standard). Consensus
does not turn candidate-owned checks into protected qualification.

## First hosted CI result: bootstrap history

[Run 40707685055](https://github.com/lost-in-the/thistle/actions/runs/40707685055)
completed **successfully** from 14:36:55 to 14:37:18 UTC on 2026-10-28 for initial
flow PR head `458778a1de909cda6ac1fa1e1d490222d5e8f2bc`, before the baseline merge.
Its `ci-plan` artifact records the actual tested
checkout/merge identity; the PR head is not a substitute for that source record.
This result does not cover an untested future revision.

| Hosted job | Observed result |
|---|---|
| Plan checks | Success; 9 seconds; explicit bootstrap scope. |
| Automation contract | Success; 8 seconds; 28 automation regressions passed. |
| Primary product | Intentionally skipped because the tested tree is bootstrap-only. |
| CI / required | Success; 5 seconds; accepted the valid bootstrap route and metadata result. |

The elapsed run was 23 seconds; job durations may overlap and are not summed.
This is an observed first-run result, not a general latency guarantee. Product,
broader compatibility, installed release-candidate, and independently protected
qualification lanes remain **unverified by this run**. No gem was published.

## First source run and correction

[Run 40709002260](https://github.com/lost-in-the/thistle/actions/runs/40709002260)
tested the integrated source revision above. The primary Ruby 3.3.13 / Rails
7.2.4 job passed Rust, Ruby and Map tests, native compilation, package creation,
manifest verification, and upload in **133 seconds**. Its candidate archive is
artifact `12825785699`; the review record retains the archive digest and scope.

The 28 automation tests passed, but `git show --check HEAD` on a shallow checkout
incorrectly scanned inherited source, vendored code and historical evidence.
The required aggregate correctly failed. The correction removes only that
optional cosmetic step; required product and artifact checks remain intact.
The failed attempt is retained. Check the current PR revision and its subsequent
hosted run before acceptance; neither historical run certifies a later revision.

## Recover or maintain the setup

1. Open the existing project and canonical issues before creating replacements.
   Restore missing membership by adding the existing issue/PR; do not duplicate it.
2. Preserve field definitions and per-item values, especially launch Evidence
   and current bounded work. Do not infer Doing from a branch/PR,
   or Pass from an issue closure. Update #22's actual task/branch claim at handoff.
3. Preserve the four saved views and native parent/blocking relationships. Verify
   actual saved metadata when repairing it; written intentions are not a receipt.
4. Preserve the project and issue URLs when recovering configuration. Auto-add
   handles matching new items; explicitly check pre-existing items and PRs.
5. Record new current PR heads and applicable run links in the issue/PR handoff.
   After authorized source/workflow adoption, collect
   real product/main/release-candidate evidence and observed cost separately.

Restoring metadata or workflow files does not recreate protected branch rules,
evaluator authority, credentials, or release approval. Track those controls in
#23 and the applicable release record, with their actual verification evidence.
