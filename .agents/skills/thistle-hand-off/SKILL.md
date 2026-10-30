---
name: thistle-hand-off
description: Hand off, resume or close a bounded Thistle task with current ownership and exact evidence. Use when a candidate, blocker, dependency, acceptance result or responsible worker changes.
---

# Hand off

Use the [existing claim/checkpoint format](../../../docs/development/agent-workflow.md#claim-protocol)
and the assigned role. Keep one current checkpoint with historical receipts linked.

1. Reconcile the current issue, PR state/head/base, checks, reviews, evidence
   identities and retained findings once per event batch. Deduplicate by task/PR,
   candidate, event identity and update time. Keep applicable older-head findings;
   a new push does not dismiss them. Refresh before a consequential action.
2. State the customer-visible change or supported result first. Identify source,
   package, installed and qualification evidence separately. Preserve original
   identities and failed attempts; remove cleared blockers from the current summary.
3. Name the actual task/provider identity, branch/base/candidate, owned resources,
   acceptance owner, remaining action and claim state. Never describe a prepared
   prompt or idle branch as a running worker.
4. The technical owner updates the PR's technical summary. The PM reconciles Linear
   planning/acceptance. Workers hand back bounded evidence; they do not take over
   planning metadata.
5. Release file and host claims after actual child completion/cancellation. A wait
   timeout is not cancellation. Transfer unfinished ownership explicitly and avoid
   re-running already completed work on restart.
6. If a repeated workflow defect was observed, link one bounded improvement to the
   canonical rule, skill or script. Prefer fixing executable failure handling over
   adding repetitive prose. Keep host/account/private values local.

## PR watch ownership

One named owning thread watches each PR across both hosts through native T3
`watch_pull_request`; children and reviewers never subscribe. Process existing
findings and actionable checks before watching. Finish any authorized branch
update/push, reconcile the batch once, then watch and end the turn for native
events. Stay quiet for stale, duplicate or no-action events. Wakeups prompt
inspection; they grant no approval or artifact acceptance. This procedure reduces
duplicate handling, not duplicate notifications emitted by T3.

Use no polling loop, bundled watcher fallback, scheduler or new manager layer.
If native watch access is unavailable, report the gap and hand back the obligation.
Unwatch on handoff or completion. Transfer any outstanding post-merge main checks
explicitly to one named owner, who retains or establishes the sole watch until
those obligations finish; a merged/closed PR watch may already have ended.

A merged PR with required checks queued, missing or inconclusive remains
explicitly unaccepted. Name the check/closeout owner and exactly which acceptance,
integration or delivery step is blocked. Keep disjoint source work moving unless
an explicit owner sequencing decision prevents it. Retire completed watches;
reopen only for a new named obligation. Follow existing repository gates.

## Takeover or restart

Verify the actual issue, PR, remote head/base, worktree (including uncommitted
changes), active claims, findings and current customer problem before resuming.
Treat the retained handoff as context, not proof of current state; record access
gaps rather than inventing a running task or retrieving restricted history.
Agree the continuation scope and writer before editing; preserve unrelated work,
Git authorship, verified contributor credit and applicable evidence identities.

Check whether newer main already solves the problem or changes its architecture
or ownership. Resolve conceptual conflicts against current intent and newer
invariants, not just clean conflict markers. Recommend continuation, bounded
rework or closure with evidence; closure and scope expansion need their existing
authority. When a rebase is authorized, inspect `git range-diff` and the final diff
to verify intent, then run only affected checks. Remote reads/fetches and branch
changes remain within the assignment's tool and access authority.

Before any force push, require both an observed remote HEAD and explicit
force-push authorization; use a lease tied to that exact HEAD. A failed lease
requires reassessment, never overwrite. Takeover itself grants no force push,
merge, queue, automerge, publication, or global stop of unrelated work.

Return a concise change, evidence, blocker/decision, next owner/action and available
work. Include a real access gap if a surface cannot be reconciled. Skip separate
user-facing updates for stale events or unchanged completed tasks.
