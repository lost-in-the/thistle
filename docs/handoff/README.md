# Thistle

Private development handoff for a new Rust evidence engine distributed as a Ruby gem, with an optional Map and independent evaluator.

**Start with [CODEX_HANDOFF.md](CODEX_HANDOFF.md).** This repository currently holds the complete source history as Git bundles and the reviewed continuation plan. The next Codex task should import the source on a review branch, rebuild and independently qualify the hardened baseline, then run the predeclared introspective optimization experiment. No launch parity or performance advantage is claimed.

## Included

- `thistle.git.bundle`: complete core and Map source history, current commit `23ca426d8b2cc1da052492115748b60641ee4241`.
- `thistle-eval.git.bundle`: independent evaluator history, commit `b81f5adc2c647083b6ce8688234012c6d2da0ee4`.
- `ARCHITECTURE_PLAN.md`: current architecture and launch plan, including mandatory Rust.
- `IMPLEMENTATION.md`: implemented behavior, review findings and explicit limits.
- `EVALUATOR_HANDOFF.md`: exact artifacts, qualification commands and frozen benchmark policy.
- `HANDOFF_EVIDENCE.zip`: reports, review records, source manifest and checksums. The historical gem bytes and compiled local runtime are not source repository deliverables.

The latest local checkout passed 28 tests and 237 assertions. The previous packaged gem passed installation checks before additional reader and path hardening; those results cannot qualify a new package. The first task is to rebuild and run the updated independent evaluator.

Rust owns capture, validation, storage, publication and querying. Ruby is the gem/Rails boundary, with a small C bridge. No console or Woods engine code belongs in this project. Authorized Map reuse keeps its original license attribution.
