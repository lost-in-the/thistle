# Selected historical evidence retention — 2026-10-28

Issue [#24](https://github.com/lost-in-the/thistle/issues/24). This records byte
availability and recovery, not installed qualification, experiment replay,
reproducibility, publication, or completion of a launch capability.

## Destination and authority

Reused the existing **private** `lost-in-the/thistle` repository and existing
owner access for an evidence-only **unpublished draft**. No new service,
credential, permission grant, plan change, published release or historical build.
This is the requested restricted retention/nonpublishing preparation, separate
from product release authority. Keep this draft unpublished.

Release ID: `426968373`. Use the stable authenticated
[release API record](https://api.github.com/repos/lost-in-the/thistle/releases/426968373)
or its [draft page](https://github.com/lost-in-the/thistle/releases/tag/untagged-968bb7f2f8abb5d72176).
Target/source context: `b3a2985af3388ac4bc784bccf57d89e0ea569358`.
The draft stores historical bytes; its target does not relabel their source.

Owner: LeahArmstrong / lost-in-the repository owners. Draft listings require
repository push access; recovery uses existing authenticated repository access.
Candidate execution receives none of these credentials. The
[release](https://docs.github.com/en/rest/releases/releases) and
[asset](https://docs.github.com/en/rest/releases/assets) APIs support this existing
boundary. This is independent of Actions artifact expiry, but drafts/assets remain
mutable and deletable by authorized writers. It is neither WORM storage nor
an off-provider backup, and cannot serve as a protected qualification verdict.

## Original availability and retained bytes

All four selected original artifacts remained available at download on October 28.
The original baseline (`12822385322`, run `40700690778`) expires November 27 at
13:58:41 UTC. Controller (`12821898684`), measured baseline (`12821819156`) and
candidate (`12822901065`), all run `40702407356`, expire November 27 at
14:10:21, 14:10:22 and 14:10:24 UTC respectively. Original API metadata, including
digests and expiry, is retained in the provenance archive. No original was deleted.

The four original ZIPs total **46,578,723 bytes**. The original eight destination
assets total **56,702,544 bytes**, including compressed provenance and receipts;
two later recovery receipts are additional small assets. ZIP hashes below were
verified against the original API digests, uploaded asset digests, and actual
freshly retrieved bytes. They are distinct from individual package/native hashes.

| Asset | Destination asset ID | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `12821819156.zip` | `685750929` | 15,506,810 | `eedbd14ab84840c3a706a8c88f56f318995b5e347626f0d558c4b15e0b2cc0d5` |
| `12821898684.zip` | `685750939` | 45,509 | `03c331015f53a5af36301f1621fac0f4d29d2f7cf33ef25d2553d24cf74df231` |
| `12822385322.zip` | `685750937` | 15,514,637 | `7bb9029a3adde2386ace7a91ebae1ac7365426e3fc9a7239bb80756f3ea3a108` |
| `12822901065.zip` | `685750936` | 15,511,767 | `07c625188caa0bdb446db29a0daf985345920002b77e3795ffcb5f21b2bb2a13` |
| `ASSET-SHA256SUMS` | `685751079` | 582 | `9b5aeaa03db63380b516f23927db6270383e1b01d9012c0f92ad0c9dac7b07d2` |
| `integrity-results.json` | `685751019` | 2,365 | `28a126b66f0b5cc453275c45ec1a24e1346f57f5cd3282574e6cd98e3b712bd9` |
| `inventory.json` | `685750978` | 15,985 | `5acd97d5ac5defd85c598c344042f75f311b9bb68d3f54b61b54b5f607bbbbe1` |
| `provenance.tar.gz` | `685750934` | 10,104,889 | `51b39133e722a619bc728f1b4eecf4b41c24618f964fc7706443337e5f8c96db` |

`provenance.tar.gz` additionally preserves all four original metadata records,
original inventory/integrity results, proposal and independent review disposition,
the original evaluator bundle, exact frozen policy, main's handoff/audit/failure
history, and measured-source orchestration. The inert historical controller
capture comes from `f424aa661804a013afc41a167f8afde47358f268`; evaluator history
is `b81f5adc2c647083b6ce8688234012c6d2da0ee4`, bundle SHA-256
`7d24cf43a1ca1c57456d2a009e70bec8cfea10895aff5f981c92ab448e6acb2d`.

## Separate payload and recovery verification

Fresh retrieval used the asset IDs above into a new mode-0700 directory;
source staging also remains restricted locally. All eight asset byte streams
matched staging and API digests. The separately retained checksum-file digest is
`9b5aeaa03db63380b516f23927db6270383e1b01d9012c0f92ad0c9dac7b07d2`.
All **92 inventory file hashes** matched after the explicit reconstruction below.
Every arm's 3,408 Core packaged file digests and 16 Map packaged file digests
matched recorded build/installed manifests. Gem/report/self-capture/native hashes
matched their tuple and quality reports; Cargo locks and 15 recorded evaluator
file identities matched. No candidate, Ruby/native or evaluator code was executed.

| Identity | Verified SHA-256 |
| --- | --- |
| Original and measured baseline Core gem | `fc9fb44db77817dcb65dd9d4d23e601e0661b8116ebd4071c1c94b2d747d527e` |
| Candidate Core gem | `98b9eac030a744a732ff88a5289bfe5603ca37b73d93e5c1ee13733c3d26c147` |
| Map gem in all three package records | `c19c41173588ea6929a675539cf549e429950442fe36382d49c1fa6edc472bf7` |
| Original baseline loaded native | `ee8002e57cf356a6a2ed59617c6fb90e5fbff18e447142e6c79db79d15009541` |
| Measured baseline loaded native | `2aab962c4a7b33297a82c9552ad1027dbcc353130d97b11c4874929b4c77e151` |
| Measured candidate loaded native | `f563f7d2a3872b48e6029e05d5ad38cb94c81b393a01f64cc3b343f51c0055cb` |
| Frozen experiment policy | `14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe` |
| Uncompressed comparison report | `30dcd79b5a8b9a55463d614dd5b10ea5e4b78acce12b4f3e79b3b01f9ff91fbe` |

The recovered comparison contains all 96 process attempts, zero faults, both
arm quality/native bindings, frozen policy and evaluator/workload-helper identities.
It exactly equals the decompressed retained historical report. Both distinct
baseline native installations are preserved, rather than substituting one.

Recovery attempt 1 **refused** the inventory check because the inventory included
six derived convenience files absent as standalone ZIP entries. Attempt 2 passed
after reconstructing them from retained bytes. This was a recovery-procedure
defect, not missing historical bytes. The failed attempt and correction remain
in `recovery-attempt-1.json` and `recovery-receipt.json` at the destination.

Both receipts were also retrieved by asset ID and their actual hashes verified:

| Receipt | Asset ID | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `recovery-attempt-1.json` | `685767304` | 486 | `4e2e3ee0d3c224270f5e4d35439cd1f9b7c2c747ad205bb3d25e98cc8966496d` |
| `recovery-receipt.json` | `685767306` | 4,493 | `7c37fdd65ed3c5c766f643624199a39ca04787fbb5662179830781b5567fa078` |

## Recovery procedure and monitoring

1. Authenticate with existing owner repository access. Check the repository is
   private and release `426968373` has `draft=true`, `published_at=null`.
   Never publish this evidence to obtain a stable-looking public URL.
2. List the release's assets and download the exact recorded IDs using
   `gh api repos/lost-in-the/thistle/releases/assets/ASSET_ID -H 'Accept: application/octet-stream'`
   into new restricted files under a fresh mode-0700 directory. Check the
   checksum-file digest against this versioned report before trusting its entries.
   Compare all assets to their SHA-256 values and original ZIP API digests.
3. Inspect archive membership before extraction: refuse absolute/traversing paths,
   symlinks and special entries. Extract each original ZIP beneath its artifact-ID
   directory; extract provenance under the fresh recovery root. Do not run code.
4. For each package artifact (`12822385322`, `12821819156`, `12822901065`), read
   `engine/Cargo.lock` from the Core gem's inner `data.tar.gz` and write those exact
   bytes as `Cargo.lock`. Read `baseline-self-inspection.json`'s `content`, encode
   UTF-8 and verify against its `sha256`, then write `captured-store.rs`.
   These six convenience copies are derived from historical bytes, never rebuilt.
5. Verify every path/size/hash in `inventory.json`. Independently bind Core/Map
   package digests, native bytes and report/self-inspection files to build/tuple/
   quality reports. Hash each gem payload member against packaged and installed
   file inventories. Verify evaluator bundle/history/file identities and exact
   policy bytes; bind raw comparison to both quality/native tuples, its 96 attempts,
   frozen policy and compressed historical copy. Preserve any failed recovery.
6. Record a dated receipt with release/asset IDs, all actual hashes and gaps.
   Recheck draft/private state and ownership. Retain the private local copy as
   an additional recovery source; it is not asserted to be an off-host backup.

Repository owner is responsible for the next retrieval before **2026-11-20**
(and before original expiry November 27), then quarterly and before relying on
this evidence. No automatic monitor/schedule or owner acceptance is fabricated.
If a check fails, report #24 and preserve the failed attempt; do not rebuild or
repeat the experiment to manufacture replacement bytes.

## Costs, limits and review

The existing release store avoids a new retention service or custom uploader.
GitHub documents up to 1,000 assets per release, each below 2 GiB, with no total
release size/bandwidth limit. Expected incremental storage charge is $0, inferred
from the [release quotas](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases#storage-and-bandwidth-quotas)
and [metered-product allowances](https://docs.github.com/en/billing/reference/product-usage-included),
not an account billing audit or a future price guarantee. Owner recovery checks,
continued GitHub access and mutation/deletion risk remain operating costs.
Reconsider an off-provider/WORM store if those risks exceed the owner's tolerance.

Original dependency gem/toolchain executable bytes are **not** present in the
selected four archives. Recorded identities, Ruby/Gemfile and Cargo locks,
source captures and toolchain manifests are retained; this does not establish
reproducible environments. Earlier failed-run ZIPs outside the selected four
were not fetched; the historical attempt index and audit dispositions are retained.
No missing evidence is replaced by a fresh build. Historical results stay scoped
to their exact original environments; all launch capabilities remain unqualified.

Independent native `/root/retention_inventory` reviewed archive/payload integrity
and destination fit. Its substantive findings required complete provenance
membership and fresh recovery before acceptance; both were implemented. Native
`/root/ci_evidence_review` independently checked the live private/draft boundary,
all ten asset records, both freshly retrieved recovery receipts, all 92 recovered
inventory hashes, policy/evaluator/raw-report bindings and archive membership.
No blocker was found. Its low-severity request to pin both recovery receipts in
this report is resolved above. Owner acceptance and report-PR integration remain
separate decisions; neither review establishes protected qualification authority.
