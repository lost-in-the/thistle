# Independent security review: experiment 001 candidate

Reviewed candidate file: `/workspace/thistle-experiment/engine/src/store.rs`, SHA-256 `027aad23b86a2dc20676b5544a42d3fa4523f345eb4045f948fbe31dd3a25e5e`. Date: 2026-10-28. The reviewed change adds immutable normalized search records, admission accounting and two focused native tests. This reviewer made no implementation, evaluator, fixture or policy edits.

Baseline evidence inspected: hosted run `40700690778`, source `39f49d500ad941b01f9a839978f0fca599d812c6`, evaluator `b81f5adc2c647083b6ce8688234012c6d2da0ee4`, package SHA-256 `fc9fb44db77817dcb65dd9d4d23e601e0661b8116ebd4071c1c94b2d747d527e`, installed native SHA-256 `ee8002e57cf356a6a2ed59617c6fb90e5fbff18e447142e6c79db79d15009541`. The supplied baseline report records a pass for 12 check groups, including parser-worker, reader-constructor and real Rails routes; its tuple verification records a pass. This reviewer inspected those report files but did not rerun the hosted checks.

Disposition: **no concrete blocking boundary, accounting or search-correctness regression identified in the bounded source patch**. Candidate installed qualification and the unchanged frozen experiment must still decide acceptance. This report is source review evidence, not a runtime or performance verdict.

## Search and ownership invariants

- Search records are created after facts have passed shape/digest/depth validation (`engine/src/store.rs:147`–150). Each validated fact receives one record in the same order (`:158`–165). The cache and facts are retained inside the same immutable reader; no public operation mutates either after construction. Therefore the zip at `:188` does not silently drop facts under the current implementation.
- The cached expressions at `:161`–162 exactly preserve the baseline expressions: lowercased name, unchanged case-sensitive kind, and lowercased optional path. Query normalization, terms, original-query exact-ID matching, name/prefix ranking, original-name/ID tie ordering, limits, total count, truncation and coverage output remain unchanged (`:182`–199). Unicode expansion and original-ID behavior receive focused test coverage in the patch. This is a direct source-equivalence observation; installed comparison still must independently enforce semantic/ranking/source/coverage equality.
- Allocation or checked-accounting failure before construction returns drops the partially built vector and all owned strings through Rust RAII. Registry insertion still occurs only after `Reader::open` succeeds. The unchanged close path subtracts the same retained `reader.weight`, so the added cache does not introduce a separate ownership/refund path.
- JSON depth, filesystem containment, source integrity, generation selection, parser behavior and C/Ruby handoff code are unchanged by the search patch. No new unsafe code, native pointer, shared mutable state, execution endpoint or source-freshness assertion is introduced.

## Memory accounting

At `engine/src/store.rs:163`, the candidate adds the retained allocation capacity of both strings per record rather than charging only text length. At `:170`–173 it adds vector capacity times `size_of::<SearchRecord>()`, plus the vector header, with checked multiplication/addition. This covers the newly retained Rust allocations at the stated estimate level. The existing encoded fact/manifest contribution is preserved.

The charge intentionally reduces reader-admission headroom for the same store, especially with many concurrently retained readers; this cost must remain visible. It does not represent complete heap usage or process RSS. Allocator overhead, existing parsed JSON/index allocations and transient open/path-normalization buffers are outside the estimate. Concurrent opening happens before registry admission, and an in-flight Arc may retain a closed reader temporarily; these were existing architectural limits. The patch correctly labels accounting as an estimate (`:167`–169). Do not reinterpret it as a physical-memory cap or a hostile-input sandbox. Initial and warm peak RSS gates remain required for both session modes.

## Validation and acceptance still required

No candidate native build/test, installed-artifact evaluator, Map smoke or timing trial was executed by this reviewer. The two added native tests must actually run; their presence is not a pass. Both exact installed arms need the current frozen evaluator/probes, actual native/Ruby identity checks and matching correctness hardening. Then run the frozen 20 paired trials and four A/A calibration pairs per mode, retaining failures and all measured attempts. A failed or inconclusive full-session/RSS/calibration gate retains the qualified baseline. The source review offers no basis to substitute warm-query-only timing or change policy.

The existing candidate-owned hosted orchestration remains development evidence with shared runner authority; this review does not establish protected evaluator ownership or an external required-check service. All broader launch/security gaps in the baseline security report remain open.
