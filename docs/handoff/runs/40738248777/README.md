# Modern installed candidate — 2026-10-28

Bounded #20 development verification for exact candidate
`30a9156e283aa0ce0759ff4c5e9cd045dc731473`, tree
`c47897f25b13f9683da9811ae883171d1f3ae2e8`, base
`0b140570a86312041a8e4935795415699e511c14`.
[Run 40738248777, attempt 1](https://github.com/lost-in-the/thistle/actions/runs/40738248777)
used that same exact workflow driver and source SHA; this manual run did not
use a synthetic merge. PR #33 contains the driver repair and reviewed lock
policy. This report is outside gem contents under the existing `docs/handoff/`
exclusion. It does not relabel a later report-only head, updated main, or another
package as tested. The subsequent alpha README is a separate packaged change.

## Integrated-main prerequisite

Owner-authorized #27/#29 integration produced main
`0b140570a86312041a8e4935795415699e511c14`, tree
`f37ea4814f1bf1a19b5e15de30009e44f8d50c6a`.
[Main 40735966001](https://github.com/lost-in-the/thistle/actions/runs/40735966001)
and [Compatibility 40735966109](https://github.com/lost-in-the/thistle/actions/runs/40735966109)
passed, with zero check annotations. Main passed 47 automation tests, 16 native
tests, 28 Core tests / 237 assertions, 21 Map tests / 165 assertions, and package/
manifest verification. The earlier main automation failure and PR #27's failed
HTTP 429 download attempt remain unchanged. #28 completed its scoped repair.

## Attempts and exact bytes

The first installed run
[40736613316](https://github.com/lost-in-the/thistle/actions/runs/40736613316)
built source `0b140570a86312041a8e4935795415699e511c14`, prepared artifact
`12837323090`, archive SHA-256
`25ca721513397df965edb87e3ad3b2dcf63e1b7f614861a40d0bf3a85346dc71`.
Its Core package was
`afe325981e9fec3761e5f0890abbb74bd9e0641c14f059404a76339f41ac715e`.
Minimum installed verification passed; primary stopped **before evaluation**
with Bundler 4's removed `bundle cache --all` (exit 15). No primary installed pass
or artifact exists for that attempt. Minimum's actual-loaded native hash was
`f3b39ef79a92c64d636b8abc367f2c68253312ff21743887e862345ba6376c89`.
The minimum evidence archive `12838660212` was separately verified. That
success does not transfer to the repaired candidate below.

The fixed invocation uses `BUNDLE_CACHE_ALL=true bundle cache`, preserving
path/git caching without a persistent configuration file. A new candidate was
prepared once and its **same exact downloaded package pair** installed on both
modern cohorts. Independent actual ZIP downloads matched API digests:

| Artifact (prepared, primary evidence, minimum evidence) | Bytes | ZIP SHA-256 |
| --- | ---: | --- |
| `12838286772` | 15,112,552 | `0aed69489cf64f6eb650ae01e189f01524651bcab393942c0b61ab6f5a5c606d` |
| `12838093094` | 449,351 | `0fc71b232086037aceddf3922333332f1f64e50db5f0062307c6cd3d2ae25040` |
| `12837519764` | 446,903 | `17a5efd02eb9f86c8349e75120819f43b340d2154af48ccc4c5994d450e34c8a` |

- Core gem: `8747dfcb5668018cc6d31307cc4445d464bb46417d07f8b8ff68fe3cb9206795`.
- Map gem: `41527360a404e11aab3882a307ba4c55fa7466ec72085cc4505be24efd26a4a8`.
- Retained build-observation native: `c751675ae138417af81209a90fdbb3f9342f349ff4d7840ac81ea39d10a4a1ec`.

The build-observation binary is distinct from actual installed native identities:

| Cohort (Linux x86-64, Rails 8.1.4) | Recorded actually loaded native SHA-256 | Installed report SHA-256 |
| --- | --- | --- |
| Ruby 4.0.9 | `f4ddc79691337b3109bf34102976c511cb41e017f4a6a19f1f01daf54f76a275` | `93467ccd7e12efe97498558972854507b7301af7d24db9f5470445ee019a4b95` |
| Ruby 3.4.12 | `fee2330db2c6661aa2116f5cf5d201958aa0559e16bf5b4e3dfd867ee3bfac4f` | `39c06d646f8a65ae035b6a55e161f9b473116ef63b561b622d7274db0b7fee52` |

Both passed all 12 installed check groups, parser-worker and reader-boundary
probes, real Rails route checks, installed Map smoke, and exact self-capture.
Each arm verified 3,417 Core and 17 Map packaged/installed file identities.
Captured `engine/src/store.rs` hashes to
`027aad23b86a2dc20676b5544a42d3fa4523f345eb4045f948fbe31dd3a25e5e`.
This is exact source inspection, not Rust symbol/call-graph analysis.

Reports record Ruby/compiler/toolchain/native/dependency identities, commands,
probes and tuple checks. Rust remains 1.90.0, with the declared vendored/offline
Cargo build and libclang 18 route. All 15 evaluator source-file identities matched
frozen history `b81f5adc2c647083b6ce8688234012c6d2da0ee4`; preserved policy hash
is `14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe`.
The installed functional checks were reused; Experiment 001's campaign was not run.

## Reviewed dependency-lock disposition

Keep floating library development resolution with uncommitted, retained per-run
locks, as justified in [development decisions](../../../development/decisions.md).
A committed universal root lock or separate cohort locks would change compatibility
feedback and require additional update/selection machinery. These exact tested
resolutions remain distinct:

| Cohort | Bundler | Lock bytes | Lock SHA-256 | CHECKSUMS |
| --- | --- | ---: | --- | --- |
| Primary | 4.0.20 | 8,960 | `a66e6ed02f7393a3df6d531af2a314564e12dc0fe9ca540f144cc078ae43ed9b` | Present |
| Minimum | 2.6.9 | 3,513 | `261765a9b462a8d4403c78917769e3f42b68974d5f7bffc2a6f5fffb5fa0703c` | Absent |

Each installed report retains 43 dependency gem hash records. The primary lock's
platform alternatives are resolution variants, not tested platform support.
Checksums detect substitution after locking, not safe authorship. Locks alone do
not establish reproducible resolution, environment or byte-identical packages.

## Reviews, maintenance findings and remaining limits

Independent native `/root/ci_design_review` assessed lock alternatives, library
compatibility feedback, Bundler cache semantics and operating cost.
`/root/ci_evidence_review` independently downloaded all three archives and checked
manifest/package/native-report/payload/dependency/evaluator bindings. No blocker
was found within this scope. Its static audit receipt hashes to
`e8c595017af9cdd908c9afe7d37e6045fd9a275d05a2c291db8558bfe67847ec`.
The one-line cache repair passed 47 automation tests in 3.025 s, Bash syntax,
notes guard, both pinned Towncrier drafts and hosted source/installed checks.

All source-head check annotations were zero. Both installed downloads emitted
Node `DEP0005` (`Buffer()` deprecated) from pinned download-artifact. Preserve
this low-severity upstream maintenance finding; do not hide it with a runtime
override or unreviewed pin replacement. No removed `--all` warning remains.

Actual installed native binaries and dependency gem package bytes were **not
uploaded**. The reports' native/dependency hash bindings are verified as records;
this audit does not claim independently recovered installed binary bytes. Only
the build-observation native binary is retained. The current three artifacts
expire January 26, 2027 at 17:42:26 UTC. This is bounded candidate-owned evidence,
not durable release retention, reproducibility, hostile-worker attestation or
protected qualification. #24's exact historical bytes remain a separate record.

Acceptance/integration of PR #33 remains with the owner. Base changes, including
the alpha README, need an explicit affected-scope check/new intended candidate;
this record never qualifies changed packages by version label. #23 still owns
protected evaluator/result authority, #25 preview acceptance is separate, and all
17 launch capabilities remain unqualified. Implementation and evidence authors
cannot independently accept their own qualification claim.
