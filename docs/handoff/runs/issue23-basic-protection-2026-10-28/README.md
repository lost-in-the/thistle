# Basic protection proof: stopped after an unexpected success

This is ordinary repository-control evidence for issue #23, not independent
qualification. The original proof did **not** pass. Main activation was withheld.
The [public disposition](https://github.com/lost-in-the/thistle/issues/23#issuecomment-6483149471)
and [structured command/result receipt](outcome.json) retain the actual outcome.

## Unexpected direct update

With temporary ruleset `26083802` active only on the disposable target, the
authenticated actor issued:

```text
PATCH repos/lost-in-the/thistle/git/refs/heads/proof/thistle-basic-main-20261028
{"sha":"20871a6bce77005434b5751c369ed23ef579f7dd","force":false}
```

GitHub returned **HTTP 200**, advancing that target from
`241823b613f95715e81f13f09af4fa0cb3a79395` to the requested head. That head belonged
to an opened, up-to-date PR whose two required contexts were green and conversation
was resolved. GitHub marked [disposable PR #45](https://github.com/lost-in-the/thistle/pull/45)
merged indirectly. The request was a negative control expecting refusal, not an
authorized positive-control merge. Its unexpected success is preserved as a
failed negative control; it is not relabeled as a passing non-merging proof.

GitHub documents the native PR rule as requiring changes to be associated with an
opened PR. This does not establish an exclusive merge endpoint. The original
blanket-direct-update expectation was too broad. See the
[rules documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).
Accepting that narrower native scope needs an explicit owner decision and a fresh,
completed proof before main activation.

## Results and limits

| Control | Observed result |
| --- | --- |
| Force push | HTTP 422: explicit force-push prohibition; target unchanged |
| Branch deletion | HTTP 422: explicit deletion prohibition; target unchanged |
| Required CI failed | HTTP 405 naming failing `CI / required`; up-to-date head; target unchanged |
| Required CI absent | HTTP 405 naming expected `CI / required`; context absent before and after atomic attempt; target unchanged |
| Unresolved conversation | HTTP 405 naming the conversation, with both required checks green; target unchanged |
| Green eligibility | `clean`, mergeable, non-draft, exact head/base; no merge attempt for this positive control |
| Direct update of that eligible PR head | **Unexpected HTTP 200**; disposable target advanced and PR became indirectly merged |
| Genuine stale-base refusal | Unrun after stop; not a pass |
| Recovery/restoration enforcement | Unrun after stop; cleanup is not a substitute |

The contexts were `CI / required` and `pii-check / pii-check`, from ordinary
GitHub Actions App `15368`. The temporary rule had no bypass actors and zero
required approvals. This does not protect against candidate-authored same-App
lookalikes or establish independent policy authority.

The coordinator's command batch did not abort on the unexpected-success command's
nonzero process result and ran one subsequent setup force-update of the disposable
source to `80721a2266a73a66bffea412dacfcc377e21d72a`. That was an orchestration
error. It changed only the disposable source; no next control or production rule
activation ran. The unexpected-success API receipt and the subsequent source
state are retained. The source-update command/result appeared in the coordinator
transcript, but a standalone raw API receipt for that followup was not located in
the retained packet; the observed final source state does not reconstruct it.
The stopped proof's helper now
rejects further administrative mutations; a continuation needs a fresh proof and
explicit failure fencing between dependent operations.

## Cleanup and retained identities

After ownership/readback verification, rule `26083802` and both remote proof refs
were removed. Main stayed exactly
`b53d64c6edf46e30b81b1c2cf91e94f4bb2f408e`; repository rulesets and main effective
rules read back as empty. No App, credential, controller or publication was created.

Five signed commit objects, every API receipt and the failed attempts remain in
restricted retention. The 19,266,056-byte Git bundle has SHA-256
`754d4b7d5a05facf10b48cd6411c8922dd0e9179d34a06ab55055e6cb4799ff5`.
Its commit objects were recovered into a fresh bare repository and checked again.
The exact source identities are in the structured receipt. No private application
source or captures are included in this report. All 17 launch capabilities remain
unqualified; #23's qualification authority remains Check / Needed.
