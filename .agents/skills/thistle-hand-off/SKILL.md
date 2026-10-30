---
name: thistle-hand-off
description: Hand off, resume or close a bounded Thistle task with current ownership and exact evidence. Use when a candidate, blocker, dependency, acceptance result or responsible worker changes.
---

# Hand off

Use the [existing claim/checkpoint format](../../../docs/development/agent-workflow.md#claim-protocol)
and the assigned role. Keep one current checkpoint with historical receipts linked.

1. Read the current issue/PR/head and retained checkpoint once for the event batch.
   Deduplicate notifications by task/PR, candidate, event identity and update time.
   Completed watches stay retired unless a new obligation appears.
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

Return a concise change, evidence, blocker/decision, next owner/action and available
work. Include a real access gap if a surface cannot be reconciled. Skip separate
user-facing updates for stale events or unchanged completed tasks.
