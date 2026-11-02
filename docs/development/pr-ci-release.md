# Fast development, qualified artifacts, controlled release

Use short-lived branches and small acceptance outcomes. Start useful review early,
run affected checks once per meaningful candidate, cancel obsolete PR feedback,
and preserve exact packages for later qualification. Faster feedback must not turn
a source-checkout pass into an installed-package or launch claim.

## Three authorities

| Responsibility | Owns | Does not establish |
|---|---|---|
| Candidate CI | Fast source, packaging, and development regression feedback | Protected independent qualification or permission to publish |
| Independent qualification | Reviewed controller/policy, isolated workers, exact candidate/support verdict | A broader support promise than its recorded scope |
| Release approval | Owner-authorized promotion of the exact qualified bytes | Permission to rebuild different bytes after approval |

The project indexes these results. Board status, a PR label, or a second agent
with the same credentials is not an enforcement boundary.

## PR flow

1. **Choose a Ready issue.** Check existing claims and branches, agree the smallest
   complete outcome, and record the base commit and responsible reviewer.
2. **Open a draft early.** Supply a useful diff, the issue link, intended behavior,
   and check plan. Keep unrelated refactors, policy changes, and performance
   optimization in separately reviewable changes.
3. **Develop with focused checks.** Run the affected unit/regression tests locally.
   Use the PR workflow for the declared affected lanes; don't rerun a full matrix
   after a text-only follow-up unless it changes an applicable contract or gate.
4. **Review and check in parallel.** Reviewers inspect the current diff while CI
   runs. Route ownership, native/parser, packaging, Map access/rendering, and
   workflow-permission changes to relevant reviewers. Resolve concrete findings
   and record remaining scope limits.
5. **Integrate an accepted candidate.** The integration owner checks the current
   head/base, applicable results, and merge authorization. Revalidate changed
   integration scope after the base moves. Do not let a stale approval or a prior
   head's report silently qualify new code.
