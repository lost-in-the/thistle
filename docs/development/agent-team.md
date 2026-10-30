# Reusable agent team

Use five responsibilities and five reusable procedures to deliver the
[mission](../MISSION.md). The [workflow](agent-workflow.md) remains authoritative
for ownership and planning; the [PR/CI/release policy](pr-ci-release.md) owns gates.
These entry points add no manager approval layer or release authority.

## Roles

Assign one role explicitly by linking its file in the task brief. These are
portable agent prompts, not a claim that a runtime autoloads arbitrary filenames.

| Role | Responsibility | Typical lifetime |
| --- | --- | --- |
| [Overseer](roles/overseer.md) | Product/CTO: mission, architecture and substantive product direction | Continuing context |
| [PM](roles/pm.md) | Local overseer: Linear planning, dependencies, assignments and acceptance tracking across hosts | Continuing context |
| [Dev Lead](roles/lead.md) | Implementer: a bounded customer outcome, specialist delegation and technical convergence | Outcome |
| [Reviewer](roles/reviewer.md) | Independent correctness, security, performance and maintenance review | Assigned review |
| [Auditor](roles/auditor.md) | Customer interaction, blast radius and actual evidence applicability | Assigned QA scope |

Keep one PM across Mac and Linux. Prefer leads per customer outcome; platform
work may justify a host-specific lead. Keep one named repository integration
owner at a time. A role can delegate execution without transferring its
accountability or another owner's authority.

Focus on two primary outcomes while admitting genuinely disjoint bounded workers.
Reviews and audits apply to the change's risks; these roles are not five mandatory
approval stages. Keep substantive review independent from authorship. An additional
provider or agent does not establish protected evaluator independence.

## Skills

Canonical procedures live under `.agents/skills/`. Claude-facing entries under
`.claude/skills/` explicitly load the canonical file; they contain no parallel
procedure. Resolve all task paths from the actual repository root.

| Skill | Use |
| --- | --- |
| [thistle-plan](../../.agents/skills/thistle-plan/SKILL.md) | Shape an outcome and its ownership, dependencies and acceptance |
| [thistle-build](../../.agents/skills/thistle-build/SKILL.md) | Implement and converge an assigned outcome |
| [thistle-review](../../.agents/skills/thistle-review/SKILL.md) | Challenge the actual candidate for lasting quality |
| [thistle-check](../../.agents/skills/thistle-check/SKILL.md) | Verify the affected journey and evidence bindings |
| [thistle-hand-off](../../.agents/skills/thistle-hand-off/SKILL.md) | Reconcile current state, transfer responsibility and release claims |

Load the needed procedure and relevant references. Keep current task state in
Linear/PR checkpoints, not role prompts. Use existing validation tools for mechanical
work. A repeated defect can justify one assigned improvement to a rule, skill or
script; the Dev Lead can delegate that work without adding a permanent manager.

## T3 and two hosts

