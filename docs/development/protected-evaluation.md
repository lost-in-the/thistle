# Protected evaluation: design and owner decisions

This is the bounded design proposal for [issue #23](https://github.com/lost-in-the/thistle/issues/23).
It prepares a deployment decision and a proof procedure. No controller, repository,
App, credential, rule, purchase or enforcement proof has been created by this PR.
The repository owner can accept the proposal; the independent qualification owner
and role have **not** been approved. Root owns integration and independent review.
Issue #23's external authority and proof remain **Check / Evidence Needed**.
All 17 [launch capabilities](../capability-ledger.md) remain unqualified.

## Recommendation and decisions

On the current public Free organization, propose an independently controlled
controller with a distinct GitHub App publishing `Thistle qualification / required`.
Use GitHub Actions for orchestration and maintained token/runtime tooling. No
custom webhook service is needed: begin with the named custodian's manual
dispatch, using immutable request identities. Dispatch requires controller
repository write access and is not granted to candidate authors. Lack of a dispatch blocks
qualification. Automatic request discovery can be separately reviewed later.

Prefer native source-bound organization required workflows if the owner explicitly
chooses an eligible Team or Enterprise plan and public workflow source. That avoids
a custom publisher App/key, but does not solve worker isolation or shared authority.
A same-name job from the ordinary GitHub Actions App is not source binding.

The owner decisions below are the final authorization step after independent design
review. Suggested names and settings are proposals, not allocated identities.

| Decision | Concrete proposal | Missing approval or value |
| --- | --- | --- |
| Independent authority | Name a qualification custodian and a separate policy reviewer; candidate authors have no controller/policy write or publisher-key access. Owner administration remains human-controlled, outside agent sessions. | Named people, their accounts, backup custodian and authority boundary |
| Candidate authoring | Use a restricted authoring identity such as existing `lost-in-the-agent` with Thistle write only; remove owner credentials from candidate-authoring sessions before claiming independence. | Owner-approved credential separation and verification; no account switch or permission change in this task |
| Evaluator home | Proposed `lost-in-the/thistle-eval`, private for the Free/App route, selected-repository access only; no candidate agents or authoring connectors installed there. Public Free plus the same distinct App is also an option: repository rules can enforce policy review without buying Team, and standard public hosted minutes are free. | Name availability, creation, visibility, actual repository ID and access list; public source/fixture disclosure and a restricted evidence destination need approval; organization inherited/base access must also be checked |
| Enforcement route | Current Free: distinct proposed `Thistle Qualification` App, only Thistle installation, Checks write, Metadata read, Pull requests read and Contents read for head/base/tree verification; all other permissions off. | App name availability, numeric App ID, client ID, installation ID and custodian approval |
| Key custody | App key in custodian-controlled vault and only the private controller repository's publisher secret; no organization-wide secret, candidate secret, developer checkout or worker copy. | Actual approved vault/access list and publisher secret configuration; no key material belongs in this document |
| Native alternative | If eligible plan is chosen, public evaluator workflow source in the organization, pinned repository ID/path/SHA; same independent writers and worker boundary. | Plan purchase/entitlement, public disclosure approval and actual workflow identity |
| Repository rules | Active rule on exact `refs/heads/main`, no bypass actors, PR and current-base testing required, exact trusted source mandatory; details below. | Separate owner authorization and actual rule ID/readback |
| Initial scope | Same Core/Map source-gem bytes installed on both modern Linux cohorts, with installed contracts, parser-worker, reader-boundary and Map checks. | Independent approval of adapter, fixtures, policy, observer coverage and measured limits |
| Operating budget | One request at a time, two sequential cohorts, no paid overage or larger runner until separately approved; retain proof/qualification records before artifact expiry. | Account billing/quota, storage/retention location and cap, operational time budget |
| Observer feasibility | Propose at most one engineer-day and two maintained-runtime prototypes before a new decision; define the exact load-observation claim and negative controls first. | Approved time/cost cap, collector/archive totals and durable capacity; stop with readiness Needed if coverage cannot be demonstrated within the cap |

If the same owner credentials remain available to authoring agents, no second
repository, reviewer agent or job makes this independent. The custodian must
verify effective access, including organization owners, teams, installed Apps,
workflow writers, secret users and recovery paths. A human owner can retain
emergency administration, but an agent with those credentials is inside that
administrative boundary. This is a prerequisite, not a claim of current separation.

## Current evidence and limits

Read-only REST inspection on October 28, 2026 found:

| Fact | Observation |
| --- | --- |
| Candidate repository | `lost-in-the/thistle`, ID `1437113504`, public, default branch `main` |
| Provided branch/worktree | `t3/protected-evaluation-design` in the tool-provided isolated worktree |
| Local base and live remote main before writing | `3ed85afd4d9569b4b46086c55672bc7c1e3ea9b7` |
| Organization plan | `free` |
| Current CLI actor | `LeahArmstrong`, active organization admin; Thistle admin permission |
| Existing authoring account | `lost-in-the-agent`, Thistle `write` |
| Rules | Repository rulesets `[]`; effective rules for main `[]`; branch protection GET `404`; branch says `protected: false` |
| Current check source | `github-actions`, App ID `15368`, including `CI / required` |
| Project metadata | GraphQL rate limit reported by root; issue claim recorded through REST; metadata sync pending |

These are dated observations, not durable guarantees. No tokens, secret values or
PII configuration were read. No fetch was needed: the remote branch was inspected
explicitly through REST, rather than inferred from a cached tracking ref.
[Earlier #23 research](https://github.com/lost-in-the/thistle/issues/23#issuecomment-6475927851)
recorded a private repository and 403 responses; the
[public-state refresh](https://github.com/lost-in-the/thistle/issues/23#issuecomment-6477848280)
supersedes that platform restriction. Public Free supports repository rules;
it does not provide organization required-workflow entitlement.

The bounded work in #20, #24, #31 and #35 is integrated. Existing
[run 40753315478](https://github.com/lost-in-the/thistle/actions/runs/40753315478),
at source `aa07413eaac4b3d37a015ad11e9ba626b372c4c8`, attempt 1, completed
successfully. [Root's recorded audit](https://github.com/lost-in-the/thistle/pull/37#pullrequestreview-5688492799)
verified the actual ZIP/package bytes and both installed cohorts. This design does not repeat that audit or relabel its artifacts as current
main. The actual installed native and dependency binaries were not retained in
that evidence: reported hashes cannot reconstruct or independently rehash them.
Build-observation native bytes are not the per-cohort installed native bytes.

Historical [restoration](../handoff/RESTORATION.md),
[baseline acceptance](../handoff/BASELINE_ACCEPTANCE.md) and the
[evaluator handoff](../handoff/EVALUATOR_HANDOFF.md) supply provenance and test
intent, not current protected authority. [Experiment 001](../experiment-001.md)
and its attempts, selected packages, policy and result remain unchanged.

## Maintained alternatives and maintenance cost

| Option | Fit now | Cost, limits and reconsideration |
| --- | --- | --- |
| Native organization required workflow | Best source binding when an eligible Team/Enterprise plan is deliberately selected. Select an actual source repository/workflow, not a job name. Public Thistle requires public workflow source. | Plan and public disclosure decisions; no App-key rotation/custom check publisher. Still needs protected policy, safe candidate execution and proof of freshness/complete results. Prefer this if the owner accepts those decisions. |
| Free repository rule plus distinct App | Fits current public Free repository; rule binds check context to actual App ID. Controller runs separately; only publisher gets App token. | Small policy adapter/publisher maintained by custodian, App-key rotation, Actions/image updates, billing/retention and recovery. Proposed route, not deployed. Reconsider if native entitlement is approved. |
| Candidate workflow, reusable workflow call, or same-name `github-actions` check | Useful development feedback only. Candidate can change caller/conditions or create a lookalike with App `15368`. | Does not establish independent source or verdict; rejected as the qualification boundary. |
| New webhook service or bespoke sandbox | No demonstrated need for initial manual request volume. | Adds exposed service, authentication, retries, queue and patching burden. Reconsider only after measured orchestration/runtime limitations. |

GitHub documents [organization rules on Team/Enterprise](https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization)
and the [June 2025 Team rollout](https://github.blog/changelog/2025-06-16-organization-rulesets-now-available-for-github-team-plans/).
The [required-workflow rules](https://docs.github.com/en/enterprise-cloud%40latest/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
describe source selection and visibility restrictions. An API `workflows` schema
alone is not evidence of the current account's entitlement. Ordinary
[repository rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
are available for public Free targets. Sources checked October 28, 2026.

Reuse [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)
for short-lived installation tokens, explicitly restricted to `lost-in-the/thistle`
and the publisher's required permissions; keep its post-job revocation enabled.
Do not inherit all installation repositories or permissions. Use the maintained
GitHub CLI/REST client for bounded API calls. At implementation review, pin the
chosen release's full SHA and verify its declared runtime and runner compatibility;
this document selects no unverified action pin. The publisher needs only Checks
write and read access for final identity verification, never Contents write,
Administration, package publishing or release permissions. Downloading candidate
Actions artifacts, if later chosen, requires a separately assessed Actions read
permission; it is not silently added here.

This is a proposed choice record. On authorized adoption, the integration owner
should index the accepted choice in [development decisions](decisions.md).
This bounded PR does not edit that shared file or install tooling.

## Controller, worker and publisher ownership

The controller's protected default branch owns request validation, policy,
fixtures, expected results and the worker adapter. Candidate paths cannot select
lanes, evaluator revisions, images, result destinations or shell commands.
Manual dispatch accepts a PR number and full expected head/base SHAs, not a URL
or executable input. It reads GitHub's actual PR/head/base and tested merge,
rejects conflicts/mismatches, and gives the request an immutable attempt ID.
For the proposed private evaluator on Free, “protected” here means an exclusive
custodian write/access boundary, **not** an available private-repository branch
rule. The reviewer supplies a recorded disposition; the sole human custodian
promotes the reviewed SHA. GitHub does not technically enforce that two-person
review on this proposed private Free setup. If the owner requires enforced policy
reviews, choose public evaluator visibility with repository rules, or an eligible
paid plan, before activation. Neither alternative is approved. Record and prove
all effective writers; candidate-authoring credentials must reach none of them.
Only reviewed controller code is dispatched. No candidate workflow
completion event or artifact name alone authorizes a result.

Use separate disposable hosted jobs for admission, preparation/execution and
final publication:

1. A trusted admission job uses the publisher's existing narrowly scoped App
   authority, without checking out or executing candidate code. Before admitting
   any required attempt, including a retry or policy change on the same head/base,
   it establishes and reads back a blocking state for the canonical trusted check.
   It must verify that no earlier success or duplicate check still makes that
   request eligible. Revoke this short-lived token before worker dispatch. Failure
   to establish or verify the blocking state prevents dispatch and policy
   activation; requesting a retry alone does not invalidate an existing success.
   If an earlier result must be withdrawn but cannot be invalidated, the custodian
   must freeze integration through the approved recovery control before proceeding.
2. A trusted preparation job resolves approved tool/dependency/image digests,
   source and tested-merge identity using bounded downloads. It emits an immutable
   input manifest. No candidate build, gemspec or install hook runs in this job.
3. A fresh execution VM launches the unprivileged candidate runtime. Build one
   Core/Map package pair from the selected tested source in isolation, collect it
   as untrusted bytes, and install those exact bytes on both cohorts. A controller
   supervisor outside the runtime owns expected facts, deadlines and verdicts.
   The frozen evaluator must use the protected adapter for **every** subprocess;
   importing its old host-execution helper unchanged is not safe.
4. The supervisor validates bounded observations against independently held
   expectations and records all attempts. Candidate test scripts, exit-zero,
   `pass` text and self-reported hashes are evidence inputs, never the verdict.
5. A different fresh publisher VM reads only the controller-owned result envelope
   from the exact approved run/workflow/attempt. It verifies the artifact ID and
   digest, schema and complete required cohort set, then re-reads current head,
   base and merge identity. It never checks out or executes candidate code,
   loads a candidate plugin, evaluates a template or sources a report as shell.
   Only after these validations may it obtain a separate narrowly scoped App token
   for final success publication. The earlier admission token is not reused.
   Interrupted or failed final publication leaves the verified admission state
   blocking; a complete final result is required to replace it with success.

Neither the controller's owner/policy credentials nor the publisher key/token is
present on the execution VM. Candidate processes receive no GitHub, owner, SSH,
policy, publisher, release or artifact-upload credentials. Runner service tokens
stay outside the candidate runtime; escaping that runtime could corrupt evidence,
so isolation failure invalidates the entire run even though the publisher is
separate. No mutable candidate cache is trusted across attempts or promoted to
publication. Result transfer uses the trusted supervisor's fixed output directory,
not a candidate-selected path or a candidate-uploaded “trusted” artifact.

## Initial qualification and byte evidence

Initial scope is Ubuntu 24.04 Linux x86-64 source installs on Ruby 4.0.9 and 3.4.12,
both Rails 8.1.4, as currently declared in [CI policy](../../.github/ci-policy.json).
The protected policy must approve and pin its own cohort snapshot; changing the
candidate's CI policy cannot silently change qualification. Both cohorts install
the same Core and Map gem bytes. Native builds may differ by Ruby ABI and build
path: retain and verify each actual installed result, without claiming deterministic
rebuilds. Other OS/ABI/precompiled routes, full launch capability coverage and
performance are outside this first scope.

Reuse evaluator commit `b81f5adc2c647083b6ce8688234012c6d2da0ee4`, from bundle
SHA-256 `7d24cf43a1ca1c57456d2a009e70bec8cfea10895aff5f981c92ab448e6acb2d`,
through an independently reviewed adapter and new modern qualification policy.
Verify the bundle and commit before extracting it. Preserve the frozen evaluator
and Experiment 001 policy; record the adapter separately. Port the installed
public contracts, parser-worker probe, reader-boundary probe and installed Map
integration/smoke expectations under protected authority. Independently review
expectations and deliberately defective candidates; do not trust the candidate's
`tools/qualify_baseline.py` or `map/test/installed_smoke.rb` to decide success.
The parser's declared grammar, real Rails facts, generation/mutation/refusal
behavior and no-Woods/no-checkout-load requirements remain observable contracts.

The trusted manifest must bind at least:

| Identity | Required retained evidence |
| --- | --- |
| Source | Repository ID, PR, full head SHA, base ref/SHA, tested merge SHA/tree and parent identities; controller workflow SHA and request ID |
| Packages | Actual ZIP/archive bytes if used, actual Core/Map gems and digest inventory; bounded extraction with path/symlink/type/size checks |
| Installed execution | Per-cohort complete installed files, actual built extension and loaded dependency binaries, runtime libraries; trusted observed loads and immutable file/object identities linked to retained bytes |
| Environment | Resolved dependency lock and actual dependency gems; Ruby/Rails, OS image digest, kernel, compiler/linker/libclang, Cargo/Rust and flags; actual tool bytes or recoverable content-addressed artifacts |
| Evaluation | Frozen evaluator/bundle, adapter, policy, fixtures, expected facts, workload, lane set, observer/runtime versions and configuration digests |
| Attempts | Workflow/run/job/attempt IDs, command/exit/signal/deadline, raw bounded observations, truncation/loss flags, resource use, prior failures and cleanup results |
| Verdict | Protected result-envelope digest, complete cohort/lane inventory, exact check ID/source/conclusion, independent reviewer disposition and explicit limitations |

Collect install outputs only after stopping all build descendants. The trusted
supervisor hashes and copies actual regular files into a new immutable evaluation
root. Mount packages, toolchain and installed libraries read-only for tests;
provide separate bounded writable fixture/snapshot directories. Verify immutability
again after tests. Do not follow candidate symlinks or paths out of the collection
root, parse executable metadata, or copy a live tree subject to candidate writes.
Archive native/dependency bytes before destroying each VM and before hosting
retention expires, following the [retention guidance](pr-ci-release.md).

### Loaded-native observation is still a readiness gate

A retained `.so` proves its bytes were collected, not that every tested process
loaded it. Ruby `$LOADED_FEATURES`, `dlopen` wrappers, candidate hash text and a
sample of `/proc/.../maps` can miss short-lived loads, descendants, unlinked files,
anonymous executable mappings, replacement or modified executable pages.
Do not claim they establish complete observation.

| Maintained option | Useful role | Unproven coverage and operating cost |
| --- | --- | --- |
| Host-supervised [strace](https://strace.io/) from process creation, following descendants | Diagnostic trace of exec/open/mapping syscalls; easier bounded initial coverage experiment than a custom tracer | Paths/syscalls alone do not bind every mapped byte or modified page. Must cover fork/clone/exec, FD passing, memfd, unlink/rename, mapping and protection changes. Tracing adds overhead; measure it. |
| [gVisor runtime monitoring](https://gvisor.dev/docs/user_guide/runtimemonitor/) plus sandbox runtime | Maintained isolated syscall implementation and event stream outside the application | Establish event coverage, loss behavior, library identity resolution and Ruby/native/build compatibility first. It is not automatically complete load attestation. Runtime/image/kernel maintenance and overhead remain. |
| Periodic process maps or in-process loader reports | Supplementary debugging and cross-checking | Races and tampering prevent authoritative qualification. Rejected as sole observer. |

Propose a bounded feasibility proof of a host-controlled tracer over an immutable
installed root first. Restrict executable file origins to that root and the pinned
runtime; disable optional JIT execution for the initial scope. Any unsupported or
unattributable executable mapping, observer loss, untracked descendant or mutable
native mapping fails qualification. Enforcing and observing those restrictions
requires implementation proof; a mount flag alone does not do it. The protected
review must explicitly resolve native-page modification, anonymous execution and
in-process assertion spoofing. Until then, rule-identity proof may pass while
**full qualification worker readiness remains Needed**. There is no synthetic
“all loads verified” result in this proposal.

Before this feasibility work starts, approve its finite time/cost cap and precise
coverage claim, collector/archive totals and durable storage capacity. The proposed
one-day/two-prototype limit is not authorization. If a required negative control
cannot be observed and rejected within the cap, stop with readiness Needed and
return the evidence and alternatives for an owner decision. Do not expand into an
unbounded custom tracer or silently weaken the qualification claim.

## Isolation and measured limits

Propose disposable standard Ubuntu hosted VMs with rootless Docker and a non-root
candidate UID, read-only root, private PID/mount/user namespaces, no network,
all capabilities dropped and no-new-privileges. Keep the seccomp profile enabled;
never mount the runtime socket, host home, host PID namespace, writable evaluator
or credentials. Mount only declared inputs read-only and bounded scratch/output
volumes. Tool/dependency downloads happen before candidate execution. No privileged
container, shared self-hosted machine or candidate-selected image is proposed.
The [Docker rootless model](https://docs.docker.com/engine/security/rootless/)
reduces daemon privilege; it is not a separate kernel.

Verify cgroup v2/systemd delegation and actual CPU, memory and PID enforcement:
[Docker documents](https://docs.docker.com/engine/security/rootless/tips/#limiting-resources)
that rootless resource flags can be ignored without the required setup. Use a
supervisor-created quota-backed scratch filesystem, not just a free-space check.
The observer stays outside candidate namespaces with only its required host-side
privilege. If Docker's shared-kernel boundary cannot meet the threat model or
observer requirements, assess [gVisor](https://gvisor.dev/docs/architecture_guide/security/)
before inventing a runtime. Do not silently fall back to an unsandboxed worker.

| Proposed trial limit | Status and required measurement |
| --- | --- |
| 2 CPUs, 6 GiB memory, 256 PIDs | Unmeasured. Record peak build/install/test use and demonstrate enforcement including descendants; VM must also have headroom for runner/supervisor. |
| 8 GiB scratch per worker | Unmeasured. Include dependency unpacking, compilation, traces and evidence; test inode and disk exhaustion as well as bytes. |
| 30 minutes total per worker | Unmeasured. Pin per-command deadlines in policy, retain existing probe deadlines, and include cleanup allowance outside candidate time. |
| 16 MiB combined stdout/stderr per command | Unmeasured. Cap while streaming, terminate on overflow, mark incomplete; bound trace/event/archive/schema totals separately before readiness. |
| One request; two sequential cohorts | Initial concurrency proposal. Measure queue delay, elapsed time and total VM minutes before increasing it. |

A deadline or cancellation kills the entire container/cgroup, drains bounded
output, checks that no descendants remain and destroys the VM. Cleanup failure
fails the attempt; the next request gets a fresh VM. Record observer loss, OOM,
PID/disk limit, timeout and truncation as explicit failures, not partial passes.
No latency, isolation or cost improvement is claimed without measurements.

## Exact rule proposal

Configure nothing until the owner authorizes the chosen route and actual source
identity exists. The following is an intentionally **non-executable template**
for a Free repository ruleset, based on the [REST schema](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset).
The unquoted App-ID placeholder prevents accidental submission as valid JSON.
Do not replace it with null, zero, `-1`, App `15368`, or omission/“any source”.
Validate the actual numeric App ID against installation and observed check JSON.
The current UI documentation describes additional status-source selection
conditions. Prove that the Checks-write-only App can be bound through the rules
API and read back correctly. If GitHub requires more permission for the chosen
path, stop for a specific owner decision; do not silently grant Statuses write,
weaken source binding or claim the proposed minimal permissions are proven.

```text
{
  "name": "Thistle protected qualification",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews_on_push": true,
      "require_code_owner_review": false,
      "require_last_push_approval": true,
      "required_review_thread_resolution": true
    }},
    {"type": "required_status_checks", "parameters": {
      "strict_required_status_checks_policy": true,
      "do_not_enforce_on_create": false,
      "required_status_checks": [
        {"context": "Thistle qualification / required",
         "integration_id": <ACTUAL_INDEPENDENT_APP_ID_REQUIRED>}
      ]
    }}
  ]
}
```

This adds a qualification requirement; existing candidate CI remains feedback
and must not be relabeled. Reconcile any rules added by others at deployment,
rather than replacing them. All applicable rules must pass. No ordinary bypass
is proposed, including for owner/admin roles or publisher. Admins able to edit
rules remain part of the separately controlled administrative trust boundary.

If native organization required workflows are chosen instead, scope the rule to
repository ID `1437113504` and exact `refs/heads/main`, active, with no bypass.
Require the source tuple below through the organization `workflows` rule, with
`do_not_enforce_on_create: false`. Retain PR/review/deletion/force-push protections.
Use the [organization rule schema](https://docs.github.com/en/rest/orgs/rules#create-an-organization-repository-ruleset):

```text
repository_id: <ACTUAL_PUBLIC_EVALUATOR_REPOSITORY_ID_REQUIRED>
path: .github/workflows/qualification.yml  # proposed, not yet created
sha: <REVIEWED_FULL_WORKFLOW_COMMIT_SHA_REQUIRED>
```

Do not substitute a mutable default branch or check-name-only rule when the source
is unavailable. Native source binding and current-base handling must be proven
on the actual account before adoption; the native alternative must pass the same
head/base-change controls below. The API's SHA field is not an executed proof.

For the App route, publish only for the tested commit and bind head/base/tested
merge in the result. Re-read the live tuple immediately before publication.
Require the branch to contain the current base and test that exact merged tree;
a base advance blocks under the strict rule until the author updates and a new
head is evaluated. Do not post an old artifact's success onto a new head. The
proof must exercise base movement both during a run and after a success; any
remaining freshness race blocks adoption. Use one canonical trusted check lifecycle
per head/base/policy request: the separate admission phase must invalidate
an earlier success before starting a new required attempt, and never let an older
successful attempt mask a later failure. Policy or source-identity changes require
explicit invalidation of affected outstanding successes and new proof, even if
candidate source is unchanged. Test duplicate-check ordering and replay behavior
against GitHub rather than assuming the latest report wins.
No merge queue is proposed initially.

GitHub can accept `neutral` or `skipped` as ordinary required-check outcomes
([documented semantics](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)).
The trusted publisher therefore emits `success` **only** for a complete exact
pass. Failed, cancelled, timed-out, missing, malformed or inconclusive required
evidence becomes `failure` or `action_required`; it never emits qualification
`neutral` or `skipped`. After verified admission, final-publisher loss leaves the
established non-success state blocking. Before admission, do not claim that a
missing publisher or a newly requested attempt withdrew a previous success.
An always-run trusted finalizer checks every required lane and observer status;
workflow/job success by itself cannot supply that completeness decision.

## Proof after authorization

Keep two explicit milestones: **A: rule/source identity enforced** and **B: full
qualification worker ready**. Passing A cannot close #23 or qualify a package.
No proof in either milestone has been performed by this design task.

After authority separation, an authorized administrator saves current settings,
creates a disposable PR and uses a non-bypass writer for the negative controls.
Use a disposable proof target with identical proposed rules first; record its
exact ref/rule IDs. Keep production main unchanged until the positive control and
owner review are complete, then read back and verify main's exact configured rule.
Milestone A fixture checks stay on the disposable proof target; they are never
published as production package qualification. Production qualification activation
also requires milestone B readiness and its explicit owner acceptance.
Never attempt a positive-control merge. A negative merge attempt may run only
while the expected blocking condition is present; if any negative unexpectedly
merges, stop and record failed enforcement instead of continuing the campaign.

| Milestone | Control | Required result and retained evidence |
| --- | --- | --- |
| A | Missing trusted check; candidate same-name green GitHub Actions check; same-name PAT commit status | All block the non-bypass writer. Save check/status JSON including actual App IDs, rule JSON, head/base and API refusal status/body. No new PAT is authorized by this proposal; use an explicitly approved existing restricted proof identity or leave that case unrun. |
| A | Complete trusted fixture result from actual distinct App, or actual source-bound native workflow | With independent review requirements satisfied, only this positive control makes the disposable PR eligible. Do not merge. Label the fixture result as rule-identity proof, never package qualification. |
| A | Advance head or base during evaluation and after a success; replay old result; candidate imitation of source workflow | Stale/replayed/lookalike evidence cannot make the updated PR eligible. Save old/new trees, check bindings and refusal. |
| A | Prior success on the same head/base, verified admission invalidation, replacement attempt, then final-publisher interruption | The old success no longer permits integration throughout the admitted retry. Missing admission credentials or failed invalidation prevents dispatch; retain the observed blocking state, check IDs and token-revocation evidence. Test policy changes and duplicate-check ordering too. |
| A/B | Failure, cancellation, timeout, missing cohort/lane, observer loss, malformed or incomplete envelope | All block; none becomes neutral/skipped qualification. Test finalizer and publisher interruption as well as worker failure. |
| B | Swap Core/Map/archive/native/dependency/evaluator/policy/fixture bytes; spoof hash/pass text; wrong run/attempt | Trusted byte/schema/identity verification rejects every mismatch, including validly formatted self-reports. |
| B | Oversized/truncated outputs, deep JSON, duplicate fields, path/symlink escape, archive expansion and forged result paths | Bounded parser/collector rejects; no host extraction escape, uncontrolled allocation or publication. |
| B | Canary credential reads, network/DNS/metadata access, runtime socket, evaluator writes, namespace/capability escape | All forbidden access fails; use nonsecret canaries, never expose a real owner/policy/publisher key to test isolation. |
| B | CPU/memory/PID/disk/output/deadline exhaustion; detached descendants; cancellation during install/collection | Enforced bounds, complete descendant cleanup, failed verdict and clean next VM. Retain measured peaks and cleanup observations. |
| B | Short-lived/native replacement loads, memfd/anonymous execution, FD passing, children, trace loss and assertion spoofing | Observer/enforcement rejects or attributes every required case to actual retained bytes. Unknown coverage blocks readiness. |
| B | Complete real package positive control on both cohorts | Independently verified exact installed tuple and every required result make PR eligible, without merge or publication. |

Retain actual rule and App/installation/source-workflow JSON, permissions readback,
workflow revision, check runs/statuses, exact head/base/merge refs, request/result
bytes and digests, refusal bodies, resource observations and every earlier attempt.
Redact authentication headers and secrets; preserve nonsecret response evidence.
Store a reviewer-signed disposition referencing the exact evidence index. Source
files declaring a rule are not proof that GitHub enforced it. Issue/project status
may index the disposition only after the independent acceptance owner records it.

## Cost, rollback and recovery

[Standard public hosted Actions minutes are free](https://docs.github.com/en/actions/concepts/billing-and-usage).
That does not make a proposed private controller free: its plan quota, storage,
artifact retention and overage settings need an account-specific assessment.
Private controller jobs accrue there; reusable workflow billing follows the caller.
Do not invent available quota, prices, total storage or a paid-plan entitlement.
Measure VM minutes, peak storage, trace/archive bytes, queue delay and custodian
maintenance time on the proof before accepting an operating budget. An unavailable
quota or unapproved cost leaves qualification blocked.

Record approved action/runtime/image versions and security/deprecation review,
key rotation owner, retention expiry dates and a recovery drill schedule. Before
expiry, copy evidence to the approved durable destination and rehash actual files.
No new storage service or purchase is authorized here. Lost actual native or
package bytes require a new attributable attempt; rebuilding creates new evidence.

If the controller or publisher fails, keep the required check active and block
merges. Restore the last reviewed controller/policy/image by exact digest, revoke
a suspect installation token/key through the custodian, rotate outside authoring
sessions, and invalidate affected success records. Save incident and old attempts.
A replacement App needs an explicit rule-source update and repeated identity proof;
never remove the expected-source binding to recover availability.

Keep the pre-change rule export and a separately approved recovery runbook. Routine
rollback restores a last known enforced configuration, not an empty rule set.
Disabling the first rule would remove protection and requires a new explicit owner
decision with the qualification gap recorded. During a suspected compromised
success, the administrator must freeze integration through an independently
controlled restriction before repair; no bypass merge is part of this design.
Re-run negative and positive controls on the restored identities. Backup custodian,
recovery access and storage must be named before activation.

## Review and handback

Independent review must assess authority separation, source identity, stale-result
races, evidence parser/collector boundaries, observer completeness, cleanup and
operating cost. Concrete unresolved worker findings block B even if A succeeds.
The draft's documentation checks establish format/metadata health only.
The gemspec currently includes development documentation, so this proposal adds
package bytes on the next build. It changes no runtime behavior; old package
qualification cannot transfer to the rebuilt gem. This PR deliberately leaves
packaging policy unchanged. Root will
arrange independent review, reconcile the proposed decisions with the owner and
request genuinely missing authorization after this artifact is reviewable.
No self-acceptance, deployment, launch qualification or publication follows from
merging this documentation.
