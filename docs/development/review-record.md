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

## Remaining evidence and bounded follow-ups at the original review

- **At the initial review, hosted behavior had not yet run; see the follow-up below.** Local validation does not prove
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

## Follow-up: hosted source integration and whitespace scope

After the initial review, the owner merged restoration. Delivery
[PR #26](https://github.com/lost-in-the/thistle/pull/26) then incorporated restored
main `1b65f82ae8b8b693a8d7e8adb052b939b23bd5a9` through integration commit
`1737e1b6b81eced268dee510f0d4fe284a05983e`. The original integration notes above
remain historical; this follow-up does not claim the reviewer performed or
authorized that merge.

The reviewer inspected the jobs and metadata log for
[hosted run 40709002260](https://github.com/lost-in-the/thistle/actions/runs/40709002260).
Planning passed. All 28 automation regressions passed in 0.527 seconds, but the
subsequent `Changed-line whitespace` step failed. Its
`git show --format= --check HEAD` command ran against a shallow checkout and
treated inherited source, vendored files, and archived evidence as the commit's
new content. The logs show whitespace findings in preserved handoff evidence and
vendor/source files. This was an incorrectly scoped cosmetic check, not a
failure of the routing regressions.

**Disposition:** remove only that optional two-line step from `ci.yml`. Do not
rewrite vendored source or evidence archives to satisfy it. The planning,
automation, product, and required-result checks remain in place. This fixes a
concrete false failure without adding checkout/history cost to every metadata
job. The initial run remains a failed attempt; it must not be relabelled a pass.

The reviewer re-read the correction and reran the four-workflow actionlint
command recorded above with version 1.7.12: it passed without diagnostics. Hash
comparison confirms that only `.github/workflows/ci.yml` changed among the eight
reviewed automation files; script and regression-suite bytes were unchanged.
The revised `ci.yml` SHA-256 is
`ce2ea49c98f9a68f31e2298327d03c30a5cfd02ac44131b9a57fe055a03b46c1`.
Using the same combined-fingerprint algorithm, the corrected automation payload
is `bb864dcc83aa1f15ff8497bb2c18527877dbff08d9374a65300b5ec1f4f3d24f`.
It supersedes the original fingerprint for this correction; the original value
is retained as the identity of the first reviewed payload.

The reviewer subsequently confirmed the completed hosted job records. Primary
product job `122888952720` succeeded, including Rust tests, native compilation,
Ruby and Map checks, package creation, manifest verification, and artifact upload.
The resulting artifact was `12825785699`, named
`pr-candidate-ruby-3.3.13-40709002260-1`, with 15,086,581 bytes and GitHub artifact
digest `sha256:7c39a31ee21830995dc67223b43a4c91929f2c89f34c65da6c36a3242a4f3624`.
This artifact digest identifies the uploaded archive, not either individual gem
or an installed native binary.

The overall run and `CI / required` still failed because metadata failed. That
correct aggregate behavior is preserved; the successful product job does not
override it. The corrected commit still requires its hosted rerun. Record the
final commit, run, and result in the PR and [setup record](project-setup.md); the
new installed release-candidate and broad compatibility paths remain separate
evidence. A single hosted product result does not establish a general CI speedup.

The follow-up guidance also assigns one writer to each shared mutable UI resource.
This addresses the observed cross-tab automation collision: separate tabs are
not treated as isolated sessions. The reviewer inspected the added agent and
workflow guidance; it preserves parallel independent code/read work while making
UI ownership and handoff explicit.

## Follow-up on 2026-10-28: avoid a duplicate run on review readiness

The reviewer independently confirmed that
[run 40711863879](https://github.com/lost-in-the/thistle/actions/runs/40711863879)
completed successfully for PR head
`1792d6499e9806b32f62659bc343f1e894d4b6a3`: planning, automation, primary product,
and `CI / required` all passed. This resolves the preceding pending rerun for
that head only. The integration owner recorded 174 seconds overall elapsed;
that is one observed workflow duration, not a comparative performance result.

Marking the PR ready then started
[run 40712558262](https://github.com/lost-in-the/thistle/actions/runs/40712558262)
on the same PR head. The reviewer confirmed both runs are associated with that
commit and that the second had already restarted native product work. Its final
outcome was not established by this review. The readiness event changed review
metadata without introducing a new source revision, so repeating the full
product lane added avoidable feedback and runner cost.

**Disposition:** remove only `ready_for_review` from `pull_request.types`.
`opened`, `synchronize`, and `reopened` remain, as do main pushes, merge groups,
and manual dispatch. There is no draft guard in the PR or reusable product
workflow: draft creation and source updates already receive the applicable
checks. All jobs, routing, permissions, concurrency, and required aggregation
remain unchanged. Comparing the local file with the committed file at the
successful head confirmed this exact one-event change.

Review readiness is consequently not a retry or fresh validation signal.
Missing, cancelled, or failed checks require an explicit rerun or applicable
update; a moved base still needs the appropriate integration validation. The
change cannot turn missing evidence into a pass.

Independent focused validation ran
`/tmp/thistle-actionlint/actionlint .github/workflows/ci.yml` with actionlint
1.7.12 and passed without diagnostics. The regression and product implementation
bytes did not change, so no new test suite or repeated local product campaign was
added for this event-only correction.

The updated `ci.yml` SHA-256 is
`1745d7206cd8768e39d49a073d0e711b6d2c0f5490e6b40a7a4d18da2357d74f`.
The eight-file automation fingerprint, using the same algorithm above, is
`3a69297adf0cd6a6c5188f932b43facb12ceeaa16ebe7abd194c1c222dbb7a1b`.
Reinserting only the removed event reproduces the preceding
`bb864dcc83aa1f15ff8497bb2c18527877dbff08d9374a65300b5ec1f4f3d24f` fingerprint.
Both older identities remain historical evidence.

**Review disposition:** no blocker in this bounded event change. Its new commit
does not yet exist in this review record and is not covered by the successful
`1792d6499e9806b32f62659bc343f1e894d4b6a3` result. The integration owner will commit
the correction and verify its required CI before reporting the new head green.

## Follow-up on 2026-10-28: current cohorts and independent release notes

The owner challenged the inherited Ruby/Rails default and requested deliberate
tool selection and conflict-free release notes. This review covers that expanded
delivery change before its next commit. Earlier run, artifact, and payload
identities above remain historical evidence; none is reassigned to the new
cohorts. The integration owner reports PR #26 still open and unmerged at
`eafc73bb89781851d630c3b3d83fddab6385934e` against restored main
`1b65f82ae8b8b693a8d7e8adb052b939b23bd5a9` while preparing this revision.

### Scope and findings

The reviewer inspected the complete proposed delivery payload, including the
shared CI policy, five workflows, routing/aggregation and installed-artifact
scripts, action inventory, dependency maintenance configuration, Towncrier
configuration/lock/guard/tests, both gemspecs, development Gemfile, changelogs,
Map test import, README files, agent/contributor guidance, PR template, and
development decision/release/setup documents.

The integration owner will also remove the duplicate lowercase
`.github/pull_request_template.md`. The reviewer fetched that file at the
pre-update PR head (Git blob `d05711cee0438e1ce6fb9118209083c1b30b8060`)
and compared it with the canonical uppercase template. The recovery/rollback,
evaluator-policy ownership, evidence identity, scope and review prompts remain
represented in the uppercase version. This is a deliberate deletion in addition
to the regular-file payload below; it is not an accidental case-only rename.

| Finding or design risk | Reviewed disposition |
|---|---|
| An accepted historical tuple had become a new project's default without a current support rationale. | The decision record cites current upstream maintenance. One validated JSON policy selects Ruby 4.0.9 / Rails 8.1.4 as primary and Ruby 3.4.12 / Rails 8.1.4 as minimum; both gemspecs now require Ruby >=3.4. The Gemfile reads the policy's primary Rails requirement and retains an explicit cohort override. Linux remains the actual platform restriction. |
| A second selected cohort could be omitted, cancelled, or fail while an aggregate appeared green. | The planner constructs explicit primary/minimum rows; its schema and exact patch inputs are validated before routing. Negative tests reject missing/duplicate minimum rows, extra package builds, failed/skipped/cancelled product work, and missing planning/metadata results. The product matrix uses `fail-fast: false`, no `continue-on-error`, and an always-present aggregate that requires matrix success. |
| A broad matrix could repeat expensive work without testing a distinct boundary. | Ordinary Rust-internal PR changes use primary; Ruby/native, dependency, policy, workflow and unknown control changes select both. Both names of a rename are retained. Main runs primary in CI and minimum in Compatibility; weekly/manual broad checks run both. Rust-only unit tests run once on primary, while every selected Ruby row still compiles its own bridge and runs applicable Ruby/Map checks. |
| Release cohort selection or package rebuilds could weaken exact-byte verification. | The release workflow reads cohort policy from its workflow-driver checkout, prepares one source-gem pair, and supplies that immutable artifact ID to both installed rows. Per-install native identity remains separate from the checkout build observation. Candidate orchestration still establishes no protected qualification or publication authority. |
| Old action runtime declarations had survived full-SHA pinning and green CI. | Updated checkout/upload pins and the pin inventory declare Node 24; the integration owner independently fetched all four exact action definitions. Dependency automation proposes reviewed updates without auto-merge. Immutable downloads, digest rejection, read-only permissions and nonpersistent credentials remain. |
| Towncrier's native reader follows paths and replaces invalid UTF-8. | A small precheck rejects linked/non-regular/nested inputs, checks ancestor directories and output files, and requires nonempty strict UTF-8. It keeps the reviewed flat input/output/template configuration. Native Towncrier remains responsible for filename/category parsing, duplicate detection, ordering, rendering and consumption. |
| Parallel notes or a one-package release could collide or consume another package's pending work. | One shared native configuration supplies ten categories; core and Map have separate directories and consolidated histories. Native numeric counters distinguish parallel same-issue/category notes. Real CLI tests prove nonmutating drafts and package-specific consumption in a temporary Git repository. |
| A release-note fragment claimed a production Map query-link change that was not implemented. | Corrected to the actual test-only `require 'cgi/escape'` change for `CGI.unescapeHTML`. No production Map behavior is claimed to change. |
| A failed preparation precheck could be followed by a successful diff command and mask the pasted block's exit status. | The guide now keeps `git diff --cached` inside the successful `set -eu` subshell. Both package prechecks precede any fold. The guide explicitly distinguishes prevalidation from crash-atomic writes and requires one branch/index owner. |

Both gemspecs include their own `CHANGELOG.md`; the planner rejects removal of
required core or Map changelog files. Note/config/guard-only PRs stay in metadata
checks. A script or unknown product/control path does not gain that exemption.
The notes tool and its three dependencies stay outside the runtime gem contents.

The historical baseline lane refuses current-policy source before tool setup.
Experiment 001's separate branch, selected packages, environment and evaluator
policy remain unchanged. A new Ruby >=3.4 gem cannot be substituted into its
Ruby 3.3 environment and labelled a replay. The explicit parser-language policy
is a documented product follow-up; this change does not alter Prism semantics.

### Independent validation of this revision

After both authors froze their code, the reviewer ran the complete suite once
from the delivery payload directory:

| Command | Tool/version and observed result |
|---|---|
| `/tmp/thistle-notes-venv/bin/python -B -m unittest discover -s tests/automation -v` | CPython 3.12.14; all **46 tests passed** (37 pipeline and 9 notes tests), 4.075 seconds reported by unittest; 4.149 seconds tool wall time. |
| `/tmp/thistle-actionlint/actionlint .github/workflows/ci.yml .github/workflows/product-checks.yml .github/workflows/compatibility.yml .github/workflows/release-candidate.yml .github/workflows/hardened-baseline.yml` | actionlint 1.7.12; passed with no diagnostics. |

The reviewer inspected the installed tool versions: Towncrier 26.9.0, Click
8.5.0, Jinja2 3.1.6 and MarkupSafe 3.0.4. The notes author separately verified
their fresh wheel-only `pip install --require-hashes` from the committed lock;
this review reused that environment rather than downloading the same packages
again. The notes tests execute the actual Towncrier CLI, including all ten
categories, deterministic drafts, duplicate/category rejection, UTF-8 and
filesystem failures, package-specific real folds, preservation of the other
package, and unchanged files/index when prechecks fail.

These are local automation and configuration results. **Hosted Ruby 4.0.9 and
3.4.12 product runs, modern installed release-candidate verification, and hosted
latency/resource measurements are not established by this review.** No native
product build or frozen performance campaign was rerun locally. The first new
hosted run must retain its exact candidate, resolved dependencies, annotations,
job results, artifact identities and cost. No comparative speed claim is made.

### Frozen payload identity and review conclusion

Using the fingerprint algorithm defined above, the original eight-file
automation subset now hashes to
`4dadec7a41b223913d19cf5e6846affa4e23b133f42d354ddbe5a9e77f5bac27`.
The expanded **41-file** reviewed payload hashes to
`5cccb3fb004bd7304810dfc8808629c74ddcd78b7fd9b86a870c21736b79b791`.
Its exact membership is:

```text
.github/ISSUE_TEMPLATE/01-work.yml
.github/ISSUE_TEMPLATE/02-bug.yml
.github/ISSUE_TEMPLATE/03-experiment.yml
.github/ISSUE_TEMPLATE/04-check.yml
.github/ISSUE_TEMPLATE/config.yml
.github/PULL_REQUEST_TEMPLATE.md
.github/ci-policy.json
.github/dependabot.yml
.github/requirements-notes.txt
.github/scripts/action-pins.json
.github/scripts/check-notes.py
.github/scripts/installed-check.sh
.github/scripts/pipeline.py
.github/workflows/ci.yml
.github/workflows/compatibility.yml
.github/workflows/hardened-baseline.yml
.github/workflows/product-checks.yml
.github/workflows/release-candidate.yml
AGENTS.md
CHANGELOG.md
CONTRIBUTING.md
Gemfile
README.md
changelog/26.build.md
changelog/26.changed.md
changelog/README.md
docs/development/agent-workflow.md
docs/development/changelog.md
docs/development/decisions.md
docs/development/pr-ci-release.md
docs/development/project-setup.md
map/CHANGELOG.md
map/README.md
map/changelog/26.changed.md
map/changelog/README.md
map/test/highlighter_test.rb
map/thistle-map.gemspec
tests/automation/test_notes.py
tests/automation/test_pipeline.py
thistle.gemspec
towncrier.toml
```

This record itself is excluded to avoid self-reference. Python caches and the
four obsolete root handoff copies in the local staging directory are excluded;
the restored `docs/handoff/` paths remain canonical and those copies must not be
reintroduced by this delivery update. The fingerprint identifies reviewed file
bytes, not a Git commit or a hosted result. It covers the 41 present files; the
separate lowercase-template deletion is identified by path and original blob
above and does not contribute nonexistent file bytes to this hash.

**Review conclusion:** the CI author, notes author and independent reviewer have
converged on the bounded approach, with the concrete findings above resolved.
No blocking implementation finding remains for committing and verifying this PR
update. This is shared-session agent consensus, not maintainer approval, merge
authorization, protected independent qualification, or production acceptance.
Modern hosted product evidence and the separately authorized release/qualification
controls remain outstanding; previously green historical runs do not cover them.

## Follow-up on 2026-10-28: modern hosted result and Map homepage metadata

The reviewer read the completed run and job records for
[run 40718920736](https://github.com/lost-in-the/thistle/actions/runs/40718920736).
It succeeded for PR head `e5887c6c1b74f6adbf2991faab85c0455d2d412e` against
base `1b65f82ae8b8b693a8d7e8adb052b939b23bd5a9`. The primary build's manifest
log identifies the actual tested merge checkout as
`fd7122f385caf87c9d7875d265296d92a1ade72e`; the PR head is not substituted for
that source identity.

Planning, automation, primary Ruby 4.0.9, minimum Ruby 3.4.12, and
`CI / required` all succeeded. The reviewer read the automation log confirming
all 46 tests passed in 2.509 seconds. Both product jobs compiled their native
bridge and passed Ruby/Map checks; primary additionally ran Rust invariants and
prepared the candidate packages. The integration owner separately reported zero
check annotations. These are successful modern development-cohort results for
that revision, not installed release-candidate or protected qualification.

The primary log nevertheless contained `WARNING:  no homepage specified` during
the Map gem build. The reviewer confirmed the warning's Map-build context and
compared the two local edits with the files fetched at the exact PR head above:

- `map/thistle-map.gemspec` adds only
  `spec.homepage = 'https://github.com/lost-in-the/thistle'`.
- `map/changelog/26.changed.md` adds one sentence describing that metadata field.

The URL is the canonical repository already used by this project. The change
adds no runtime behavior or permissions, and the note matches the implementation.
No new local test suite, gem build, or workflow lint run was performed for these
two plain metadata/text additions; the actual review checks were source
comparison, hosted-record/log reads, and fingerprint calculation.

| Updated file | SHA-256 |
|---|---|
| `map/thistle-map.gemspec` | `da3ab30af5431e19fd7ba555a4fd5ad18631941291c58d5245d1c1dae90a8431` |
| `map/changelog/26.changed.md` | `8b363b15e7a2be819657a4645cdf726336d716ab1221ea2f6f917ae3a656b2c4` |

The same 41-file payload now hashes to
`9b78c384bc59259b1122b27db6412cb030c7d09b7ee5c30d8f07932b9330c87f`.
Removing only those two added lines reproduces the preceding
`5cccb3fb004bd7304810dfc8808629c74ddcd78b7fd9b86a870c21736b79b791`
fingerprint. The eight-file automation subset is unchanged. The exclusions,
separate lowercase-template deletion, and non-authorization limits above remain.

**Disposition:** no blocking finding in this metadata correction. The successful
`e5887c6c1b74f6adbf2991faab85c0455d2d412e` run is retained as evidence for its
own bytes. The homepage changes package metadata and therefore creates a new
candidate; its commit and required hosted check are still pending at this review.
The integration owner will record that new head and result separately.
