# Pull requests, CI and security boundaries

This document describes implemented local controls and required deployment controls separately. No GitHub branch protection, independent check, publishing identity, or repository has been configured by creating these files.

## Pull request unit

Each implementation PR links the affected capability-ledger rows, states the intended behavior and its unknowns, and includes meaningful positive/failure/mutation evidence. An optimization PR additionally includes the exact runnable artifacts, input/profile identities, falsifiable hypothesis, full-workflow effect and cost, semantic regression evidence and rollback decision. Expected-output or acceptance-policy changes receive separate evaluator-owner review. A new candidate head invalidates evidence for a prior head.

Review the smallest complete user/evidence slice: a parser-only patch cannot claim a source-to-query outcome; a fast query cannot claim fast application refresh. Retain rejected optimization experiments. Keep source/runtime/native build identities attached to performance evidence so the accepted gem can help inspect its own implementation without confusing diagnostic and release binaries.

## Candidate repository CI

The checked-in workflow is development feedback: Ruby/runtime tests, locked native tests, Map's Ruby tests against the native core, both package builds and artifact retention. It runs on pull requests without path filters, grants only `contents: read`, disables checkout credential persistence and uses pinned actions. It has no release step, secret-bearing privileged event or automatic merge. Run native code and gem install hooks as untrusted code. PR workers are disposable; caches must not be promoted into privileged release contexts. Browser and independent installed-artifact checks remain separate required lanes; these source-checkout unit jobs cannot substitute for them.

The initial matrix is a small compatibility probe, not the launch support matrix: Ruby 3.0/Rails 6.1, Ruby 3.3/Rails 7.2 and Ruby 3.4/Rails 8.0 on a current Ubuntu runner. Actual runs still need to occur in GitHub. Source builds require the checked-in exact Rust toolchain, a C compiler, libclang and locked vendored dependencies. Precompiled gems, supported operating systems/CPU/libc/ABI routes, Ruby 4 and other promised/current cohorts are separately unqualified until tested.

Third-party action pins are verified from official repositories on October 28, 2026:

| Action | Immutable commit | Source |
|---|---|---|
| Checkout v4 | `11d5960a326750d5838078e36cf38b85af677262` | [Official commit](https://github.com/actions/checkout/commit/11d5960a326750d5838078e36cf38b85af677262) |
| Ruby setup v1 | `7f797815d8adceb1c412e7abefdd1ab4abc47a5f` | [Official commit](https://github.com/ruby/setup-ruby/commit/7f797815d8adceb1c412e7abefdd1ab4abc47a5f) |
| Artifact upload v4 | `ea165f8d65b6e75b540449e92b4886f43607fa02` | [Official commit](https://github.com/actions/upload-artifact/commit/ea165f8d65b6e75b540449e92b4886f43607fa02) |

Dependency updates are normal reviewed PRs. Pinning an action does not make it trusted for secrets; this workflow intentionally has none. Repository-level permissions and required checks must be configured by the repository owner before depending on CI for enforcement.

## Independent required check

The authoritative controller and policy belong outside the candidate's writable checkout. The proposed `thistle-eval` workspace provides an executable starting point, but sibling directories are not a security boundary. In protected infrastructure, the controller:

1. Selects a reviewed evaluator revision and required lane set independently of candidate paths/workflow contents.
2. Binds the exact candidate head/tested merge and dependency/package bytes. Build/install workers run with no production, evaluator or release credentials.
3. Runs disposable least-privilege workers with bounded CPU, memory, processes, disk and egress. Worker identities cannot write policy, expected facts, controller verdicts or other candidates' caches.
4. Accepts only bounded outputs, then validates evidence against independent expected facts. Candidate-generated “pass” text is data.
5. Publishes a verdict bound to candidate, package, evaluator, fixture and environment identities. Missing/cancelled/timed-out lanes fail qualification. Re-runs retain previous failure evidence.

The required check must be enforced by branch/ruleset policy that candidate PRs cannot change. A candidate-owned workflow reporting green cannot substitute for this external check. Do not run untrusted PR head code under `pull_request_target` or another privileged context. These principles follow [GitHub's Actions security guidance](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions).

## Required lanes before launch

| Lane | Required evidence |
|---|---|
| Installed public contracts | Clean installed core/Map packages; no Woods; Ruby and external client contracts; version/refusal behavior |
| Runtime and mutation | Real loaded Rails fixtures; independently labelled facts; source/reload/schema/branch edits; atomic failed publication |
| Native and distribution | Supported source/precompiled installs; loaded native hashes; parser/index fuzzing; ownership and panic boundaries; platform/ABI cases |
| Consumers and human interface | Thistle-only Map; generation consistency; source escaping, CSP, auth/origin policy, focus/keyboard behavior; complete required journeys |
| Retrieval, tasks and cost | Relevance and customer success with predeclared margins; real declared providers; full-source follow-up; all cost/failure accounting |
| Controlled performance | Cold boot/extraction, edit-to-fresh-client, startup, warm and whole-task distributions; all owned process/service resource use |
| Release qualification | Exact final package tuple, full required support/features, recovery/soak, usable setup/switching docs, benefits and remaining limits |

Scheduled fuzzing/scans/soaks supplement exact-candidate checks; they cannot qualify a later changed binary. Required lanes stay unqualified until actually executed.

## Product boundaries

Static capture parses bytes without evaluating application source. Runtime Rails capture is explicit trusted application execution and inherits the application's authority. It must state what is loaded, what is outside scope and what source/runtime coherence has not been established. Content equality before/after capture alone cannot prove a safe load epoch.

Offline readers consume source-sensitive snapshots. Validate schema, identities, lengths, digests and paths; reject corruption and unsupported versions; bound input/work/output sizes; do not follow path/symlink escapes. Source, schema defaults, profiles and logs may contain confidential information. Capture no records, locals or process dumps by default; provider disclosure must be explicit. The optional Map is read-only evidence consumption with escaped source and no command-execution surface. Read-only software still needs access controls when deployed beyond a trusted local process.

The Rust core is linked through a small C Ruby extension. Its FFI boundary must fail closed for malformed JSON, invalid UTF-8/lengths, path errors and panics. Track ownership of input/output native buffers and release them exactly once; release the GVL only while the native operation owns its memory and cannot touch Ruby objects. Batch calls rather than paying the boundary cost per fact. A source-built native core is a packaging choice, not an isolation boundary. Map and Rails plugins in the same process inherit that process's authority.

## Release authority

Release remains a separately authorized protected workflow. It builds or promotes only the exact qualified package bytes, verifies package contents and loaded native assets, records provenance and publishes through a protected short-lived identity where available. [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/) is the intended publication mechanism to evaluate. No publishing credentials or release automation are included in this private milestone.
