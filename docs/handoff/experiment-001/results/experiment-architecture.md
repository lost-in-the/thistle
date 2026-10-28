# Experiment 001 independent architecture review

Reviewer: `/root/review_architecture`, 2026-10-28. Reviewed candidate
`/workspace/thistle-experiment/engine/src/store.rs`, SHA-256
`027aad23b86a2dc20676b5544a42d3fa4523f345eb4045f948fbe31dd3a25e5e`,
against original hardened `store.rs`, SHA-256
`45fb5d5f7c4f7fdc4ae14171537420ea094ca13a985b0cbf6377225d90063c10`.
No implementation, evaluator, fixture, or policy edits were made by this reviewer.

## Disposition

No blocking matching/ranking, hardening-parity, or retained-cache-accounting
defect found in the reviewed patch. The bounded change is suitable to build and
qualify independently before the frozen experiment. This is a source-review
disposition, not a candidate quality pass or a performance acceptance decision.

## Semantics and architecture

- `engine/src/store.rs:158` constructs exactly one record for each validated fact
  in fact order. No later mutation changes either sequence, so the `zip` at
  `engine/src/store.rs:188` preserves fact-to-record identity.
- The preparation expressions at `engine/src/store.rs:161` and
  `engine/src/store.rs:162` are identical to the baseline expressions. Name and
  path are lowercased, kind retains its original text, absent path becomes the
  empty string, and the same spaces form the haystack.
- Query normalization, byte/term/result limits, original untrimmed-query ID
  comparison, exact/prefix/other rank assignment, original-name/ID sort keys,
  total counts, truncation, response fields and coverage are preserved at
  `engine/src/store.rs:182` through `engine/src/store.rs:199`.
- The added semantic test at `engine/src/store.rs:308` checks Unicode expansion,
  Unicode path case, original-query IDs, mixed-case kinds, null paths, rank order,
  truncation and refusals. These expectations match the reviewed baseline.
- The implementation's runtime source content differences under `engine/`,
  `ext/`, `lib/` and `.cargo/` are confined to `engine/src/store.rs`. Capture,
  parser, schema/depth validation, C ownership, Ruby reader construction,
  publication, source validation, and generation semantics are unchanged.

## Resource accounting

`engine/src/store.rs:163` charges both retained strings by capacity, and
`engine/src/store.rs:170` charges the actual vector capacity multiplied by the
record size, plus its header. Checked addition/multiplication fails explicitly
instead of wrapping. The original encoded-data weight remains included. The
existing registry uses that weight on admission and release, so the new retained
cache contributes to the existing budget without a separate untracked owner.
Counting the vector header is conservative; it is not evidence of measured heap
usage. Temporary lowercase-path allocations, allocator bookkeeping, parsed JSON,
the existing indexes, concurrent in-flight readers, and process RSS are not fully
represented. The code explicitly preserves the estimate-versus-physical-limit
distinction at `engine/src/store.rs:167`.

Low-priority test improvement: `engine/src/store.rs:340` verifies the calculated
weight against retained capacities directly. A behavioral registry-budget
refusal/close/reopen test would exercise integration in addition to the direct
arithmetic assertion. This review found the existing registry integration
unchanged and correct for its declared accounting contract; this suggestion is
not a newly demonstrated blocking defect.

## Baseline self-inspection and evidence reviewed

The supplied baseline evidence belongs to source
`39f49d500ad941b01f9a839978f0fca599d812c6`, evaluator
`b81f5adc2c647083b6ce8688234012c6d2da0ee4`, Ruby 3.3.13, Rails 7.2.4 and
Rust 1.90.0. Its report records `pass`, including both boundary probes, with
native SHA-256
`ee8002e57cf356a6a2ed59617c6fb90e5fbff18e447142e6c79db79d15009541`.
The tuple verification records pass and 3,408 core and 16 Map files verified.
These are inspected supplied results, not tests rerun by this reviewer.

I independently hashed the local retained packages:

- Core: `fc9fb44db77817dcb65dd9d4d23e601e0661b8116ebd4071c1c94b2d747d527e`.
- Map: `c19c41173588ea6929a675539cf549e429950442fe36382d49c1fa6edc472bf7`.

I opened `packages/thistle.gem` as a package archive and verified that its
15,972-byte `engine/src/store.rs` matches the captured baseline self-inspection
content byte-for-byte and hashes to
`45fb5d5f7c4f7fdc4ae14171537420ea094ca13a985b0cbf6377225d90063c10`.
The recorded source generation is
`bd7001faaf6cfcf361bf5d5f0088ee3d6a35eab73b5921f972373da735f5328b`.
That closes the earlier source-inspection prerequisite for this bounded patch.

## Outstanding gates

Candidate native/Ruby tests, installed quality checks with real Rails and both
probes, actual loaded-file identities, and Map smoke remain required for the
candidate tuple. Only after candidate qualification may the unchanged frozen
20-pair/four-A/A-per-mode policy compare the two installed artifacts. Keep the
baseline on any failed or inconclusive gate; no speed result was available to
this reviewer and none is approved here.

The supplied evidence itself labels hosted orchestration candidate-owned, with a
separately versioned frozen evaluator. It is development evidence, not a protected
external required check or hostile-worker isolation. All launch rows remain
unqualified.
