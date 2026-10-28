# Protected evaluation: design and owner decisions

This is the bounded design proposal for [issue #23](https://github.com/lost-in-the/thistle/issues/23).
It prepares a deployment decision and a proof procedure. No controller, repository,
App, credential, rule, purchase or enforcement proof has been created by this PR.
The owner selected Leah as custodian/final policy approver, with CodeRabbit as an
advisory reviewer. Independent authority has not been activated or proven; shared
authoring credentials still disqualify it. Root owns integration and peer review.
Issue #23's external authority and proof remain **Check / Evidence Needed**.
All 17 [launch capabilities](../capability-ledger.md) remain unqualified.

## Three delivery levels

| Level | Trigger and scope | Authority and consequence |
| --- | --- | --- |
| Ordinary PR merge | Automatic, targeted routing and tests appropriate to changed files, plus recorded substantive review. Documentation does not select full product or installed matrices. | Basic PR/CI protection prevents accidental unchecked integration. Candidate CI is not independent qualification. No custodian dispatch or full qualification queue on this path. |
| Integrated main | Automatic broader product, Compatibility and PII checks on the exact integrated SHA. | Detect integration and support drift; preserve failures and exact identities. A main pass does not qualify packages. |
| Protected qualification | Deliberately selected exact-package preview/release acceptance or an explicitly accepted performance experiment. | Independent policy/controller and exact artifact evidence; custodian dispatch is acceptable here. This is separate from ordinary main-PR eligibility and does not authorize publication. |

The existing [tier policy](pr-ci-release.md) remains the ordinary feedback path.
Full qualification must not turn every small PR into a manual two-cohort queue.
If a protected result is later required on every PR, its scope must instead be
fast, automatically dispatched and routed by trusted policy; that is a separate
reviewed design, not this manual qualification path. Strict-base PR checks and a
possible future merge queue must not be confused with exact-package acceptance.

## Recommendation and decisions

The owner selected a public Free controller plus a distinct App as the proposal
route. Propose an independently controlled controller publishing
`Thistle qualification / required` for selected qualification requests, not as a
requirement on every ordinary PR targeting main.
Use GitHub Actions for orchestration and maintained token/runtime tooling. No
custom webhook service is needed: begin with the named custodian's manual
dispatch, using immutable request identities. Dispatch requires controller
repository write access and is not granted to candidate authors. Lack of a dispatch blocks
that selected qualification request; it does not block an ordinary PR merge. Automatic request discovery can be separately reviewed later.

Prefer native source-bound organization required workflows if the owner explicitly
chooses an eligible Team or Enterprise plan and public workflow source. That avoids
a custom publisher App/key, but does not solve worker isolation or shared authority.
A same-name job from the ordinary GitHub Actions App is not source binding.

The remaining setup decisions below require explicit authorization after independent
design review. The route and custodian preferences do not authorize setup. Suggested names and settings are proposals, not allocated identities.

| Decision | Concrete proposal | Missing approval or value |
| --- | --- | --- |
| Independent authority | Leah is the custodian and final policy approver. CodeRabbit can supply advisory policy review; it is not the qualification authority. Candidate authors have no controller/policy write or publisher-key access. | Verify human-controlled administration outside authoring sessions, effective access and backup/recovery custody; role selection is not credential or setup authorization |
| Candidate authoring | Use a restricted authoring identity such as existing `lost-in-the-agent` with Thistle write only; remove owner credentials from candidate-authoring sessions before claiming independence. | Owner-approved credential separation and verification; no account switch or permission change in this task |
| Evaluator home | Proposed public `lost-in-the/thistle-eval` on Free, with repository rules for policy changes and a distinct App. No candidate authors or authoring connectors may write there. Standard public hosted minutes are free. Private Free custody remains a fallback with weaker review enforcement. | The owner selected this route, but repository creation/disclosure, actual ID, writer/access list and restricted evidence destination still need authorization; inherited organization access must be checked |
| Enforcement route | Current Free: distinct proposed `Thistle Qualification` App, only Thistle installation, Checks write, Metadata read, Pull requests read and Contents read for head/base/tree verification; all other permissions off. | App name availability, numeric App ID, client ID, installation ID and custodian approval |
| Key custody | App key in custodian-controlled vault and only the protected publisher phases' secret (admission and final publication); no organization-wide secret, candidate secret, developer checkout or worker copy. | Actual approved vault/access list and publisher secret configuration; no key material belongs in this document |
| Admission authority | Admission and final publication are phases of one protected publishing authority. Both would have full App Checks write; the admission program permits blocking updates only, but its token is not conclusion-scoped. | Custodian acceptance and proof of this trusted-code boundary; no claim that a separate job/token prevents a compromised admission publisher from writing success |
| Native alternative | If eligible plan is chosen, public evaluator workflow source in the organization, pinned repository ID/path/SHA; same independent writers and worker boundary. | Plan purchase/entitlement, public disclosure approval and actual workflow identity |
| Repository rules | Basic main PR/CI protection is separate from qualification. Qualification source-identity proof uses a disposable target, with no ordinary-main manual qualification requirement. | Separate authorization for each concrete rule; actual IDs/readback and non-bypass proofs |
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
Manual qualification dispatch accepts exact source and package identities, with
a PR/head/base tuple only when that selected preview request concerns a PR. It
accepts no executable input or arbitrary URL. The controller resolves actual
repository/source/tree and package bytes, verifies any supplied PR/merge tuple,
rejects conflicts or identity mismatches, and allocates an immutable attempt ID.
Public Free repository rules can enforce policy review after authorization. For
the private evaluator fallback on Free, “protected” instead means an exclusive
custodian write/access boundary, **not** an available private-repository branch
rule. CodeRabbit supplies recorded advisory review; Leah supplies final policy
approval and the human custodian promotes the reviewed SHA. The private Free
fallback does not technically enforce policy review.
The owner selected the public Free route, where repository rules can enforce the
approved review policy; its setup remains unauthorized. An eligible paid plan
would require a separate decision. Record and prove
all effective writers; candidate-authoring credentials must reach none of them.
Only reviewed controller code is dispatched. No candidate workflow
completion event or artifact name alone authorizes a result.

Admission is protected publisher code, not an unprivileged controller or candidate
worker. The proposed single App grants both publisher phases full Checks write;
GitHub does not provide a blocking-conclusions-only permission. Separate jobs,
revocation and fresh tokens protect the worker boundary and retry lifecycle, not
conclusion authority. Both publisher phases, their code writers and hosts belong
to the verdict's trusted computing base. A compromise of either invalidates that
authority and requires the freeze/recovery procedure.

The protected admission entry point accepts only validated request identities and
blocking updates; only the final-publication entry point accepts a complete,
validated result for success. These are protected program-policy guards to prove,
not an API capability restriction on the token. If the custodian instead requires
admission credentials that cannot publish success even after publisher compromise,
stop for a separately reviewed authority design; no extra App or broker is created
or assumed here. Use separate disposable hosted jobs for the two trusted publisher
phases and preparation/execution:

1. Only after separate App creation, permission/custody approval and activation,
   a trusted publisher admission job uses repository/permission-scoped App authority, without checking
   out or executing candidate code. Before admitting
   any required attempt, including a retry or policy change for the same request,
   it establishes and reads back a blocking state for the canonical trusted check.
   It must verify that no earlier success or duplicate check still makes that
   request eligible. Revoke this short-lived token before worker dispatch. Failure
   to establish or verify the blocking state prevents dispatch and policy
   activation; requesting a retry alone does not invalidate an existing success.
   If an earlier result must be withdrawn but cannot be invalidated, the custodian
   must freeze that qualification/promotion decision through the approved recovery
   control before proceeding; ordinary main PRs retain their separate CI gate.
2. A trusted preparation job resolves approved tool/dependency/image digests and
   the selected repository/source SHA/tree using bounded downloads. For a
   PR-scoped request it also resolves the PR/head/base/tested-merge identities;
   these are not required for an exact-package request without a PR. It emits an
   immutable input manifest. No candidate build, gemspec or install hook runs in
   this job.
3. A fresh execution VM launches the unprivileged candidate runtime. For an
   already selected candidate, retrieve and verify the exact Core/Map bytes; do not
   rebuild them for qualification. A separately requested new candidate may be
   prepared once in isolation from pinned source, collected as untrusted bytes,
   then that same pair is installed on both cohorts. A controller
   supervisor outside the runtime owns expected facts, deadlines and verdicts.
   The frozen evaluator must use the protected adapter for **every** subprocess;
   importing its old host-execution helper unchanged is not safe.
4. The supervisor validates bounded observations against independently held
   expectations and records all attempts. Candidate test scripts, exit-zero,
   `pass` text and self-reported hashes are evidence inputs, never the verdict.
5. A different fresh publisher VM reads only the controller-owned result envelope
   from the exact approved run/workflow/attempt. It verifies the artifact ID and
   digest, schema and complete required cohort set, then revalidates the selected
   repository/source/tree, package, policy and request/attempt identities. Only
   for a PR-scoped request does it also re-read current head/base/merge and enforce
   that request's approved PR-freshness policy. An exact-package request without
   a PR is not bound to a moving branch tip. It never checks out or executes
   candidate code, loads a candidate plugin, evaluates a template or sources a
   report as shell.
   Only after these validations may it obtain a fresh repository/permission-scoped
   token from the same App for final success publication. Both tokens have full
   Checks write; the earlier admission token is not reused.
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
| Source | Always: repository ID, selected full source SHA/tree and parent identities, controller workflow SHA and request ID/scope. For PR-scoped requests only: PR number, full head SHA, base ref/SHA and tested merge SHA/tree/parents. Record PR scope as not applicable when absent; never invent a PR tuple. |
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

## Separate basic main protection

This small protection step does not wait for the controller, native-load observer
or full qualification worker. Configure it only after a separate owner decision.
Proposed repository ruleset: exact main ref, required PR, strict current-base
`CI / required` and configured PII checks from the existing GitHub Actions App,
no deletion/force-push and no bypass actors. The checks are automatically dispatched
and retain current targeted routing. Neither check is renamed qualification.

```json
{
  "name": "Thistle basic main protection",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 0,
      "dismiss_stale_reviews_on_push": false,
      "require_code_owner_review": false,
      "require_last_push_approval": false,
      "required_review_thread_resolution": true
    }},
    {"type": "required_status_checks", "parameters": {
      "strict_required_status_checks_policy": true,
      "do_not_enforce_on_create": false,
      "required_status_checks": [
        {"context": "CI / required", "integration_id": 15368},
        {"context": "pii-check / pii-check", "integration_id": 15368}
      ]
    }}
  ]
}
```

The initial machine-enforced approval count is explicitly zero: substantive peer
review and owner-authorized integration remain the recorded workflow, rather than
inventing an available independent human approver for every owner-authored PR.
Requiring a particular approving reviewer is a separate concrete owner choice.
Unresolved review threads still block. PII remains fail-closed when its secret is
unavailable, including forks; this proposal neither broadens secret access nor
silently exempts them. Verify exact current check contexts before activation.

App `15368` identifies ordinary GitHub Actions, not an independently controlled
workflow. Candidate authors can edit candidate automation; this basic gate reduces
accidental unchecked integration but does not establish hostile-candidate or
qualification authority. A same-App lookalike is a known limit, not a protected
qualification pass. Do not claim otherwise.

Before activation, export current rules and use an owner-authorized disposable
proof target with these settings and a non-bypass writer. Read back the effective
rules before testing. Missing/failed checks, unassociated changes pushed directly, a stale base, branch
deletion, a non-fast-forward push and an unresolved review thread must each be
refused. A complete green targeted PR with resolved review threads becomes
eligible without a positive-control merge. Save actual rule/check/source
identities and each refusal. Verify the approved recovery procedure on the
disposable target, including restored settings and effective-rule readback.
Reconcile existing rules rather than replacing others' work. No rule is created
by this proposal.

The [October 28 proof](../handoff/runs/issue23-basic-protection-2026-10-28/README.md)
did **not** pass its original blanket-direct-update criterion. GitHub accepted a
fast-forward to an already eligible opened PR's exact head, indirectly marking
the disposable PR merged. The target was disposable; main never changed and
its rule was not activated. The temporary rule/refs were removed after retaining
the result. GitHub's PR rule requires association with an opened PR, not an
exclusive merge endpoint. The revised native-scope expectation needs an owner
decision and completed proof before activation; it is not retroactive approval of
that negative-control result. No broader mechanism is added to ordinary PRs.

## Qualification source-identity proof

The distinct App's `Thistle qualification / required` result belongs to selected
preview/release acceptance and deliberately accepted performance work. It is not
in the basic main ruleset above. Initially keep rule-identity experiments on a
disposable `proof/thistle-qualification` ref. Activation, real App IDs, key custody
and a promotion/acceptance surface remain separate owner decisions. No release
publishing or production promotion rule is authorized here.

For milestone A, a non-executable qualification-rule template uses an active branch
rule scoped only to that proof ref, no bypass actors, PR/current-base controls and:

```text
required_status_checks:
  strict_required_status_checks_policy: true
  do_not_enforce_on_create: false
  required_status_checks:
    - context: Thistle qualification / required
      integration_id: <ACTUAL_INDEPENDENT_APP_ID_REQUIRED>
```

Never substitute null, zero, `-1`, App `15368`, omission or any-source matching.
Validate the real App/installation and check JSON, then prove source binding through
the [rules API](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset).
If the chosen interface needs more than proposed Checks write/minimal reads, stop
for a specific decision; do not grant Statuses write or weaken binding silently.

The optional native organization-workflow route also requires an eligible plan,
a public evaluator workflow for a public target, and exact source repository
ID/path/full SHA. An API schema is not entitlement or enforcement proof. If later
used on ordinary PRs, it must select an automated fast merge scope through trusted
routing, not the manual full-qualification scope. There is no merge queue proposal
or plan purchase in this PR.

Bind every qualification result to its selected package pair, source, policy,
cohorts, run/attempt and any applicable PR/head/base/tested merge. Re-read that tuple
before publication. A later main commit does not transfer a pass to new package
bytes or automatically invalidate accepted evidence for unchanged selected bytes.
Changed request scope, policy or PR/base freshness requires explicit invalidation
and new evidence under the approved policy. Do not post an old artifact's success
onto a new request or head.

For retries of the same request, the separate admission phase must establish and
verify a blocking canonical check before dispatch; revoke its token and obtain a
separate final-publication token. Never let an older success or duplicate check mask
a later failed attempt. Prove ordering and replay behavior against actual GitHub
semantics. If admission cannot withdraw a result that must be invalidated, stop and
use the approved operator freeze/recovery control; a retry request alone is not a
blocking state.

GitHub can accept neutral/skipped required-check conclusions. The trusted publisher
therefore emits success only for a complete exact qualification pass; failed,
cancelled, timed-out, missing, malformed or inconclusive evidence becomes failure
or action_required. After verified admission, publisher interruption leaves the
non-success state blocking. An always-run trusted finalizer verifies every selected
lane and observer result; workflow success alone is insufficient. Ordinary PR
routing may legitimately skip unrelated product jobs under its separate CI policy.

## Proof after authorization

Keep two explicit milestones: **A: rule/source identity enforced** and **B: full
qualification worker ready**. Passing A cannot close #23 or qualify a package.
No proof in either milestone has been performed by this design task.

After authority separation, an authorized administrator saves current settings,
creates a disposable PR and uses a non-bypass writer for the negative controls.
Use a disposable proof target with identical proposed rules first; record its
exact ref/rule IDs. Qualification proof does not change production main or make
full qualification a main-PR requirement. Basic main protection has its own small
proof and owner decision and does not wait for milestone B.
Milestone A fixture checks stay on the disposable proof target; they are never
published as production package qualification. Preview/release qualification activation
requires milestone B readiness and explicit owner acceptance on the selected
acceptance/promotion surface; ordinary PRs continue through their separate gate.
Never attempt a positive-control merge. A negative merge attempt may run only
while the expected blocking condition is present; if any negative unexpectedly
merges, stop and record failed enforcement instead of continuing the campaign.

| Milestone | Control | Required result and retained evidence |
| --- | --- | --- |
| A | Missing trusted check; candidate same-name green GitHub Actions check; same-name PAT commit status | All block the non-bypass writer. Save check/status JSON including actual App IDs, rule JSON, head/base and API refusal status/body. No new PAT is authorized by this proposal; use an explicitly approved existing restricted proof identity or leave that case unrun. |
| A | Complete trusted fixture result from actual distinct App, or actual source-bound native workflow | With independent review requirements satisfied, only this positive control makes the disposable PR eligible. Do not merge. Label the fixture result as rule-identity proof, never package qualification. |
| A | Advance head or base during evaluation and after a success; replay old result; candidate imitation of source workflow | Stale/replayed/lookalike evidence cannot make the updated PR eligible. Save old/new trees, check bindings and refusal. |
| A | Prior success on the same head/base, verified admission invalidation, replacement attempt, then final-publisher interruption | The old success no longer permits integration throughout the admitted retry. Missing admission credentials or failed invalidation prevents dispatch; retain the observed blocking state, check IDs and token-revocation evidence. Test policy changes and duplicate-check ordering too. |
| A | Admission interface is asked to publish success or accepts an unvalidated request | Protected publisher code rejects the operation before an API call. This proves its program guard, not a conclusion-scoped credential; the entire admission publisher remains trusted. |
| A/B | Failure, cancellation, timeout, missing cohort/lane, observer loss, malformed or incomplete envelope | All block; none becomes neutral/skipped qualification. Test finalizer and publisher interruption as well as worker failure. |
| B | Swap Core/Map/archive/native/dependency/evaluator/policy/fixture bytes; spoof hash/pass text; wrong run/attempt | Trusted byte/schema/identity verification rejects every mismatch, including validly formatted self-reports. |
| B | Oversized/truncated outputs, deep JSON, duplicate fields, path/symlink escape, archive expansion and forged result paths | Bounded parser/collector rejects; no host extraction escape, uncontrolled allocation or publication. |
| B | Canary credential reads, network/DNS/metadata access, runtime socket, evaluator writes, namespace/capability escape | All forbidden access fails; use nonsecret canaries, never expose a real owner/policy/publisher key to test isolation. |
| B | CPU/memory/PID/disk/output/deadline exhaustion; detached descendants; cancellation during install/collection | Enforced bounds, complete descendant cleanup, failed verdict and clean next VM. Retain measured peaks and cleanup observations. |
| B | Short-lived/native replacement loads, memfd/anonymous execution, FD passing, children, trace loss and assertion spoofing | Observer/enforcement rejects or attributes every required case to actual retained bytes. Unknown coverage blocks readiness. |
| B | Complete real package positive control on both cohorts | Independently verified exact installed tuple and every required result satisfy the selected qualification decision, without promotion or publication. PR eligibility is relevant only for a PR-scoped proof request. |

Retain actual rule and App/installation/source-workflow JSON, permissions readback,
workflow revision, check runs/statuses, exact source/tree and applicable
PR/head/base/merge identities, request/result bytes and digests, refusal bodies,
resource observations and every earlier attempt.
Redact authentication headers and secrets; preserve nonsecret response evidence.
Store a reviewer-signed disposition referencing the exact evidence index. Source
files declaring a rule are not proof that GitHub enforced it. Issue/project status
may index the disposition only after the independent acceptance owner records it.

## Cost, rollback and recovery

[Standard public hosted Actions minutes are free](https://docs.github.com/en/actions/concepts/billing-and-usage).
The selected public controller still needs an account-specific storage, retention
and overage assessment. The private fallback would also consume its plan's private
runner quota; reusable workflow billing follows the caller.
Do not invent available quota, prices, total storage or a paid-plan entitlement.
Measure VM minutes, peak storage, trace/archive bytes, queue delay and custodian
maintenance time on the proof before accepting an operating budget. An unavailable
quota or unapproved cost leaves qualification blocked.

Public controller source does not authorize public application captures. Keep
private/external source, snapshots and identifying evidence in an approved
restricted destination; do not upload them as public-controller Actions artifacts.
Publish only reviewed nonsecret result summaries and digests. Storage access and
the transfer/retention mechanism must be approved before such inputs are admitted.
The initial rule-identity proof uses nonsecret fixtures, not application captures.

Record approved action/runtime/image versions and security/deprecation review,
key rotation owner, retention expiry dates and a recovery drill schedule. Before
expiry, copy evidence to the approved durable destination and rehash actual files.
No new storage service or purchase is authorized here. Lost actual native or
package bytes require a new attributable attempt; rebuilding creates new evidence.

If the qualification controller or publisher fails, block the selected acceptance
or promotion, not ordinary main PRs. Keep its expected-source requirement active.
Restore the last reviewed controller/policy/image by exact digest, revoke
a suspect installation token/key through the custodian, rotate outside authoring
sessions, and invalidate affected success records. Save incident and old attempts.
A replacement App needs an explicit rule-source update and repeated identity proof;
never remove the expected-source binding to recover availability.

Keep the pre-change rule export and a separately approved recovery runbook. Routine
rollback restores a last known enforced configuration, not an empty rule set.
Disabling the first rule would remove protection and requires a new explicit owner
decision with the qualification gap recorded. During a suspected compromised
qualification success, the administrator must freeze the affected acceptance or
promotion through an independently controlled restriction before repair. Basic
main-CI protection has its own recovery scope; qualification outage does not make
the ordinary PR path depend on that controller. No bypass merge is proposed.
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
