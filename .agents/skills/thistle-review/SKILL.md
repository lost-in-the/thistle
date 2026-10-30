---
name: thistle-review
description: Independently review a Thistle change for correctness, security, resource cost, accessibility and lasting design quality. Use for substantive Rust, Ruby, native boundary, Map or workflow review.
---

# Review

Read the [Reviewer role](../../../docs/development/roles/reviewer.md), the assigned
contract and the [review standard](../../../docs/development/pr-ci-release.md#review-standard).
Inspect the actual candidate and raw evidence before adopting the author's
explanation. Read only relevant specialist material.

1. Verify the exact head/base, complete diff and scope. The normal initial pass
   covers the full change; subsequent passes cover changed code and unresolved
   findings under the [bounded review loop](../thistle-build/SKILL.md#bounded-review-loop).
   Trace affected callers and consumers; a plausible local implementation can
   still break the complete job. Do not start additional reviewers or subagents.
2. Challenge affected costs and boundaries:
   - Rust/C: avoidable clones/materialization, asymptotic work, retained memory,
     locks, handles, error/panic paths, GVL and allocation ownership.
   - Ruby/Rails: reflection versus application dispatch, inherited/effective
     metadata, mutable framework state and honest source/runtime coherence.
   - Map/API: pinned evidence, partial/no-match distinction, escaping/access,
     keyboard/IME/no-JavaScript use, response bounds and vocabulary.
   - Delivery: failure propagation, stale evidence, trusted/untrusted execution,
     dependency/runtime support and excessive CI or package work.
3. Prefer a concrete counterexample or focused reproduction for a finding.
   Separate a defect from an optional improvement; explain the consequence and
   smallest complete remedy. Reject fixes that only move cost elsewhere.
4. Report each material finding once with a stable ID, location, scenario,
   evidence, severity rationale and acceptance effect. Preserve IDs and mark prior
   findings resolved or still open with reasons. A rare path or small repeated
   cost is not automatically a nit; assess its security, lifecycle and complete-job
   consequences against the review standard. A clean result is valid; do not
   manufacture criticism or insist on repeated consensus.
5. Return unresolved disagreements to the technical owner with evidence. Another
   review round needs changed code, a concrete objection or missing evidence.

Retain applicable unchanged evidence without a ritual personal rerun. Name the
reviewed identity and any applicability limits; missing or failed required
evidence cannot become approval. Reviewers never subscribe to PR watches.

Review is read-only unless the assignment separately grants a correction scope.
A prompt or approval-required mode is not an enforced read-only sandbox. Do not
run candidate code with credentials or claim evaluator independence merely
because another agent/provider performed the review.

Return findings, meaningful improvements, reviewed identity, checks actually
performed and residual limits. Give the lead one consolidated disposition.
