# Basic main protection: activation record

On October 29, 2026, the separately authorized basic protection was activated as
rule [`26097789`](https://github.com/lost-in-the/thistle/rules/26097789).
Main was `cea4d04039093586e29070d95a8648de2b8bb760` before and after the write.
This records basic repository enforcement, not independent qualification.

| Identity | Recorded scope |
| --- | --- |
| Source at activation | Main `cea4d04039093586e29070d95a8648de2b8bb760` |
| Policy artifact | Approved request SHA-256 `2fb4ece45d620e257f87534cdb6f423afdde9611e8f319dafbca1c6e20d06bee` |
| Package artifact | Not applicable: this administrative operation built or installed no gem |
| Product native identity | Not applicable: no Thistle native component executed in this operation |
| Package evaluator identity | Not applicable: no package evaluator ran; the proof and independent reviews inspect repository-rule behavior and receipts |
| Protected qualification identities | Unavailable: the independent controller/authority has not been created or proven |

## Active policy and readback

The rule is active only on `refs/heads/main`, with no bypass actors:

- Native PR association and resolved review threads.
- Strict current-base `CI / required` and `pii-check / pii-check`, each bound
  to the GitHub Actions App `15368`.
- Deletion and non-fast-forward updates prohibited.
- Zero machine-required approvals; substantive peer review remains procedural.

The immediate preflight verified the authorized administrator, absent prior
configured/effective rules and successful exact-main checks from App `15368`.
One production POST returned HTTP 201. Configured and effective readbacks matched
the approved request, allowing only the four previously reviewed GitHub PR
defaults. The actor's `current_user_can_bypass` was `never`; the branch reported
`protected: true`. No negative probe or ref update targeted main.

An independent review repeated the configured/effective/main/check-source reads,
verified all 16 retained archive hashes and found no blocker. Retained receipts
show one POST followed by reads; they are not a complete server write audit.
The legacy protection subobject is not the effective ruleset readback.

## Proof and preserved history

The owner accepted native PR-association behavior and required proof before
activation. Independent review supported the combined disposable controls:
missing and failed checks, a never-associated head with genuine successful push
checks, unresolved threads, force/deletion refusal, nonmerging green eligibility,
strict freshness and rule restoration. The final strictness-only comparison used
fixed commits and unchanged checks/reviews; eligibility changed from `behind` to
`clean` only while strictness was false, then returned to `behind` on restoration.
No merge or ref update occurred while loose. Strictness was restored before PR67
closed unmerged and its temporary rule/refs were removed.

The [original October 28 proof](../issue23-basic-protection-2026-10-28/README.md)
remains **failed** under its blanket-direct-update criterion. An eligible PR head
can integrate through a native direct ref update; the owner explicitly accepted
that narrower behavior. Earlier stopped/inconclusive attempts and their historical
post-refusal merge-inventory limitation remain unchanged. Valid bounded controls
retain their own scope; a failed whole attempt is not relabelled as passed.

Public checkpoints: [final disposable handoff](https://github.com/lost-in-the/thistle/issues/23#issuecomment-6487564503),
[root proof acceptance](https://github.com/lost-in-the/thistle/issues/23#issuecomment-6487710303),
and [activation/readback](https://github.com/lost-in-the/thistle/issues/23#issuecomment-6487749038).
Raw receipts and independent reviews remain in restricted local retention.

## Integrity, recovery and remaining limits

- Approved production request SHA-256:
  `2fb4ece45d620e257f87534cdb6f423afdde9611e8f319dafbca1c6e20d06bee`.
- Final disposable attempt11 index SHA-256:
  `79b2fe3a91c0f2dd3d5b1a8968a2a5823114b5a49e368b18aa0c969cd2e7eb44`.
- Restricted activation report SHA-256:
  `cdc4a47c2e3bb40f192c203c6f32dfa2c823b1d231b5cfbd206cefd0b8759bf6`.

Root is this session's retention custodian; Leah retains owner acceptance.
The restricted activation packet `basic-main-activation-20261029` includes the
request, raw responses, exact comparison, hashes and recovery note. Verify those
hashes before relying on the record or pruning data; retain the separately indexed
attempt11 and independent reviews too. Same-host storage is not immutable or an
off-host recovery guarantee. A future rule change/removal requires applicable
owner authorization; no main bypass or protection-removal recovery was granted.

Candidate-controlled same-App checks do not establish independent evaluation.
No qualification controller, distinct App, new credential, promotion rule or
publication was created. Issue #23's broader authority remains Check / Needed,
and all 17 launch requirements remain unqualified.
