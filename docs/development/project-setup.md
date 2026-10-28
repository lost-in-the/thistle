# Project setup and verification record

This snapshot records verified setup on **2026-10-28**. It is an operational
record; current issue claims, review decisions, and run identities remain the
authoritative work/evidence records. Pending work below is not asserted complete.

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
| Required-check rules, protected evaluator, release identity | Not established by this setup PR; separate authorized configuration and verification remain necessary |

Field definitions are configured. **Per-item field population is still in
progress** in this snapshot; a field's existence does not prove every issue has
been assigned its intended values.

| Field | Values |
|---|---|
| Status | Backlog, Ready, Doing, Review, Check, Done |
| Priority | Urgent, High, Medium, Low |
| Area | Core, Gem, Map, Eval, Delivery |
| Target | Baseline, Trusted checks, First experiment, Preview, Launch |
| Evidence | Needed, Pass, Fail, Unclear, Stale |

## Views

| View | Verified availability and remaining work |
|---|---|
| [Now](https://github.com/orgs/lost-in-the/projects/2/views/1) | Saved board, grouped by Status; filter `is:issue -label:capability -status:Done`. |
| [Review](https://github.com/orgs/lost-in-the/projects/2/views/2) | Saved view; verify its final filters/visible fields with the completed board snapshot. |
| [Launch](https://github.com/orgs/lost-in-the/projects/2/views/3) | View exists; launch field population/configuration is in progress. |
| Plan | Planned; not created or verified in this snapshot. Add roadmap dates only for credible commitments. |

## Canonical records

All **23 seed issues** were created and auto-added. The full ID-to-issue index is
in [Work already in progress](agent-workflow.md#work-already-in-progress); keep
criteria and evolving evidence in those issues rather than another backlog file.

| Record | Issue / existing PR |
|---|---|
| Launch requirements L01–L17 | Issues #3–#19 in order: L01 is [#3](https://github.com/lost-in-the/thistle/issues/3), L17 is [#19](https://github.com/lost-in-the/thistle/issues/19). All 17 remain unqualified. |
| Hardened baseline integration | [#20](https://github.com/lost-in-the/thistle/issues/20), Check / Needed after merged [PR #1](https://github.com/lost-in-the/thistle/pull/1); reconciliation and the new primary product lane remain to be verified. |
| Experiment 001 result review | [#21](https://github.com/lost-in-the/thistle/issues/21), open [PR #2](https://github.com/lost-in-the/thistle/pull/2), now targeting main. The recorded bounded `retain_candidate` result awaits its separate review/integration decision. |
| Agent/PR/CI/release workflow | [#22](https://github.com/lost-in-the/thistle/issues/22), now Review with [PR #26](https://github.com/lost-in-the/thistle/pull/26). |
| Protected qualification authority | [#23](https://github.com/lost-in-the/thistle/issues/23). |
| Durable baseline evidence | [#24](https://github.com/lost-in-the/thistle/issues/24). |
| Exact scoped preview candidate | [#25](https://github.com/lost-in-the/thistle/issues/25). |

Native parent/sub-issue and blocking relationships are **not yet verified as
complete**. The seed's intended relationships and links do not establish that
GitHub saved them. Verify the actual issue metadata before treating a dependency
as satisfied or a card as ready for an agent.

## PR and review record

[PR #26](https://github.com/lost-in-the/thistle/pull/26) delivers this workflow on
`agent/development-flow`. The initially verified PR head was
`458778a1de909cda6ac1fa1e1d490222d5e8f2bc`, against main/base
`317671367949111861a63d0c3635dec94533fc8e`. Later board/documentation snapshots may
advance the head; verify the current commit and its checks before integration.

At **14:38:06 UTC**, PR #1 merged and main advanced to
`1b65f82ae8b8b693a8d7e8adb052b939b23bd5a9` (tree
`b403a0706730c946ee0eb25bb222cf705159eef4`). This restored the runtime source and
moved the original handoffs under `docs/handoff/`. PR #26 now needs main integrated
and its `AGENTS.md` / `ci.yml` overlap resolved while preserving that runtime.
**This integration and its product checks are pending in this snapshot.** Keep
#20 open for the post-merge verification record; source merge is not qualification.

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

## Complete or recover the setup

1. Open the existing project and canonical issues before creating replacements.
   Restore missing membership by adding the existing issue/PR; do not duplicate it.
2. Verify field definitions and finish per-item values, starting with the launch
   Evidence state and current bounded work. Do not infer Doing from a branch/PR,
   or Pass from an issue closure. Update #22's actual task/branch claim at handoff.
3. Finish and inspect Launch, create Plan, and verify saved filters and visible
   fields. Save actual parent/blocking relationships and inspect them after saving.
4. Preserve the project and issue URLs when recovering configuration. Auto-add
   handles matching new items; explicitly check pre-existing items and PRs.
5. Update this snapshot with the verified final board state, current PR head,
   and applicable run links. After authorized source/workflow adoption, collect
   real product/main/release-candidate evidence and observed cost separately.

Restoring metadata or workflow files does not recreate protected branch rules,
evaluator authority, credentials, or release approval. Track those controls in
#23 and the applicable release record, with their actual verification evidence.
