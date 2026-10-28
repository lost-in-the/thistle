# Thistle delivery review — final verdict

**Verdict: APPROVE. No blocking design findings.**

Reviewed on 2026-10-28.

- Candidate: `/workspace/scratch/bc08c0d3c126/woods-design-review/thistle-plan-v0.2.md`
- Verified SHA-256: `0be7dbb21f69390254bd16a9bf12625094c0916d0ceed386b8c493b7fbf2556e`
- Review scope: entire exact candidate; delivery, outcome coverage, distribution, independent evaluation, support, integration, PR/CI/security, estimation and launch readiness.
- This is a fresh approval of the Thistle plan. It does not carry forward the earlier rewrite/prototype approval.
- No substantive candidate edits are requested. Adding review metadata and the reviewed hash is sufficient to record this verdict; any later substantive change creates a new review candidate.

## Why the plan is ready to guide implementation

The plan now distinguishes three things that the earlier proposal conflated: the customer outcomes required at launch, the internal milestones used to build them, and the evidence needed to forecast and qualify delivery.

The launch boundary is clear. Every useful required outcome and supported deployment cohort must qualify, with evidence quality, freshness and completeness intact. An aggregate benchmark, an attractive Map slice or a smaller set of popular extractors cannot substitute for coverage. The published and pinned current comparison products have distinct roles; material baseline drift is reviewed before release while experiments remain frozen during trials.

The implementation boundary is equally clear. Thistle's engine is new. Its commands, tool schemas, Ruby API, physical store, exports and URLs are its own design. Comparator adapters live in the independent evaluator. Permitted Map reuse does not oblige the product to preserve old tools or maintain two producer paths. The exact installed candidate must operate without Woods code, executables or transitive runtime loading.

The estimate boundary is honest. W0–W10 represent the full launch program, not a renamed demonstrator. The former ranges are withdrawn as launch estimates. Discovery, two dissimilar evidence families and an installed reused-UI path produce the evidence for optimistic/likely/adverse estimates. The plan separately accounts for engineering effort, elapsed critical path, CI/service capacity and independent review capacity.

## Resolution of the principal delivery risks

| Risk reviewed | Resolution in this candidate | Delivery judgment |
|---|---|---|
| Prototype presented as a competitor launch | Full capability matrix, unresolved-row blocking rule, W10 public-launch boundary and explicit limitations of feasibility | Resolved at plan level |
| Parity achieved by selecting the older, smaller baseline | Published 2.1.0 minimum plus useful pinned current Woods/Map jobs; final baseline change review and matched-scope comparisons | Resolved at plan level |
| Old API and file compatibility inflate the new product | New interfaces explicitly allowed; job-level comparison adapters owned by the testbed; no old-tool/format/URL requirement | Resolved |
| Map reuse secretly depends on Woods | Replace dependencies, require paths, reader/policy helpers and Guide launchers; clean Thistle-only installed bundle; no mandatory dual-provider support | Resolved at plan level |
| Package proliferation before a need is proven | One core gem, optional UI only when it reduces install/lifecycle burden; native and MCP assets need not become subgems | Resolved |
| Native implementation becomes an untested schedule commitment | Profile and benefit bound first; fixed spike budget/stop rule; install, ownership and complete-workflow gates; simpler implementation remains valid | Resolved |
| Evaluation inherits candidate bugs or permits self-grading | Independent expected facts, fresh runtime observations, external mutation fence, hostile candidates, protected worker/controller authority and held-out confirmation | Resolved at plan level |
| Performance hides quality loss or work shifted elsewhere | Matched complete workflows, explicit task-quality floor/uncertainty, cold and update latency, all owned processes, maintenance debt, failed attempts and cost amortization | Resolved at plan level |
| Semantic and human workflows remain indefinitely “optional” | Required deployment/retrieval outcomes, actual supported provider tests, complete Map investigations and independently qualified Guide configuration | Resolved at plan level |
| Accessibility and word finding become cosmetic naming changes | Stable literal labels, visible alternatives, approximate discovery with exact identity protection, configurable scoped keys and intended-user task evaluation | Resolved at plan level |
| Launch is implied by a green source checkout | Installed packages, actual loaded native identity, exact release tuple, required lanes and independent publication authority | Resolved at plan level |
| Switching becomes ownership of the old product | Separate roots/bundles and task-oriented adoption; reversible user setup without old release-line or compatibility commitments | Resolved |

