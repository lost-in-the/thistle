# Experiment 001 decision: retain the candidate for review

The unchanged frozen controller returned `retain_candidate` in
[run 40702407356](https://github.com/lost-in-the/thistle/actions/runs/40702407356),
candidate source `f424aa661804a013afc41a167f8afde47358f268`.
This is a draft development change, not merged or published. Baseline restoration
remains separately reviewable in [PR #1](https://github.com/lost-in-the/thistle/pull/1);
this optimization is [PR #2](https://github.com/lost-in-the/thistle/pull/2).

## Exact artifacts

| Component | SHA-256 |
|---|---|
| Baseline source gem, source `39f49d500ad941b01f9a839978f0fca599d812c6` | `fc9fb44db77817dcb65dd9d4d23e601e0661b8116ebd4071c1c94b2d747d527e` |
| Reinstalled/requalified measured baseline native | `2aab962c4a7b33297a82c9552ad1027dbcc353130d97b11c4874929b4c77e151` |
| Candidate source gem | `98b9eac030a744a732ff88a5289bfe5603ca37b73d93e5c1ee13733c3d26c147` |
| Measured candidate native | `f563f7d2a3872b48e6029e05d5ad38cb94c81b393a01f64cc3b343f51c0055cb` |
| Map gem, tested against both exact cores | `c19c41173588ea6929a675539cf549e429950442fe36382d49c1fa6edc472bf7` |
| Frozen policy | `14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe` |
| Full uncompressed comparison report | `30dcd79b5a8b9a55463d614dd5b10ea5e4b78acce12b4f3e79b3b01f9ff91fbe` |

The accepted original baseline package was downloaded by exact run/artifact and
digest, not rebuilt into a replacement package. Installing it on the measurement
host produced the newly qualified native above. It is distinct from the original
`ee8002e5...` baseline installation used for the first self-inspection. Every
measured process is bound to the native/Ruby hashes in its current passing quality
report; neither original installation evidence nor another source build is
silently substituted. Package payloads differ only in `engine/src/store.rs`.

Evaluator history remains `b81f5adc2c647083b6ce8688234012c6d2da0ee4`; evaluator,
fixture, workload-helper, policy and toolchain hashes are recorded. Both arms used
Linux x86-64, Ruby 3.3.13, Rails 7.2.4, Rust/Cargo 1.90.0, GCC 13.3.0 and libclang
18. Build summaries record the actual Ruby/compiler binary digests and Cargo
release configuration (thin LTO, one codegen unit, debug=1, panic=unwind).

## Frozen primary results

Twenty randomized paired trials per mode and four A/A pairs per mode completed:
40 comparison pairs, eight calibration pairs, 96 successful process attempts,
zero faults. Seed, fixture sizes, thresholds and metrics were unchanged.
Ratios below are medians of paired candidate/baseline ratios, not ratios of the
independent medians. Absolute times are descriptive per-arm medians.

| Metric | Single query + source | 100 queries + 10 sources | Required gate |
|---|---:|---:|---|
| Process-until-results paired ratio | 1.003260 | 0.713172 | <=1.10 / <=0.90 |
| Baseline median seconds | 0.093293 | 0.185986 | Descriptive |
| Candidate median seconds | 0.093587 | 0.132520 | Descriptive |
| Initial peak RSS paired ratio | 1.007436 | 1.005953 | <=1.20 each |
| Warm peak RSS paired ratio | 1.007436 | 1.004937 | <=1.20 each |
| A/A process timing paired ratio | 1.002028 | 1.005283 | [0.95, 1.05] |

The repeated-session primary metric observed about 28.7% less time in this
synthetic workload, including process startup. Single-session time was roughly
unchanged. Reader opening became about 0.7–0.8 ms more expensive, as expected
from preparing records once. Single-session median peak RSS rose from 42,266 to
42,600 KiB; repeated-session initial/warm peaks rose from 45,364/46,950 to
45,644/47,182 KiB. Cache capacities are charged to admission; the encoded-data
estimate still does not cap physical process memory. More cache reduces the
number/size of readers admitted under the existing aggregate budget.

Exact semantic hashes agreed across all trials after only the controller's
declared generation normalization; ranking, coverage, source and response fields
remained significant. Warm-query diagnostics were not substituted for the
process-until-results primary metric.

## Validation and reviews

Candidate native suite: 16 tests passed, including Unicode/case/ID/ranking/limit
semantics and cache-capacity accounting. Ruby: 28 tests/237 assertions. Map:
21 tests/165 assertions. Evaluator: 18 tests. All passed with no errors/skips.
All three development CI cohorts also passed.

Each exact installed artifact separately passed all 12 evaluator check groups,
including real Rails routes, parser-worker and reader-boundary probes. Both
passed installed Map smoke and package-to-installed file checks. Evaluator
tracked-file identities and package hashes remained unchanged through each lane.
The source/Ruby/native identities in the comparison match these reports.

Architecture and security source reviewers found no concrete candidate blocker.
Independent result auditing recomputed raw paired medians, all gates, trial
counts, seeded ordering, semantic/native/Ruby bindings and package/native hashes.
The audit does not turn candidate-controlled orchestration into independent
protected authority. Admission/refusal integration coverage beyond the retained
capacity assertion is a nonblocking follow-up; wider workloads remain unmeasured.

Artifacts from run `40702407356`: controller/raw trials `12821898684`, exact
baseline `12821819156`, exact candidate `12822901065` (30-day hosting retention).
The [compressed raw report](results/experiment-001.json.gz) preserves every
attempt; decompress with `gzip -dc` and verify the uncompressed digest above.
[Summary](results/summary.json), both quality/tuple reports, toolchain summaries,
source-test logs and independent audits are preserved alongside it. Compiled
gems/native binaries remain in immutable run artifacts and local downloaded
archives, outside source history.

## Limits and next steps

Retain this patch as the experiment-selected candidate for code review; keep the
hardened baseline and its evidence for rollback. No repeat confirmation campaign
was run. The one-time push trigger is removed after recording this completed
campaign; subsequent measurements require an explicit separately reviewed run.
Development PR CI still runs without path filters. Missing future qualification
cannot be inferred from this frozen source/artifact result.

This visible synthetic workload uses warm shared OS caches and new processes.
It is not an OS-cold, extraction, customer-task, provider-cost, Woods comparison,
population-confidence or global speed claim. Protected controller ownership,
hostile-worker isolation, full native fuzz/sanitizer evidence, broad runtime
families, support/precompiled packages, lifecycle/retention, complete Map/Guide
journeys and intended-user accessibility remain launch blockers. All 17 ledger
rows remain unqualified. Next reviewable work is protected evaluator deployment
and one independently labelled runtime-family slice; no merge or release here.
