# Delivery workflow review record

Reviewed on 2026-10-28 by the separate `flow_independent_review` agent task.
The reviewer initially read files and reported findings; the parent then assigned
this record as the reviewer's only authored file. The CI and guidance authors
resolved their respective findings.

**Disposition: no unresolved blocking finding for opening the delivery PR.**
This is an agent review of the proposed development infrastructure, not a GitHub
maintainer approval, protected independent qualification, production acceptance,
merge authorization, or permission to publish. The agents share the same session
authority. Review of their work does not establish a separate security boundary.

## Scope and identity

The review covered `AGENTS.md`, `CONTRIBUTING.md`, the two development guides,
the PR template, all four issue forms and their configuration, the four new
workflows, both automation scripts, the action-pin inventory, and automation
regressions. It checked routing, source/bootstrap distinctions, required-result
aggregation, permissions, package identity, installed verification, multi-agent
coordination, and the user's performance and lasting-quality review standard.

The code/configuration snapshot comprised these eight files:

- `.github/workflows/ci.yml`
- `.github/workflows/product-checks.yml`
- `.github/workflows/compatibility.yml`
- `.github/workflows/release-candidate.yml`
- `.github/scripts/pipeline.py`
- `.github/scripts/installed-check.sh`
- `.github/scripts/action-pins.json`
- `tests/automation/test_pipeline.py`

Its combined SHA-256 was
`2e01db4f0e2a22f6315e84f71ab8a047eebfb2e94987ba033a2f3c28a999ecb3`.
Compute this by sorting those paths, concatenating each path, a NUL byte, its
lowercase SHA-256 hex digest, and a newline, then hashing the UTF-8 concatenation.
This identifies the local reviewed payload before the delivery commit existed;
it does not invent a tested GitHub commit. Reconcile subsequent edits and record
the actual PR head and hosted results before acceptance.

## Findings and resolutions

| Finding | Consequence | Resolution verified |
|---|---|---|
| Complete Map deletion or rename could select no product lane. | A source checkout could silently lose Map coverage. | Planning checks Map markers in both base and candidate; actual Git rename/deletion fixtures fail closed. Partial source and complete core removal also fail closed. |
| Removing required root package documents could look like a harmless documentation change. | The source gem could become unbuildable without the PR product lane running. | Restored source requires `README.md`, `LICENSE`, and `THIRD_PARTY.md`; deletion and rename cases have regressions. |
| Every file named `manifest.json` was excluded from accounting. | A nested file could be uploaded without a recorded digest. | Only the root manifest is excluded. Nested manifests are hashed; unlisted, altered, missing, duplicate, traversal, and symlink entries are rejected. |
| Hidden paths could be accounted for but omitted by artifact upload defaults. | Downloaded bytes and the manifest could disagree. | Hidden path components are rejected. Source identity also rejects tracked changes without printing the source diff. |
| An empty Ruby test glob could report successful test execution. | Deleting or renaming the suite could remove meaningful coverage. | The Ruby lane now rejects an empty test glob, matching the existing Map guard. |
| Issue-form and PR-template edits selected the full native/Map lane. | Routine planning changes would pay unnecessary build and test cost. | A narrow planning-metadata allowance skips product work while automation checks remain; workflow, script, executable, and unknown paths stay conservative. |
| Source-build native bytes could be mistaken for installed source-gem identity. | Consumers could attach the wrong native hash to an installation claim. | Manifest and summaries label the checkout native hash as a build observation; each installed cohort records its own loaded-native identity. |

The always-present `CI / required` aggregate requires successful planning and
metadata work and a successful selected product lane. Unexpected skips,
cancellation, malformed planning outputs, and failed required work cannot become
a pass. No workflow-level path filter hides that check.

The workflows use read-only repository permissions, immutable action references,
nonpersistent checkout credentials, and no publication credentials. The release
candidate flow downloads the prepared package set by artifact ID, rejects digest
mismatch, and verifies the same source-gem bytes across its installed cohorts.
The existing restoration qualifier was inspected to confirm that this orchestration
reuses its installed checks rather than building a second evaluation suite. Its
authority remains candidate-owned.

## Validation actually run

