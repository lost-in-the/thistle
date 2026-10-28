# Experiment 001 — Reuse normalized search text

Status: hypothesis registered before the candidate comparison. The initial
correctness baseline must pass independent installed-artifact evaluation first.

## Evidence and hypothesis

The initial Rust `Reader::find` constructs lowercase names, lowercase paths and a
formatted search string for every fact on every query. Source inspection identifies
repeated work; that observation alone does not establish an important bottleneck.
The independent evaluator measures reader opening, queries, source follow-ups and
the entire session before deciding whether a change is useful.

Use the accepted installed baseline to capture its own packaged source, query the
`engine/src/store.rs` file fact, and retrieve the exact source with generation and
digest. Record the gem digest, actually loaded native-library digest, compiler,
Ruby tuple, Cargo lock digest, release profile and available source symbols.
The first source view records Rust files accurately; it does not infer Rust
symbols or a complete native call graph.

Hypothesis: constructing immutable normalized search records once when a reader
opens will reduce the complete cost of repeated investigations while preserving
every result, rank, source reference, coverage label and error.

## Bounded change

Change only native reader search preparation and reuse. Charge allocated search
strings/vector storage in cache admission accounting. Do not change capture,
ranking, result limits, expected answers, corpus or evaluator policy. Keep the
unmodified baseline artifact and rejected attempts.

## Decision fixed before measurement

Run the external evaluator's frozen generated corpus (400 classes and 2001
declarations), exact expected facts/source, single-query-plus-source sessions and
100-query-plus-10-source sessions. Use 20 paired randomized candidate/baseline
trials per session type plus A/A calibration. Every unsuccessful attempt remains
in the report. Use warm OS file caches and fresh worker processes as explicitly
declared by the evaluator; this does not claim uncached extraction performance.

The primary complete-session metric is `process_until_results_seconds`, including
Ruby/native process startup. Decisions use the median of paired candidate/baseline
ratios, not a ratio of independent medians. Reader-open-and-sequence and warm-query
timings are secondary diagnostics. Retain the change only if:

- Both exact artifacts pass the same independent functional checks, and all
  comparative result/ranking/coverage/source checks agree.
- The repeated-session primary median paired ratio is at most 0.90.
- The single-query primary median paired ratio is at most 1.10.
- Both initial and warm peak-process RSS median paired ratios are at most 1.20
  in each session mode.
- The A/A primary median paired ratio differs from 1 by at most 0.05 in each
  session mode; otherwise treat the speed verdict as inconclusive.

These are this experiment's engineering tradeoff rules, not population confidence
bounds or launch qualification. Report distributions and absolute costs as well
as ratios. An inconclusive or failed required check does not pass; retain the
baseline and record the result rather than tune the acceptance policy afterward.

## Claim boundary

This tests a local change to one early native implementation. It does not compare
Thistle with Woods, establish general market advantage, validate all workloads,
or prove autonomous self-improvement. A retained patch demonstrates one
source-informed, independently evaluated development cycle.
