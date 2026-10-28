# Independent audit of experiment 001 artifact bindings

Audit date: 2026-10-28. Hosted run: `40702407356`. Inputs: the retained `baseline/`, `candidate/` and `controller/` directories under `/workspace/thistle-eval-runs/experiment-001-40702407356`. This reviewer inspected retained reports and hashed retained package/native bytes. No implementation or evaluator was edited, no candidate was installed or executed by this audit, and no benchmark trial was rerun.

**Disposition: no concrete artifact-binding or reported-gate blocker found.** The retained evidence supports `retain_candidate` for the one frozen development experiment. It does not establish launch qualification or protected evaluator authority.

Machine-readable audit: `experiment-results-security-audit.json` beside this report. It records zero issues. The comparison report's actual SHA-256 is `30dcd79b5a8b9a55463d614dd5b10ea5e4b78acce12b4f3e79b3b01f9ff91fbe`.

## Exact artifact tuple

| Component | Baseline | Candidate |
|---|---|---|
| Source commit recorded by build | `39f49d500ad941b01f9a839978f0fca599d812c6` | `f424aa661804a013afc41a167f8afde47358f268` |
| Actual retained source-gem SHA-256 | `fc9fb44db77817dcb65dd9d4d23e601e0661b8116ebd4071c1c94b2d747d527e` | `98b9eac030a744a732ff88a5289bfe5603ca37b73d93e5c1ee13733c3d26c147` |
| Actual retained installed-native SHA-256 | `2aab962c4a7b33297a82c9552ad1027dbcc353130d97b11c4874929b4c77e151` | `f563f7d2a3872b48e6029e05d5ad38cb94c81b393a01f64cc3b343f51c0055cb` |
| Retained quality-report SHA-256 | `bcb68b624394041d6c2ce57eed9aa60fc54327c086edba2dac12b24e4768b408` | `e9a3908291decad5881f416f23a24856bce907782a395e190e6aa69fdcb65feb` |

Both arms use the exact same retained Map gem, SHA-256 `c19c41173588ea6929a675539cf549e429950442fe36382d49c1fa6edc472bf7`. Both record Ruby 3.3.13, Rails 7.2.4, Rust 1.90.0, and matching recorded Ruby/rustc/Cargo/C-compiler binary hashes.

The original qualification run `40700690778` used the same baseline source-gem bytes but native SHA-256 `ee8002e57cf356a6a2ed59617c6fb90e5fbff18e447142e6c79db79d15009541`; I independently hashed its retained native and source-gem files too. The experiment did **not** silently reuse that old native result: it rebuilt the baseline on the experiment host and qualified native `2aab962c...` again. Its own new quality report is exactly the report bound into the comparison. The two native identities must remain distinct in delivery claims; this work does not establish deterministic native rebuilds across paths/environments.

## Byte and execution-record checks

- Both retained core gem payloads contain **3,408 regular files** with identical path sets. The only differing payload file is `engine/src/store.rs`. Thus the C/Ruby boundary, JSON-depth/reader-constructor/empty-path hardening, capture code, dependency locks and vendored bytes are identical in the two packages. Neither includes `docs/handoff`; both preserve all four legitimate `engine/vendor/cc/src/target/*.rs` files. No prebuilt `.so`, `.a` or `.o` was present in the core payloads.
- Independently computed payload-file hashes exactly match `build-identity.json` and the recorded installed-file inventory for all 3,408 core files and all **16 Map files**. These are byte checks against retained package data and recorded installed inventories. The full installed Ruby trees were not separately included in this download; this audit therefore does not claim to have reread their original filesystem paths after the run. The actual retained native files were independently hashed.
- Each arm's quality report records a pass for **12 check groups**, including the current installed parser-worker probe, reader-boundary probe and real Rails route lane. Probe helper hashes match the frozen evaluator, and each probe's native identity matches the arm's actual retained native. Both installed Map smoke reports name the corresponding native, report no Woods installation and no checkout load path, and record a pass.
- Each tuple file binds the actual retained gem hashes, quality-report bytes, native identity, loaded runtime-file hashes, self-inspection report and installed-file counts. The self-inspection report's exact `store.rs` content and digest agree with that arm's actual packaged file and its embedded build identity. Baseline `store.rs` SHA-256 is `45fb5d5f7c4f7fdc4ae14171537420ea094ca13a985b0cbf6377225d90063c10`; candidate is `027aad23b86a2dc20676b5544a42d3fa4523f345eb4045f948fbe31dd3a25e5e`.
- The comparison's quality-report hashes equal the retained quality-report bytes. Every A/B measurement and every recorded attempt uses exactly the corresponding quality report's native and **seven loaded runtime-file identities**. Every A/A role correctly uses the requalified baseline's runtime tuple. No occurrence substitutes the original `ee8002e...` baseline native for the compared `2aab962c...` native.
- The **15 recorded evaluator-file hashes** match the restored evaluator at commit `b81f5adc2c647083b6ce8688234012c6d2da0ee4`. Controller, benchmark helper, fixture and both probe hashes match those same frozen files. The policy is unchanged at SHA-256 `14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe`.
- The report contains **20 A/B pairs per mode**, **four A/A pairs per mode**, **96 recorded process attempts**, and no faults. All recorded attempts report passed validation. Semantic hashes agree across both arms and calibration for their respective modes, as checked by the unchanged frozen comparison helper. This is the recorded generated-fixture semantic/ranking/source/coverage equivalence, not broad application or launch parity.

## Independent arithmetic check

I recomputed the median of the paired candidate/baseline ratios directly from the retained individual measurements; these exactly match the reported summaries and decision.

| Gate | Single session | Repeated session | Frozen rule |
|---|---:|---:|---|
| Complete process-until-results ratio | 1.003260 | 0.713172 | At most 1.10 / 0.90 |
| Initial peak-RSS ratio | 1.007436 | 1.005953 | Each at most 1.20 |
| Warm peak-RSS ratio | 1.007436 | 1.004937 | Each at most 1.20 |
| A/A primary ratio | 1.002028 | 1.005283 | Each within [0.95, 1.05] |

All frozen gates pass. The reported primary single-session medians are approximately 93.293 ms baseline and 93.587 ms candidate; repeated-session medians are approximately 185.986 ms and 132.520 ms. The acceptance calculation correctly uses paired ratios rather than a ratio of those independent medians. Warm-query timings were not substituted for the primary metric. A defensible claim is that the bounded cache was retained under this one generated, warm-OS-cache, new-process development workload; a general performance or Woods advantage is not established.

## Remaining authority and claim limits

The evaluator history, expectations and frozen policy are independently versioned, but candidate-controlled hosted orchestration and candidate execution share runner authority. This is not an independently protected controller, a hostile-candidate sandbox, or an externally enforced required check. The existing deployment/security and all 17 launch-ledger gaps remain open. Source freshness, broad parser safety, physical process-memory enforcement, platform support, intended-user Map/accessibility journeys and release provenance are not qualified by these trial results.

The earlier orchestration failure-output issue is resolved in the reviewed current helper: smoke/inspection output writes directly to retained files with a deadline, and tracked evaluator-file cleanliness plus before/after hashes are now checked. This source observation does not erase the earlier review or any failed attempts. No additional evidence or threshold was changed by this audit.
