# Independent architecture and performance review

Reviewer: `/root/review_architecture`; 2026-10-28. Reviewed frozen implementation
`23ca426d8b2cc1da052492115748b60641ee4241` and evaluator
`b81f5adc2c647083b6ce8688234012c6d2da0ee4`. This is a static review of the
restored baseline and experiment readiness, not installed-artifact qualification.
No implementation or evaluator files were changed by this reviewer.

## Disposition

No additional blocking implementation defect was demonstrated in this review.
Baseline acceptance and experiment readiness remain blocked by the required new
installed-artifact evidence. Do not interpret this disposition as an approval of
the unbuilt package, protected evaluation infrastructure, performance, or launch.

## Qualification blocker

**Q1 — High, acceptance blocker: current installed baseline remains unqualified.**
`docs/experiment-001.md:3` requires baseline installed-artifact acceptance before
optimization, and `docs/experiment-001.md:14` requires self-inspection using that
accepted installation. The historical package cannot prove the new reader and
JSON-depth hardening. At review time no new core package/native tuple, installed
Rails route/probe report, or matching Map smoke result was supplied. Close this
with a newly built package evaluated outside the implementation checkout using
the unchanged evaluator, then record the exact source/package/native/evaluator
and toolchain identities. Missing dependencies or source-only tests do not close
this blocker. This is a known missing-evidence blocker, not a newly reproduced
code failure.

## Candidate review requirements

**R1 — Medium, required for the proposed cache: charge newly retained allocations.**
`engine/src/store.rs:152` currently charges only encoded fact/manifest lengths.
`engine/src/lib.rs:49` constructs a reader before the registry's 128 MiB/32-handle
admission check, and `engine/src/lib.rs:64` subtracts the weight on close. Adding
normalized records without adding vector and string allocation capacities to the
reader's charged weight would violate `docs/experiment-001.md:27`. Use checked or
saturating accounting, account for vector element storage and string capacities,
and exercise budget refusal, release on close, and a healthy open afterward.
Preserve the distinction stated in `README.md:105`: this charge still does not
measure the existing parsed JSON/index allocations or enforce physical RSS.
The in-flight `Arc` reader path (`engine/src/lib.rs:19`) also means that closing a
handle is not a general process-memory reclamation barrier.

**R2 — Medium, required semantic coverage: the frozen ASCII performance fixture
does not exercise several legal search edge cases.** `engine/src/store.rs:163`
lowercases the trimmed query; `engine/src/store.rs:167` lowercases names and paths
but preserves kind text; `engine/src/store.rs:169` compares an ID with the original
untrimmed query. Ordering in `engine/src/store.rs:175` uses the original name and
ID after assigning rank. A cache must preserve those rules exactly, including
Unicode lowercase expansion, null paths, custom mixed-case kinds, original-query
ID matching, duplicate display names, truncation and equal-rank ordering. Add
small semantic tests for these cases before interpreting performance results;
do not change the independent workload, thresholds or acceptance rules.

**R3 — Informational: source inspection identifies repeated work, not its total
benefit.** The current implementation scans every fact, allocates normalized
strings, and sorts all matches on each query (`engine/src/store.rs:166`). The
registered experiment deliberately changes only string preparation. Source
follow-ups, JSON/Ruby conversion, startup and reader validation may dominate
complete sessions. The frozen controller correctly charges startup and all
source follow-ups (`../thistle-eval/benchmark_workload.rb:67`), and compares median
paired ratios (`../thistle-eval/compare.py:86`). Do not broaden the patch to
ranking/top-k/storage changes or replace the primary metric after observing data.
The unchanged policy must retain the baseline on failure or inconclusive A/A.

## Architecture assessment and remaining scope

The source has the intended ownership: Rust captures, validates, publishes and
queries; Ruby supplies the facade and explicit Rails observations. Source blobs
are separate from immutable fact/manifest generations. Reader checks preserve
generation identity and distinguish integrity from freshness
(`engine/src/store.rs:210`). The parser worker explicitly states its larger stack
is neither a sandbox nor a deadline (`engine/src/capture.rs:77`). These are useful
boundaries and should survive the cache patch.

All 17 launch capability rows remain unqualified (`docs/capability-ledger.md:13`).
Retention/recovery, physical resource enforcement, full Rails/runtime coherence,
distribution cohorts, protected controller authority, complete customer jobs and
comparative value remain open. A successful local experiment closes none of
those launch gates. Candidate-owned hosted workflows can supply development
evidence; they do not establish independent protected qualification.

## Checks actually executed by this reviewer

- Verified local source HEAD is `23ca426d8b2cc1da052492115748b60641ee4241`.
- Independently hashed all 3,323 entries in the checksum manifests for 55 restored
  vendored crate directories: no missing or mismatched files.
- Confirmed all four legitimate `engine/vendor/cc/src/target/` source files exist
  and match their vendored checksums: `apple.rs`, `generated.rs`, `llvm.rs`,
  `parser.rs`.
- Verified Cargo lock SHA-256
  `79a4189e571a1d766b6565e8abf2819dcfc16cbea79990a4ae1560feaf062674`;
  baseline `store.rs` SHA-256
  `45fb5d5f7c4f7fdc4ae14171537420ea094ca13a985b0cbf6377225d90063c10`;
  frozen policy SHA-256
  `14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe`.

No native, Ruby, installed-gem, Map, benchmark, sanitizer or hostile-input test was
run by this reviewer. Rust and libclang were unavailable locally at review time.
Other agents' or historical test results are not counted as this review's tests.
