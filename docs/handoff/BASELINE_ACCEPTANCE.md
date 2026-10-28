# Hardened baseline acceptance: bounded development qualification

Selected baseline: source `39f49d500ad941b01f9a839978f0fca599d812c6`,
[run 40700690778](https://github.com/lost-in-the/thistle/actions/runs/40700690778),
artifact `12822385322`. Its accepted package/native tuple is:

| Component | SHA-256 |
|---|---|
| Core source gem | `fc9fb44db77817dcb65dd9d4d23e601e0661b8116ebd4071c1c94b2d747d527e` |
| Actually loaded native | `ee8002e57cf356a6a2ed59617c6fb90e5fbff18e447142e6c79db79d15009541` |
| Newly built Map gem | `c19c41173588ea6929a675539cf549e429950442fe36382d49c1fa6edc472bf7` |
| Evaluator source commit | `b81f5adc2c647083b6ce8688234012c6d2da0ee4` |

The frozen historical Map binary was not in the bootstrap repository. This run
built a new Map artifact from the restored unchanged Map source and qualified it
against the selected core; it does not relabel the historical Map hash as tested.

Executed on Linux x86-64, Ruby 3.3.13 (`af48f08f21`), Rails 7.2.4,
Rust 1.90.0 (`1159e78c4`), Cargo 1.90.0 (`840b83a10`), GCC 13.3.0,
libclang 18 and Ruby development headers. Cargo was locked/offline; explicit
local dependency gems were installed into fresh gem and Cargo homes outside
the source checkout. The report records their hashes and actual runtime files.

Passed: 14 native tests; 28 Ruby tests/237 assertions; 21 Map tests/165 assertions;
18 evaluator/policy unit tests; 12 installed check groups. These include the real
Rails GET/POST route lane, 10,000 nested arrays from a Ruby worker, digest-valid
110-level snapshot refusal and 40 interrupted reader constructions, plus
independent facts/source/links, mutation/pinning, invalid publication, paths,
limits, incomplete parsing and corrupt-source refusal.

The exact installed Map smoke passed. The wrapper verified all 3,408 packaged
core files and 16 Map files against installed bytes, all 3,378 vendored files
against package contents, and evaluator-recorded loaded core Ruby/native hashes
before/after Map and self-inspection. The vendor count includes checksum files;
the independent checksum inventory covers 3,323 entries across 55 crates.

That installed baseline captured its own packaged `engine/src/store.rs`: generation
`bd7001faaf6cfcf361bf5d5f0088ee3d6a35eab73b5921f972373da735f5328b`,
fact `485bacae29f5bbe030add88071d15144dcc7171e7befff39951db98e2cd40bc3`,
15,972 bytes, digest
`45fb5d5f7c4f7fdc4ae14171537420ea094ca13a985b0cbf6377225d90063c10`.
Exact source inspection informed the separately reviewed search experiment.
No Rust semantic analysis or full call graph is claimed.

Follow-up source `ba8ce8276b0f4496ac0bb654fa4a4e17e0a5e8d1` also passed the
complete hardened lane in run `40701531996`, artifact `12822495901`, with stronger
failure-output retention, immutable package/evaluator checks and compiler hashes.
Its core package is `ab95fc2b9bf8093fbbb4fdba8dab4c8a1a75822ab8b2bbe414b51b9d6cca419a`;
Map is `0c151df6515de55f1206dc9ca23c2117ad948446e35a48cf4f6548425e1f65ab`.
Loaded native and every payload file digest are identical to the selected tuple.
Package digests differ because archive file mtimes differ; reproducible package
bytes are not established. The experiment retains the originally selected exact
package rather than silently replacing it with the follow-up.

All three development CI cohorts passed at `ba8ce827...`: Ruby 3.0/Rails 6.1,
Ruby 3.3/Rails 7.2, Ruby 3.4/Rails 8.0. They are source feedback, not installed
support-matrix qualification. Earlier Ruby 3.0 runs failed at a `ruby -e`
`require_relative` harness invocation; changing it to an absolute require allowed
the Map tests to run and pass. Earlier failures remain available by run ID.

Full evidence is retained in the run artifacts and local downloaded archives.
[First report](runs/40700690778/baseline-report.json),
[tuple verification](runs/40700690778/tuple-verification.json), and
[follow-up report](runs/40701531996/baseline-report.json) are attributable records.
Review findings/dispositions are under [reviews](reviews/DISPOSITION.md).

This qualifies the narrow hardened package milestone using an unchanged,
separately versioned evaluator. Candidate-owned orchestration and shared runner
authority do not establish protected independence. No external required check,
branch protection, hostile-worker sandbox, broad parser/native safety, full
support matrix, launch parity, accessibility/user studies or release readiness
is qualified. All 17 launch rows remain unqualified. No merge or publication.