Commands ran from the delivery payload directory on Linux x86-64. The Python
suite uses temporary Git repositories to exercise real rename/deletion cases.

| Command | Tool/version | Result |
|---|---|---|
| `python3 -B -m unittest discover -s tests/automation -v` | Python 3.12.14 | 28 tests passed; unittest reported 1.493 seconds. This is local automation-test time, not hosted CI latency. |
| `/tmp/thistle-actionlint/actionlint .github/workflows/ci.yml .github/workflows/product-checks.yml .github/workflows/compatibility.yml .github/workflows/release-candidate.yml` | actionlint 1.7.12 | Passed with no diagnostics. |
| `bash -n .github/scripts/installed-check.sh` | GNU Bash 5.2.21 | Syntax passed; the installed candidate was not executed by this command. |

The guidance author's YAML/form-structure and relative-link validation is
additional author evidence; it is not misrepresented here as a second reviewer
run. The reviewed `download-artifact` pin's own action definition exposes the
artifact-ID and digest-mismatch controls used by the workflow.

## Integration with existing work

At inspection, [restoration PR #1](https://github.com/lost-in-the/thistle/pull/1)
was an open draft at `3c1ff573163d9d3875be4574c2dc826748386c28`, targeting bootstrap
main `317671367949111861a63d0c3635dec94533fc8e`.
[Experiment PR #2](https://github.com/lost-in-the/thistle/pull/2) was an open draft
at `7ce504a9abff606370b5f55973ba7bd414fa4a0e`, stacked on the restoration branch.
These are observed snapshots; refresh them before integration.

Both the delivery change and restoration touch `AGENTS.md` and supply competing
definitions at `.github/workflows/ci.yml`. This review compared their content;
it did not simulate or perform a merge. An integration owner should:

1. Review and integrate restoration through its own authorized acceptance path.
   The delivery PR can remain open independently while that decision is pending.
2. Update the delivery branch onto the accepted restored base. Resolve agent
   guidance semantically: retain the product/authority constraints and restored
   `docs/handoff/` references, while keeping the new claim, review, and delivery
   protocol. Do not resurrect stale instructions to repeat completed restoration.
3. Retain one canonical `ci.yml`. Preserve the restoration's native/Ruby/Map and
   packaging coverage, including the Ruby 3.0-compatible Map test loader. The new
   primary PR lane plus broader main/weekly lanes replaces the old every-PR
   three-cohort matrix. Keep baseline/evaluator tools and the frozen experiment
   workflow intact. Verify the current source and exact required-check names.
4. Update the stacked experiment's base as its own review requires. The delivery
   change does not depend on accepting that optimization and must not replay its
   completed campaign automatically. Preserve original artifact/report identities;
   a newly built package needs evidence for its own scope.

No existing PR, source branch, evaluator policy, or selected experiment artifact
was modified by this reviewer.

## Remaining evidence and bounded follow-ups

- **Hosted behavior is unrun for this change.** Local validation does not prove
  the new PR/main/compatibility workflows or installed release-candidate cohorts
  have succeeded on GitHub. Verify the committed setup PR, then the integrated
  restored-source product lanes and authorized manual candidate path. A bootstrap
  metadata pass must remain explicitly narrower than product acceptance.
- **Administrative controls are separate.** Required-check rules, protected
  external evaluator identity, release credentials/environments, durable evidence
  retention, and publication remain separately authorized work. This record does
  not certify live Project settings or those controls.
- **Measure delivery cost.** Capture actual queue/job time, expensive test time,
  package size, and cache behavior before setting the owner's latency/resource
  budget. Examine full-history checkout cost and the distinct Cargo debug-test
  and release-extension build directories if material. Preserve useful coverage;
  do not merge caches across authority boundaries or assert an unmeasured speedup.
- **Keep policy updates coordinated.** Ruby/Rails cohorts, the Rust toolchain,
  source layout, and frozen evaluator identity are explicit current contracts.
  Update their workflow/script/document references together when they change.
  Broader platform, security, accessibility, and launch qualification remain open.

The review converged on a small targeted PR lane, broader integrated checks, and
thorough reuse of exact release-candidate bytes. No known blocker was left open
within the proposed delivery-infrastructure scope; the limits above prevent that
conclusion from being used as product or release acceptance.
