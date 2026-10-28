# Restoration and validation record

The repository moved to [lost-in-the/thistle](https://github.com/lost-in-the/thistle).
The [draft restoration PR](https://github.com/lost-in-the/thistle/pull/1) uses
`codex/restore-hardened-baseline`; main is not merged or published.

Restoration commit `fad98d58735cb6c5d13b5b806650feeeab9b88ee` joins the bootstrap
history and exact source commit `23ca426d8b2cc1da052492115748b60641ee4241`.
Its parents are `b116ed35f9c64561364b06a9c16aebe61e5814ed` and that source
commit. The evaluator history remains separate at
`b81f5adc2c647083b6ce8688234012c6d2da0ee4`.

Verified transfer archives:

| Archive | SHA-256 |
|---|---|
| Core bundle | `20c228ab0d450523d4f4d4c13635dd582be238423814cb5f1c888e0fb6fdabcf` |
| Evaluator bundle | `7d24cf43a1ca1c57456d2a009e70bec8cfea10895aff5f981c92ab448e6acb2d` |
| Evidence ZIP | `9423fc3942ed6e116c71869bb95b7568167a9e89f25ff35f44ebe2ab1cc225d4` |

Both bundles verify as complete histories. Independent reviewers checked all
3,323 vendored checksum entries across 55 crates, including all four legitimate
`cc/src/target` files, without missing or mismatched bytes. This is source
integrity evidence, not proof of parser safety or installed qualification.

The [one-time restoration run](https://github.com/lost-in-the/thistle/actions/runs/40699795668)
verified archives and built the restoration commit without executing candidate
code. Its final push failed because the workflow token lacked workflow-file
permission. The authorized connector then advanced the review branch to that
exact existing commit without force. The workflow itself is archived as
[restore-bootstrap.yml](restore-bootstrap.yml), not installed as an active workflow.
Its original transfer artifact is retained by run ID `40699795668`, artifact
`12821675586` (30-day hosting retention); the original bundles also remain here.

Root handoff documents are relocated here, with implementation links repaired.
Original bootstrap bytes are available from commit
`317671367949111861a63d0c3635dec94533fc8e`. The transferred `MANIFEST.json` and
`SHA256SUMS` describe the earlier expanded export; later bootstrap metadata and
these link repairs do not retroactively change their historical hashes.
The evidence ZIP remains byte-for-byte original.

The gemspec excludes `docs/handoff/`: importing archives and historical reports
must not silently enlarge the runtime package or pass them off as current evidence.
The entire vendored byte set remains included. The qualification wrapper compares
that complete set to the new package and checks installed core/Map files against
their exact packaged bytes, plus accepted loaded Ruby/native identities before
and after the Map smoke.

Review records and new run evidence are kept under this directory, outside the
gem file set. Candidate-owned hosted workflows are development feedback, not an
independent protected qualification service. No release credentials, privileged
fork event, automatic merge, or gem publishing is configured.
