# Thistle mission

Thistle is a fast, trustworthy, accessible Ruby/Rails application-understanding
tool. Its independently implemented Rust core is delivered as real Ruby gems
through a thin Ruby/Rails facade and C-native bridge, with explicit ownership of
data and lifetimes across that boundary.

This is the canonical governing intent. It is not a claim that the present
implementation meets every goal. The [README](../README.md) describes the current
slice; the [capability ledger](capability-ledger.md) owns launch outcomes and
their evidence requirements.

## Complete useful work at the best achievable cost

Pursue the best achievable complete-workflow latency, startup, capture and
publication cost, reader cost, allocations and memory use within explicit
correctness, security, usability and reliability budgets. Include installation,
native crossings, storage, operations and downstream maintenance in the cost of
a design. Functional success alone is insufficient; a faster inner loop cannot
justify moving greater cost or risk elsewhere in the user's job.

Where supported, use installed Thistle to inspect its own packaged source and
propose bounded improvements. Accept improvements through reproducible
measurements and independent review bound to the exact artifact, environment
and scope. Source inspection is a hypothesis source, not self-qualification or
authority to change frozen evaluation policy. Preserve the
[experiment policy](experiment-001.md) and the
[artifact and qualification boundaries](development/pr-ci-release.md#artifact-reuse-and-evidence).

## Preserve outcomes while challenging inherited design

Launch must at least match Woods's useful customer outcomes. Challenge inherited
architecture and interfaces when another design serves those outcomes better;
legacy API, command, storage or package compatibility is not required. Woods
engine code is prohibited. Authorized Woods Map and branding reuse must retain
provenance and license attribution, including the [Map reuse record](../map/docs/REUSE.md).

Keep Find, Source, Links and Check recognizable. Support vocabulary retrieval
through visible, literal labels and navigation that does not depend on recalling
a command. Preserve optional home-row shortcuts, text and IME input, keyboard
focus and no-JavaScript paths. Map must explain evidence provenance, coverage and
uncertainty, and enforce access boundaries even for read-only views. Console,
REPL and arbitrary evaluation endpoints remain outside the core product.

All 17 launch requirements remain until independently accepted evidence covers
their declared outcomes and support scope. A working slice, a new interface or a
deliberate compromise cannot silently qualify or remove a requirement.

## Improve without weakening evidence

Use targeted, fast PR checks, broader main-branch checks and thorough selected
release qualification, following the [review and CI policy](development/pr-ci-release.md).
Assess resource, downstream and maintenance costs as well as behavior. Keep
candidate feedback, independent qualification and owner-authorized publication
distinct. The [agent workflow](development/agent-workflow.md) governs bounded
work, review and deliberate tradeoffs; the
[configuration guide](development/agent-configuration.md) defines what belongs
in shared guidance and what remains local or private.
