---
name: thistle-build
description: Implement an assigned Thistle outcome or lead bounded Rust, Ruby, C bridge, Map, or delivery workers. Use for source changes and technical convergence under an existing task contract.
---

# Build

Read `AGENTS.md`, the assigned issue/contract and
[Dev Lead](../../../docs/development/roles/lead.md). Follow
`docs/development/pr-ci-release.md` for actual gates.

1. Verify the admitted base, workspace and current claims before editing. Record
   the real task identity and obtain explicit ownership of shared files/interfaces.
   Use isolated worktrees for independent writers.
2. Give each child the role, contract, candidate/base, owned scope, allowed
   resources, acceptance checks and return format. Children must not depend on
   inherited conversation history. Use the
   [T3 procedure](../../../docs/development/agent-team.md#t3-and-two-hosts)
   when available; explicit briefs also work without it.
3. Implement a complete bounded outcome. Reuse maintained solutions when their
   fit is justified. Keep Rust ownership, the Ruby observation boundary and C
   lifetimes explicit; preserve resource, uncertainty and accessibility contracts.
4. Reproduce demonstrated defects with meaningful focused checks. Check failure
   propagation, refused/partial inputs and relevant lifetimes. Use existing tools;
   avoid tests that merely repeat implementation or broad speculative reruns.
5. Arrange independent review and applicable artifact/customer QA early, within
   the assignment's authority. Use the bounded review loop below. Batch related
   corrections before settling packages; preserve changed-byte evidence and failures.
6. Use the authorized signer and an ordinary reviewed PR. If signing is unavailable,
   retain the reviewed working changes and stop the signed delivery step; do not
   disable signing or publish an unsigned substitute.

## Bounded review loop

Use one independent reviewer for the normal full initial pass, without reviewer
subagents, panels or consensus scores. Discover installed capabilities before
selecting a provider/model; prefer another available provider only within existing
access and evidence-egress authority. Missing access is a reported gap, not a
reason to provision another provider. An assignment may retain an existing review
slot with its integration owner rather than launch one from the writer.

Supply a complete brief: read-only role and no delegation, customer outcome,
contract, exact head/base and complete diff, owned/excluded paths, raw evidence,
permitted checks and resource limits, known gaps, and return format. Do not rely
on inherited history. Apply [Review](../thistle-review/SKILL.md) and retain stable
finding IDs with severity, evidence and disposition: open, fixed, disputed or
deferred with a responsible owner.

Batch verified corrections. Later passes cover changed code and unresolved
findings, with the original brief, retained ledger and changes since review.
Three rounds is a ceiling, not a target; stop earlier when the applicable scope
is resolved. A new T3 review/re-check uses a new review task, not a thread message;
follow native completion delivery rather than polling or overlapping reviewers.
Missing, failed, skipped or timed-out review is not approval. At the ceiling or
a persistent technical disagreement, send both positions and evidence to the
technical integration owner; actual product or authority choices go to the owner.
The owner's disposition must still satisfy the [review standard](../../../docs/development/pr-ci-release.md#review-standard)
and [material-correction/scoped-review requirements](../../../docs/development/agent-workflow.md#multi-agent-operation);
the round ceiling waives neither an open blocker nor a required scoped disposition.

Reuse applicable unchanged evidence with its exact identity and scope; do not
require a personal rerun merely to repeat it. Changed behavior, artifacts, base
or a concrete gap may require affected checks under the existing gates. This loop
adds no merge, qualification or publication authority.

Return implemented behavior, exact candidate, executed checks and their scope,
unresolved findings, applicable next gate and released claims. Do not silently
mark the issue Done, qualify a capability or publish a release.
