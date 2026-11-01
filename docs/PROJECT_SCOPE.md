# Thistle project scope and goals

Use this index to find the governing scope without treating a dated design or
working implementation as the current plan or proof of launch readiness.

| Question | Authoritative source |
| --- | --- |
| What are we building, and why? | [Mission](MISSION.md): trustworthy, accessible Ruby/Rails application understanding at the best achievable complete-workflow cost. |
| What must launch deliver? | [Capability ledger](capability-ledger.md): all 17 customer outcomes, support obligations and required acceptance evidence. |
| What works in the current implementation? | [README](../README.md), current source and the affected contracts in `docs/development/` and `map/docs/`; read each claim's actual evidence and limits. |
| What happens next, and who owns it? | [Thistle Linear project](https://linear.app/lost-in-the/project/thistle-9bc9a3494d6d) and its current issues own priorities, dependencies, claims and acceptance tracking. The [workflow](development/agent-workflow.md) explains those records. |
| What counts as accepted evidence or permission to release? | [PR, CI and release policy](development/pr-ci-release.md): candidate feedback, independent exact-artifact qualification and owner-authorized publication are separate decisions. |

Launch must at least match Woods's useful customer outcomes. This includes
source and loaded-Rails understanding, retrieval and relationships, lifecycle and
change investigation, supported interfaces and exports, Map investigations,
optional contextual help, installation and secure operation. Read the ledger for
the actual requirements and support scope; this index does not replace its rows.
Neither a working slice nor completed tasks qualify a requirement.

Rust owns the independently implemented engine; Ruby supplies bounded faithful
Rails observations and the gem boundary, bridged through C with explicit
ownership. Woods engine code is prohibited. Authorized Woods Map and branding
reuse retains provenance and license attribution. Legacy interfaces need not be
preserved. Keep Find, Source, Links and Check recognizable, with uncertainty,
access control, keyboard/IME input and no-JavaScript paths. Console, REPL and
arbitrary evaluation endpoints remain excluded. The mission governs these goals;
changing a customer outcome or support obligation requires an explicit decision.

## Historical design and evidence

Load these documents when the task concerns their design or recorded artifact,
rather than as universal startup reading:

- [Architecture and launch plan](handoff/ARCHITECTURE_PLAN.md): October 28 design
  snapshot and detailed launch inventory. Current mission, ledger and explicit
  owner decisions govern where later evidence supersedes its progress wording.
- [Implementation handoff](handoff/IMPLEMENTATION.md), [continuation handoff](handoff/CODEX_HANDOFF.md)
  and [evaluator handoff](handoff/EVALUATOR_HANDOFF.md): retained implementation
  and evaluator context, including historical next steps.
- [Restoration](handoff/RESTORATION.md) and [baseline acceptance](handoff/BASELINE_ACCEPTANCE.md):
  newer restoration dispositions and the exact accepted baseline scope.
- [Experiment 001 policy](experiment-001.md), [retained result](handoff/experiment-001/RESULTS.md)
  and [retired orchestration provenance](development/retired-workflows/README.md):
  completed experiment history, with frozen identities and limits.

Baseline restoration and Experiment 001 already landed. Verify current source,
issue state and exact evidence before proposing further restoration or another
campaign. Keep failed attempts and original identities; do not import old copies
or interpret historical instructions as unfinished assignments.
