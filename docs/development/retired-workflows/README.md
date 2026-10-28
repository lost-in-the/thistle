# Completed Experiment 001 workflow

`experiment-001.yml.txt` is an inert provenance copy, outside
`.github/workflows/`. The completed one-off job can no longer be dispatched
from current source. This prevents Ruby 3.3.13 from attempting to install current
gems requiring Ruby >=3.4 and prevents preflight-only runs from uploading empty
evidence. Existing run logs and artifacts, including failures, remain unchanged.

The copy is byte-for-byte from Dependabot PR #27 head
`60c24a80e949c1820aed7e2a945df06b5ff2b618`, retaining its four maintained pin
substitutions. It is not the orchestration used for the measured campaign.
The original workflow is preserved at
[`f424aa661804a013afc41a167f8afde47358f268`](https://github.com/lost-in-the/thistle/blob/f424aa661804a013afc41a167f8afde47358f268/.github/workflows/experiment-001.yml).
The [completed run](https://github.com/lost-in-the/thistle/actions/runs/40702407356)
and [result record](../../handoff/experiment-001/RESULTS.md) own the historical
source, action/runtime, evaluator, policy, toolchain, artifact and attempt identities.
Neither the pin update nor retirement relabels that evidence as a new run.

Retirement was chosen over a historical-source preflight because this one-off
campaign is complete. An allowlist and conditional diagnostic uploads would
maintain an executable replay path with no current work requiring it. Moving the
file adds no runtime dependency or runner execution. The Core source gem includes
`docs/` outside `docs/handoff/`, so it gains the 5,973-byte inert workflow and
this small provenance note; that bounded documentation cost is accepted instead
of adding a packaging exception. Git history and the inert copy retain inspection
and rollback provenance. Reconsider only for a
separately reviewed campaign; restoring a workflow alone does not authorize a
replay, policy changes, rebuilding selected bytes or a broader performance claim.

The historical hardened-baseline lane remains separate and refuses current-policy
source. Modern installed verification uses Release candidate and exact packages;
it cannot replace historical bytes. #24 owns durable restricted retention of
the selected baseline and experiment evidence before hosted artifacts expire.
