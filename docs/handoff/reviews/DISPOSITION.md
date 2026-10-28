# Baseline review disposition

Three independent agent reviews covered architecture/performance, native/security
boundaries, and Map/product interaction. They did not run native or installed
qualification, and their source reviews are not a consensus launch approval.

| Finding | Disposition |
|---|---|
| Fresh exact hardened installed baseline absent | Required hosted lane runs the unchanged evaluator, real Rails observations, parser worker and reader-construction probes. No pass inferred from historical packages or source tests. |
| Moved archives would enter the core gem through the docs glob | Exclude only `docs/handoff/`; compare every vendor file digest to packaged data without removing legitimate `target` directories. |
| Map smoke did not bind its native/core Ruby files to accepted evidence | Wrapper checks evaluator-recorded runtime hashes before and after Map, compares its native hash, and verifies every packaged core/Map regular file against installed bytes. Execution evidence still required. |
| Failed captured smoke output discarded | Direct stdout/stderr files now survive failure and a 60-second deadline. Local exit-7 negative control confirmed both streams persist; no false success accepted. |
| Package identities could change after quality evaluation | Compare final core/Map digests to initial identities and evaluator-recorded core digest. |
| Evaluator HEAD alone does not prove unchanged working files | Compare tracked files with HEAD before/after, record tracked-file hashes and assert they remain unchanged. Frozen policy and expected outputs are unchanged. |
| Ruby 3.0 CI could not load Map tests under `ruby -e` | Replace `require_relative path` with `require File.expand_path(path)`. Original failing run retained; rerun determines actual Map outcome. |
| Optional shortcut guard coverage and real accessibility/IME journeys incomplete | Remains unqualified; no input/accessibility/user-study claim from syntax review or historical browser automation. |
| Native fuzzing, hostile-parser qualification and resource isolation absent | Remain launch blockers. A larger parser stack is a mitigation; encoded-data admission is not a physical-memory cap. |
| Protected evaluator/controller deployment absent | Remains a launch blocker. A frozen separate history on candidate-owned orchestration is not independent authority or branch protection. |

No additional concrete baseline ownership/path-containment defect was reproduced.
Optimization is still gated on newly installed baseline evidence; any later
candidate must preserve the reviewed correctness hardening and frozen policy.
Architecture review records subtle matching/ranking semantics and added-cache
accounting requirements for that separate experiment.