6. **Close the bounded work.** Link the integrated commit and exact evidence.
   Name the owner of outstanding required post-merge main checks and keep the
   result unaccepted while those checks are queued, missing, cancelled, timed-out,
   failed or inconclusive. Native PR watch ends on merge or close; reconcile main
   checks at the next applicable event batch or checkpoint and record any native
   event wake/access gap. Use the
   [watch/handoff procedure](../../.agents/skills/thistle-hand-off/SKILL.md#pr-watch-ownership)
   to identify exactly which step is blocked; disjoint source work may continue.
   Keep broader capability, experiment, and release decisions separate.

Use closing references only when the PR actually completes that work issue.
Reference capability parents without automatically closing them. Close declined
work with its reason; a rejected optimization may be a completed experiment while
the performance capability remains unqualified.

## Review standard

Every review must look for a better implementation, even when the feature works.
Treat a small change as a lasting part of the product: assess the cost it adds to
future changes, users, package consumers, and the test suite. Identify substantive
improvements, rather than limiting review to whether the tests are green.

| Dimension | Questions to answer where applicable |
|---|---|
| Work and complexity | Does this add avoidable full scans, repeated parsing/serialization, unnecessary I/O, expensive copies, or work proportional to the wrong input size? What happens at the stated input and result limits? |
| Memory and native ownership | Are allocations, retained memory, native/Ruby lifetimes, FFI call frequency, copies, locking, and cancellation bounded and intentional? Could batching or a simpler representation reduce total cost safely? |
| Lifecycle and state | Are invalidation, generation identity, cache admission/eviction, reload, concurrent readers, interruption, and partial failure correct? Is there one clear owner for state and resources? |
| Design and maintainability | Are responsibilities, invariants, names, and failure modes clear? Does this duplicate policy or create hidden coupling, incidental abstractions, unexplained special cases, or multiple sources of truth? |
| Security and failure | Do parser/filesystem/rendering/access boundaries remain enforced on negative and error paths? Can malformed input, timeouts, missing dependencies, or failed cleanup leave misleading success or unsafe state? |
| Downstream cost | What changes in startup, complete-session time, build/install effort, gem size, platform support, retained storage, operations, and compatibility? Is a local optimization exporting work to the user or another layer? |
| Test cost and strength | Does each new check detect a meaningful regression at the smallest useful boundary? Are fixtures bounded, failures diagnostic, and coverage complementary across tiers? |

For a material performance claim, record the relevant baseline, workload, exact
candidate, measurement method, variability, and full-workflow/resource budget.
Choose the acceptance threshold before evaluating a performance experiment. For
ordinary changes, use a focused measurement when the risk warrants it; inspect
complexity and existing evidence without starting a campaign for every edit.
Measure CI duration and expensive test cases before claiming the suite is fast;
set and revisit an explicit latency/resource budget with the responsible owner.

A review response names the reviewed commit/scope, concrete findings, expected
consequences, supporting evidence, and disposition. Suggest a simpler or faster
approach when there is one. If no material issue is found, say what was examined
and why the implementation is appropriate within that scope, including any
remaining uncertainty. A bare “works” or “tests pass” is not sufficient review.

Block acceptance for correctness or security defects, material regressions,
unbounded or incorrectly owned resources, invalid cache/lifecycle behavior,
unsubstantiated required claims, or design debt that makes the current contract
unreliable. Resolve the finding or narrow the claim with an explicit decision.
Record useful improvements outside the bounded acceptance outcome as actionable
follow-up issues with their impact and check plan. Review should converge on a
defensible change; speculative rewrites and unsupported micro-optimizations do
not justify an endless series of gates.

### Efficient tests

Put a regression at the lowest layer that establishes the behavior, then add an
integration check only where the cross-boundary contract needs it. Use small,
deterministic fixtures for ordinary feedback; reserve larger scale, broad cohort,
stress, and repeated measurement work for the appropriate main, scheduled, or
release lane. Critical security regressions still belong in the required PR path
when their boundary changes. Avoid sleep-based synchronization and redundant
assertions that merely mirror implementation details. Reuse the same test commands
and artifacts across tiers so thorough release verification does not create a
second, diverging suite.

Name first-party active tests, fixture paths, namespaces, helpers and operational
fixture labels for stable behavior or capability (for example, `source_freshness`),
not the introducing ticket or PR. Update current references when renaming; preserve
historical attribution, frozen evidence, commit-pinned URLs, upstream vendor names
and PR-numbered changelog fragments. Framework cohorts such as `rails71` remain
semantic names. The automation naming guard checks active paths and declarations,
not ticket mentions in prose.

## CI execution model

The workflows and scripts under `.github/` implement candidate-owned feedback.
Their run summaries must identify which source/artifact scope was actually
checked. The setup PR does not itself configure branch rules, protected external
checks, publishing credentials, or a production evaluation sandbox.

At initial activation, retain the first hosted PR, main, compatibility, and
release-candidate results and measure their duration/resource cost. Local routing
tests and workflow validation do not prove hosted installation or latency. Keep
unrun lanes explicitly unverified; establish the first CI budget from observed
results before advertising a speed improvement.

| Change or invocation | Expected work |
|---|---|
| PR: guidance and metadata only | Validate repository automation/configuration and the changed documentation contract; report that product lanes were not needed. |
| PR: core, native bridge, gem boundary, build/dependency files, or routing logic | Run reasonably sized native/Ruby/package checks for affected boundaries in the canonical source layout. Treat unknown product paths conservatively. |
| PR: Map source or its dependency/interface changes | Run the affected Map checks with the native core and relevant package/integration work. |
| Main after integration | Run broader product and compatibility checks for integration effects, beyond the PR's targeted scope. |
| Release-candidate request | Thoroughly check the selected product/packages and prepare exact retained evidence. Independent support/security/installation qualification still precedes publication. |
| Broad compatibility, fuzzing, or controlled performance campaign | Use its declared manual/scheduled lane and retain its full scope and attempt history. It cannot qualify unrelated future artifacts. |

`Thistle CI` replaces `.github/workflows/ci.yml` as the single PR feedback
workflow. Planning, automation validation and release-note checks always run.
The current policy in `.github/ci-policy.json` selects Ruby 4.0.9 / Rails 8.1.4
as primary and Ruby 3.4.12 / Rails 8.1.4 as the additional minimum cohort.
Ordinary product PRs use the primary. Changes to policy, workflows, dependencies
or Ruby/native integration boundaries exercise both; a failure in either selected
row fails **`CI / required`**. Notes-only changes avoid native builds.

Ordinary product PRs also require the primary Ruby/Rails cohort on Apple Silicon
(`macos-15`) macOS. Main pushes, explicit full/manual CI and merge groups retain
both Apple Silicon and Intel (`macos-15-intel`). The planner records the selected
runners in `macos_runners`; the macOS matrix consumes that output directly.
Those jobs run source and fresh installed contracts through the
[platform workflow](platforms.md); failure, cancellation, absence or an unexpected
skip of selected macOS work fails the same aggregate. Their development receipts
are separate from the existing Linux candidate/evaluator artifact contract.
Notes-only PRs skip product/platform work; notes-only main pushes retain broad
coverage, including both macOS architectures. This selection policy does not
qualify the independently accepted launch support matrix.

Main runs primary in `Thistle CI` and minimum in **`Compatibility`**, without
duplicating primary. Weekly/manual compatibility and manually dispatched full CI
exercise both. Only primary runs the Ruby-independent Rust unit suite; every
selected Ruby cohort compiles its native bridge and runs applicable Ruby/Map
checks. Release preparation builds one package pair on primary and installs those
same bytes on both cohorts. Stale PR feedback runs cancel when superseded.

The [decision record](decisions.md) explains the modern cohort choice and checked
upstream maintenance status. Ruby 3.3.13 / Rails 7.2.4 belongs to the historical
baseline and Experiment 001 evidence. Newly built Ruby >=3.4 packages cannot be
substituted into that older environment or presented as a replay. The historical
baseline workflow refuses current-policy source before expensive build work.

Draft PRs receive the same required checks on opening and code changes. Marking
an unchanged draft ready does not repeat native builds. A readiness transition
does not retry failed/missing checks or validate a changed base: explicitly rerun
the applicable checks, update the branch, or use the configured integration path
when that evidence is needed. Verify the tested head/base before acceptance.

**`Release candidate`** is manually dispatched with `candidate_sha`, a full
40-character lowercase commit SHA. It prepares one candidate package pair with native/build
metadata and a manifest, then runs installed verification against those same
downloaded package bytes across both declared cohorts. It does not publish a gem.
Experiment 001 completed before PR #2 merged. Its one-off workflow is
[retired outside active Actions](retired-workflows/README.md), preserving source
and run provenance. Normal PR CI does not start a new benchmark campaign. A new
campaign requires a separately reviewed source/environment and policy decision;
modern candidate checks do not replay or broaden the historical performance result.

The required aggregate check must run even when upstream jobs fail or are
cancelled. It must verify the route and every required lane, distinguish an
intentionally unnecessary lane from a missing one, and fail on unexpected
skips/cancellation. A workflow-level path filter must not make the required check
disappear. Deletions, renames, shared interfaces, and workflow changes belong in
the routing policy and its tests.

Bootstrap-only validation must say that product source is not yet present. It can
validate this workflow/guidance change, but cannot report a gem, native engine,
installed contract, or release candidate as qualified. Product-affecting changes
must not become green merely by removing the source markers.

Use a small required feedback lane and expand support qualification according to
the changed risk and declared support promise. The existing Ruby/Rails cohort
matrix remains development evidence. Passing it does not prove every supported
ABI, precompiled install, database/provider route, accessibility journey, or
hostile-parser case.

### Integrated workflow authority

PR #26 integrated the routing/aggregate flow into `.github/workflows/ci.yml`;
it is the canonical PR feedback path. PR #2 subsequently integrated the completed
experiment. Keep one canonical feedback path and preserve the experiment's exact
selected artifacts rather than running its campaign as a per-PR smoke test.

The aggregate remains `CI / required`. The active
[basic main rule](../handoff/runs/issue23-basic-protection-2026-10-29/README.md)
requires this check and PII from GitHub Actions, current-base testing and resolved
threads. Candidate-owned checks still do not establish independent qualification;
#23 owns that unfinished authority. A renamed job
cannot silently replace a required check until the rules and a real run have
been verified by the authorized administrator. #28 completed its scoped repair
with integrated-main and Compatibility results. #20's modern installed-candidate
verification and dependency-lock decision are recorded in the
[exact-candidate report](../handoff/runs/40738248777/README.md) and the
[dependency-lock policy](decisions.md#dependency-locks-library-compatibility-feedback-and-exact-tested-resolutions).
Those completed outcomes retain their recorded artifact/environment scope;
changed candidates need their own affected checks and installed evidence.

### Running and inspecting the flow

Install the isolated notes tool environment from the
[changelog guide](changelog.md#install-and-check), then run the automation
regressions when changing workflows, routing, or release-note tooling:

```sh
python3 -m unittest discover -s tests/automation -v
```

After authorized adoption places the dispatchable workflow on the default
branch, open **Actions → Release candidate → Run workflow**, choose the workflow
branch deliberately, and supply the reviewed full source SHA as `candidate_sha`.
The candidate source must include the restored product and installed qualifier;
a bootstrap-only tree cannot prepare a release candidate. The workflow definition and
candidate source identities are recorded separately. A dispatch prepares and
checks a candidate; it does not grant publishing permission.

| Artifact name pattern | Contents and use |
|---|---|
| `ci-plan-<run_id>-<attempt>` | Selected route, changed paths, tested source/base, and honest bootstrap/source scope. |
| `pr-candidate-ruby-<ruby>-<run_id>-<attempt>` | Primary PR/main/manual candidate packages and manifest. The name does not imply installed qualification. |
| `release-candidate-ruby-<ruby>-<run_id>-<attempt>` | The single primary package set used by every release-candidate installed cohort. |
| `installed-evidence-ruby-<ruby>-<run_id>-<attempt>` | Per-cohort resolved lock and installed verification reports, including the actual loaded-native identity. |
| `diagnostics-ruby-<ruby>-<run_id>-<attempt>` | Source-check logs, including available failure diagnostics. |

Candidate payloads contain `thistle.gem`, `thistle-map.gem` when Map is present,
`Gemfile.lock`, `build-observation/thistle_native.so`, and `manifest.json`. Record
the immutable artifact ID and digest from the workflow summary, not only its
display name. PR/diagnostic artifacts default to 14 days; release-candidate
packages and installed evidence request 90 days, subject to repository policy.
Accepted evidence still needs the durable retention described below.

To check a downloaded candidate, set `THISTLE_CANDIDATE_DIR` to its extracted
directory and `THISTLE_CANDIDATE_SHA` to the expected full reviewed source SHA:

```sh
python3 .github/scripts/pipeline.py verify \
  --artifacts "$THISTLE_CANDIDATE_DIR" \
  --expected-sha "$THISTLE_CANDIDATE_SHA"
```

This checks manifest identity, bounded safe file paths, required payloads, and
hashes. It does not authenticate a candidate-owned manifest as an independent
verdict. The checkout native binary is a build observation; source-gem installs
compile a native binary whose actual identity belongs in each installed report.

The current source dependency graph resolves at build time because its lockfile
is not committed. Retained per-run/cohort locks describe what was tested; they do
not establish reproducible dependency resolution or package bytes. Follow the
[reviewed dependency-lock policy](decisions.md#dependency-locks-library-compatibility-feedback-and-exact-tested-resolutions):
retain the actual primary and installed-cohort locks with each candidate's
evidence, and keep cohort lock differences explicit rather than claiming a
universal lock. A committed development lock is not the selected policy.

## Artifact reuse and evidence

Build each candidate package once within its declared build context, then use
those exact bytes for installed verification, Map smoke, benchmarking, and any
later promotion. If an operation rebuilds a package, it creates a new candidate;
record its identity even if version strings and source commits are unchanged.

The evidence record must bind at least:

- Source head/tested merge and base identity.
- Package hashes and the native bytes actually loaded by each tested environment.
- Dependency, evaluator, policy, fixture/workload, and toolchain identities.
- Commands, result scope, run/attempt identity, failures, and relevant limits.
- The independently responsible acceptance decision where qualification is claimed.

Keep reports machine-readable and link them from the issue/PR. Retain failed
attempts and distinguish unavailable results from a pass. CI artifacts have
retention limits; accepted baseline and release evidence need durable retention
before an expiring download becomes their only copy. Do not expose captured
application source, secrets, or sensitive logs through general planning artifacts.

Caches accelerate disposable candidate builds; they are not qualified artifacts.
Use keys that include the relevant toolchain/dependency identity. A privileged
release operation must not restore or execute an untrusted PR's cache, build
script, or artifact merely because an upstream job reported success.

## Independent qualification contract

The separately versioned evaluator must remain outside the candidate's writable
policy and credential boundary. The trusted controller chooses the evaluator,
required lanes, policy, fixture, deadlines, and resource limits. It supplies exact
candidate artifacts to disposable least-privilege workers, validates bounded
outputs, and publishes a verdict bound to the tested identities.

The protected required result must come from an identity the candidate cannot
impersonate. Configure the expected GitHub App/source for that check and require
it through the applicable branch rules. Candidate-controlled job names and green
logs cannot stand in for this verdict. Track unavailable protected infrastructure
as unfinished Delivery work, while labelling local evaluation as bounded
development evidence.

Reviewer agreement cannot waive missing required evidence. A new candidate or
support scope requires requalification or an explicit reviewed applicability
decision; it must not inherit an old pass by version label alone.

## Experiment 001

Read the current baseline acceptance and experiment branch before scheduling any
work. Preserve the selected exact baseline, captured self-inspection source, and
frozen evaluator policy. Keep correctness fixes in both arms and the optimization
scope bounded. Charge cache admission and measure complete session cost.

Use the declared trial count, A/A calibration, primary timing metric, memory
guardrails, semantic equality, and recorded attempt budget. Keep, Reject, and
Unclear are all useful experiment outcomes. Do not rerun until a favorable result
appears, change thresholds after observing the candidate, or equate a successful
workflow run with an accepted speed improvement. Consult the recorded decision.

## Release flow

Keep preparation and publication separate so candidate iteration is fast and
publication has a clear, auditable boundary.

1. Choose the intended gem/Map versions and support scope. Follow the
   [changelog preparation guide](changelog.md#prepare-one-packages-release-notes)
   in a single-owner release-preparation branch: validate both pending note sets,
   consolidate the selected package's fragments with Towncrier, and review its
   version metadata and dated changelog. At the reviewed candidate SHA, verify
   that package has no pending fragments and has its matching version/date
   heading. The other package may retain valid pending notes. Open or update the
   release-check issue with the applicable L01–L17 rows and select the exact
   prepared source commit.
2. Produce a candidate package set and manifest through the non-publishing
   candidate flow. Record exact package, source, dependency, and build identities.
3. Qualify those packages with the independently controlled evaluator and all
   required installed/support/security/human-journey lanes. Development CI alone
   cannot satisfy the release decision.
4. Retain the package set, manifest, full evidence, provenance, and rollback plan
   durably. Resolve known blockers and obtain explicit release authorization.
5. A separately protected publishing operation verifies the authorized manifest
   and artifact origin, then publishes the same bytes using a narrowly scoped,
   short-lived identity where supported. It must not rebuild or execute candidate
   package code with publishing credentials.
6. Verify registry/package identities and supported installation after publication.
   Record the release result and follow-up defects without rewriting prior evidence.

Candidate preparation does not create a public release or a publishing identity.
The public license, supported package matrix, protected environment, publisher,
independent verdict, and release authorization must all be in place before that
last boundary is enabled. Preserve the gem's public-push block until an explicit
reviewed release change authorizes removing it.

## Security and administration

Use read-only permissions for candidate code, immutable third-party action pins,
non-persistent checkout credentials, and disposable workers. Treat package install
hooks and dependencies as executable candidate code. Keep branch/issue text out
of shell interpolation. Metadata automation needs narrow project/issue access,
not candidate execution or release secrets.

Do not execute untrusted PR code under `pull_request_target` or another privileged
context. New credentials, broader repository/project access, branch rules,
protected environments, and publication are administrative operations with their
own authorization and verification. A merged workflow file does not establish
that those controls are configured.

The authorized administrator should verify the intended required check source,
review requirements for the current diff, force-push/deletion restrictions,
private project/repository access, and protected release identities. Record the
actual settings and test the enforced paths; do not merely check a documentation
box. Keep the implementation task's claim separate from this administrative gate.

## References

- [Required checks and reviews in rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Secure use of pull_request_target](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target)
- [GitHub Actions security](https://docs.github.com/en/actions/reference/security/secure-use)
- [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/)
