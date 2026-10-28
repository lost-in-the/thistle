# Independent audit of experiment 001 results

Reviewer: `/root/review_architecture`, 2026-10-28. Audited the retained report and
package/native evidence from hosted run `40702407356`; no benchmark was rerun and
no implementation, evaluator, fixture, or policy was changed. Recomputed results
are also retained in `experiment-results-audit.json` beside this review.

## Disposition

**The retained evidence supports `retain_candidate` under the unchanged frozen
development policy.** No arithmetic, trial-count, semantic-identity, artifact-
binding, or required-gate blocker was found in the audited record. This is one
synthetic development workload on one hosted worker, not protected external
qualification, a Woods comparison, a population inference, or launch approval.

The audited experiment report SHA-256 is
`30dcd79b5a8b9a55463d614dd5b10ea5e4b78acce12b4f3e79b3b01f9ff91fbe`.
Its policy SHA-256 is unchanged:
`14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe`.
The embedded policy equals the frozen evaluator policy byte-identity record's
parsed content; the controller and workload-helper hashes match the separately
versioned evaluator files in `/workspace/thistle-eval`.

## Independently recomputed gates

For every metric below I computed `median(candidate_i / baseline_i)` from the raw
paired measurements, not a ratio of independent medians. All values matched the
controller summaries exactly using Python floating-point arithmetic.

| Mode | Complete-session paired ratio | Frozen maximum | Initial RSS paired ratio | Warm RSS paired ratio | A/A complete-session paired ratio |
|---|---:|---:|---:|---:|---:|
| Single | 1.0032596685669128 | 1.10 | 1.007435919384292 | 1.007435919384292 | 1.0020280246429478 |
| Repeated sequence | 0.7131717962441166 | 0.90 | 1.0059534309402012 | 1.0049372170711064 | 1.0052832655451103 |

All four RSS gates are at most 1.20. Both A/A timing ratios are within
`[0.95, 1.05]`. The primary metric is `process_until_results_seconds`, including
Ruby/native startup and the declared source follow-ups, rather than warm-query
time. The observed repeated-session paired reduction is about 28.7%; the single
session has an observed paired increase of about 0.33%, within the frozen gate.

For scale, independent raw timing medians were 0.093293 s baseline versus
0.093587 s candidate for single sessions, and 0.185986 s versus 0.132520 s for
repeated sessions. These absolute medians are descriptive; they were not used to
replace the paired-ratio decision.

## Trial completeness and semantics

- Exactly 20 A/B pairs and four A/A pairs occurred in each mode: 40 comparison
  pairs, eight calibration pairs, and 96 product-process attempts in total.
- Every attempt is recorded as passed. Every raw pair maps to the corresponding
  attempt and measurement without omissions. The report's faults array is empty.
- Pair indices are complete and sequential per mode. I reproduced all randomized
  role orders using seed `20261028` in the frozen controller's declared sequence.
- Every single trial ran one query and one source follow-up; every sequence trial
  ran 100 queries and ten source follow-ups.
- All raw trials have finite positive primary/RSS measurements. Every trial's
  semantic hash matches its mode's common hash. Every trial's generation matches
  the selected arm's captured setup generation. These are the evaluator's strict
  query/ranking/source/coverage projections with only the declared generation
  normalization, not a new looser projection.

## Exact artifact and qualification binding

| Arm | Source commit | Core package SHA-256 | Measured installed native SHA-256 |
|---|---|---|---|
| Baseline | `39f49d500ad941b01f9a839978f0fca599d812c6` | `fc9fb44db77817dcb65dd9d4d23e601e0661b8116ebd4071c1c94b2d747d527e` | `2aab962c4a7b33297a82c9552ad1027dbcc353130d97b11c4874929b4c77e151` |
| Candidate | `f424aa661804a013afc41a167f8afde47358f268` | `98b9eac030a744a732ff88a5289bfe5603ca37b73d93e5c1ee13733c3d26c147` | `f563f7d2a3872b48e6029e05d5ad38cb94c81b393a01f64cc3b343f51c0055cb` |

I independently hashed the retained core/Map packages and native files. I also:

- Checked the experiment's quality-report hashes against the exact retained
  reports and tuple-verification records.
- Checked that both quality reports pass all 12 groups, including Rails 7.2.4,
  the 10,000-array parser-worker probe and the interrupted/deep-reader boundary
  probe, with helper hashes matching evaluator revision
  `b81f5adc2c647083b6ce8688234012c6d2da0ee4`.
- Checked every trial's actual recorded native and Ruby file identities against
  its selected arm's exact quality report. Each Ruby file hash also matches the
  corresponding file in the retained gem payload; each native hash matches the
  retained native binary. A/A trials bind to the baseline installation under
  both role labels.
- Compared all package payload file hashes between arms. The only core payload
  difference is `engine/src/store.rs`; both Map artifacts are identical with
  SHA-256 `c19c41173588ea6929a675539cf549e429950442fe36382d49c1fa6edc472bf7`.
- Checked every core/Map package payload file against the installed-file identity
  manifest and tuple record. Both tuple records pass.
- Checked the installed Map smoke passes for each arm, names its matching native,
  and reports Woods absent and source-checkout load paths absent.
- Checked each arm's self-inspection content against that arm's packaged
  `store.rs` byte-for-byte. Their source digests are respectively
  `45fb5d5f7c4f7fdc4ae14171537420ea094ca13a985b0cbf6377225d90063c10`
  and `027aad23b86a2dc20676b5544a42d3fa4523f345eb4045f948fbe31dd3a25e5e`.
- Checked compiler descriptions, recorded toolchain binary identities, Cargo
  manifest/lock, native build command, Ruby runtime and loaded gem/dependency
  identities agree between arms.

The comparison's baseline native is `2aab962c...`, from its fresh current
installation and qualification. It differs from the earlier first-baseline
native `ee8002e5...`; the record correctly requalifies and binds the actual
comparison installation. The earlier binary is not substituted as evidence for
the measured one.

## Limits and remaining blockers

No new blocker was found for this bounded development retain/reject decision.
The evidence is retrospective audit of supplied records; this reviewer did not
observe worker isolation or rerun native/Ruby/Map tests. Exact file/hash binding
supports attributable results, not immunity to a malicious candidate sharing
worker/controller authority.

The orchestration is candidate-owned hosted development feedback with a frozen
separately versioned evaluator. It is not the protected independently controlled
required check, hostile-worker sandbox, release provenance, or branch policy
needed for launch. OS caches were shared and warm; measurements describe fresh
product processes, not cold-disk extraction. RSS is the product-process peak for
this workload, excluding controller, build/install and kernel cache; logical
cache charges do not enforce physical memory limits. The sample supplies no
population confidence claim and does not qualify other applications or the
Woods comparison. All 17 launch capability rows and broader security/support/
customer-outcome gates remain unqualified.