Use T3's existing provider sessions and orchestration when available. Read the
installed environment's capabilities before selecting provider instances or linked
hosts. The current upstream [delegation contract](https://github.com/pingdotgg/t3code/blob/6575ce32508bd7908444241f3719aa33aaf77f90/packages/contracts/src/orchestratorMcp.ts)
supports provider/environment targets and worktree isolation. This source contract
does not establish the installed version or authority on a particular machine.

- Distinguish UI connections from authorized [linked environments](https://github.com/pingdotgg/t3code/blob/6575ce32508bd7908444241f3719aa33aaf77f90/docs/user/remote-access.md#link-another-environment).
  Use existing links and permissions; missing access is not permission to expand it.
- Explicitly request isolated worktrees for independent writers. Shared checkout
  is the upstream default. Verify the admitted commit and actual workspace;
  uncommitted parent edits are not a child contract.
- Supply the complete bounded brief. T3 app-owned children receive the supplied
  task, not the parent's full conversation.
- Prefer completion delivery and incremental reads over repeated polling. Reuse
  an idempotency key only for a retry of the same operation; reconcile actual
  task state after an uncertain response before launching more work.
- Track named heavy-build/measurement slots per host and provider/account budgets
  separately. T3 wait timeouts do not cancel children or enforce CPU/RSS limits.
  Keep actual process/container limits and release claims after verified completion.
- Select a second provider for an existing independent-review responsibility when
  useful. Provide the contract and raw diff/evidence before the author's reasoning.
  Preserve existing required review gates; provider variety is not a new gate.

Claude dynamic workflows may perform bounded fanout inside an assigned Claude task
when the installed tool surface supports them. Start with read-only review or
retained-evidence analysis. [Workflow resume/retry behavior](https://code.claude.com/docs/en/workflows)
can repeat agent work: merges, package dispatches and one-shot measurements need
explicit replay protection and their existing authority. Preserve failed/null
worker results as unverified obligations. T3 remains the cross-provider/host
assignment mechanism; do not create a competing scheduler.

## Start or resume a task

Use the existing issue and claim protocol. The following brief is a template,
not an active assignment:

```text
Read AGENTS.md and docs/development/roles/<role>.md.
Use .agents/skills/thistle-<procedure>/SKILL.md for this assignment.
Task and customer outcome: <canonical Linear issue and concrete question>
Contract and evidence inputs: <current paths/links and relevant scope>
Base/candidate: <exact admitted identities>
Ownership: <files/interfaces, integration owner, acceptance owner>
Execution: <actual host/provider, allowed resources and finite checks>
Authority/stop conditions: <existing limits, unresolved choices, protected work>
Return: <supported result, exact evidence, remaining action and released claims>
```

An agent confirms the supplied identity and reads the linked instructions. It
does not need a fresh manager approval for already authorized routine work.
On restart, reconcile the checkpoint and active children before executing again.

## Public and local configuration

Follow the [portable configuration boundary](agent-configuration.md). Public
files contain mission, role contracts, procedures and sanitized setup references.
Keep host paths, provider/account selections, signer and credential references,
resource budgets, private sources/captures and restart details local. Adding a
provider does not authorize sending restricted evidence or history to it.

`CLAUDE.md` continues to import `AGENTS.md`; existing hooks and permissions are
unchanged. This pack installs no global profile, T3 link, watcher, credential,
workflow script or automatic background task. Native custom-agent definitions
can be added through a bounded change once their loading is verified in the
intended runtime.

## Verify discovery without a product campaign

1. In each intended installed provider, inspect available skills from the actual
   checkout. [Codex documents `.agents/skills`](https://learn.chatgpt.com/docs/build-skills);
   [T3's Claude provider discovers `.claude/skills`](https://github.com/pingdotgg/t3code/blob/6575ce32508bd7908444241f3719aa33aaf77f90/apps/server/src/provider/Drivers/ClaudeSkills.ts).
   In Codex, same-name skills remain separate and both may appear in selectors.
   Verify other providers' collision behavior in the installed runtime. Inspect
   matching paths and explicitly load the intended canonical file.
2. Run one harmless read-only assignment by explicit role and skill reference.
   Have it identify the role/procedure files, actual base and ownership boundary.
   Distinguish explicitly supplied instructions from native discovery.
3. Record sanitized runtime/provider/version and observed loading in the existing
   task checkpoint. If native discovery is absent, explicit file loading remains
   usable; leave native loading unverified rather than inventing an adapter.
4. Use the arrangement on the next suitable existing outcome. Review waiting time,
   repeated work and material findings from existing records; no separate dashboard.

Only the ten exact `SKILL.md` entry paths are additional documentation-only CI
paths. Unknown agent files, executable workflows/scripts and hook/permission
configuration retain conservative routing. Main's broader checks remain intact.
Instruction presence and CI routing are not a security sandbox or live runtime
validation. Keep this pack outside distributed gem document manifests.