“Resolved at plan level” means a concrete implementation gate exists. It does not mean that the gate has already passed.

## First implementation decisions and evidence

These are the plan's existing implementation obligations, not new approval conditions or requests to expand scope.

### W0–W3: establish the actual program

Expand the matrix into independently testable customer jobs and environment/failure combinations. Record the exact released-gem digest, installed current comparison packages, source revisions, Map tuple and evaluator revision. Apply the user's known scope exclusions when classifying the ledger; do not rediscover excluded work as a launch requirement.

Choose the smallest package topology that supports optional UI use. Define the shared evidence and query contract early enough for the engine, Map, CLI/MCP and exports to proceed without separate competing data models.

Demonstrate a clean installed package, one correct capture-to-public-answer flow, an evaluator that rejects defective outcomes, and an actual Thistle-only reused-Map journey. Complete two semantically different evidence families before extrapolating throughput. A narrow native spike enters only after the reference path identifies a worthwhile target.

These results support a costed implementation plan. They do not establish broad parity, scale, complete human workflows, provider readiness or a launch date.

### W4–W9: close the customer jobs

Require positive, negative, ambiguity, optional-dependency and mutation evidence for each required family. Capture completeness and supported limits explicitly. Keep task quality and full-source recovery in the loop as compact views, retrieval modes and default behavior change.

Run the actual provider/backend/deployment combinations that realize required jobs, including source/vector alignment, provider failure and restart. For the human product, qualify the whole investigations represented by Map's broader coverage rather than a short README milestone list.

Make new setup, diagnosis, input methods, interrupted work, source disclosure and switching part of normal validation. Update estimates as newly observed semantics or integration risks change a work package; do not turn an unqualified row into a claimed feature to preserve a date.

### W10: qualify one exact release tuple

The release decision remains a conjunction of functional coverage, correctness, task quality, performance/resources, cost, interaction, installation/deployment, security, differentiation and exact-artifact readiness.

The quantitative decision rules are deliberately not invented in this plan. Their values must be independently chosen before candidate comparisons, calibrated with baseline/pilot evidence, and frozen for the campaign. Unset or inconclusive required gates remain blocking, as the candidate already states.

No claim of general speed, market demand or agent productivity follows merely from this design approval. The introspective cycle proves the development mechanism operates; broader productivity claims require their own controlled comparison.

## Source and scope verification

In addition to the prior current-primary-source audit supporting the independent delivery report, this final review checked the exact pinned Map coverage and Guide notes used by the candidate:

- [Map coverage and job discovery](https://github.com/lost-in-the/woods-map/blob/29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9/docs/design/coverage.md) mixes design and implementation/qualification status and identifies the broader Landscape, graph/list, ERD, history, range and Trail jobs. The plan appropriately uses it for discovery, then requires verification.
- [Guide qualification notes](https://github.com/lost-in-the/woods-map/blob/29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9/docs/design/notes/m7-guide.md) explicitly leave a real-provider run open. The plan preserves that distinction and requires Thistle's own declared real-provider configuration to qualify.

The review also checked that the candidate explicitly withdraws the old launch ranges, does not mandate legacy adapters or old Map support, treats native/platform costs conditionally, and requires package independence and full outcome qualification.

## Approval boundary

Approve this exact candidate as a coherent product architecture and delivery plan. It is sufficient to begin the bounded discovery/feasibility program and produce the implementation estimate.

This approval is not a claim that Thistle has been implemented, tested, proven faster, made commercially viable or qualified for release. It authorizes no repository mutation or publication by itself. The required evidence remains the work described by the plan.

