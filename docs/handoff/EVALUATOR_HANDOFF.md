# Thistle evaluator handoff to Codex

Frozen on October 28, 2026 at the user's request for immediate handoff. No new implementation, rebuild or candidate benchmark is being run as part of this handoff. This document records a local workspace handoff; it does not assert that a remote Codex task or repository was created.

## Current state

The installed-artifact evaluator lives in `thistle-eval/`, separately from the runtime gem. It installs supplied local gems into a fresh worker `GEM_HOME`, uses an empty worker-local `CARGO_HOME` with Cargo offline, runs from outside the source checkout, checks actual loaded core Ruby/native file hashes and checks that Woods is absent. This is not an OS sandbox: protected CI/controller authority still needs separate infrastructure.

The last fully executed installed report passed **11 check groups** on Ruby 3.3.13 and Rails 7.2.4. It verified independent declaration/source/span/link expectations, deterministic generations, mutation freshness and old-generation pinning, invalid publication, identity/limit refusals, symlink containment, parse-error incompleteness, corrupt-blob refusal, real Rails route observations with unknown source coherence, and the 10,000-nested-array Ruby-worker-thread parser regression.

**That package predates newly fixed reader-construction and empty-path issues. It is historical evidence, not the current deliverable candidate.** The current checkout contains additional JSON-depth, interrupted-constructor ownership and empty-path hardening. The root agent reports 28 checkout Ruby tests / 237 assertions passing, but no source gem containing that latest hardening has been built and independently qualified yet.

The independent evaluator has already gained `reader_boundary_probe.rb`: a digest-valid 110-level manifest is repeatedly refused; a forced post-native-open handoff is interrupted 40 times; a healthy reader must still open afterward. The probe independently rejected the older installed artifact with `JSON::NestingError`, confirming the concrete missing boundary. It has **not** yet passed against an installed package of the hardened checkout. It is now required by the evaluator and experiment controller.

## Exact artifacts and evidence

| Item | SHA-256 / state |
|---|---|
| Historical core package `thistle/pkg/baseline/thistle-0.1.0.pre.1.gem` | `6a284dbf691f7fa3e3e97c9b1219b5d98242c0a1df1c5930d2bfa3d80d1de8bf` |
| Its actual installed native `thistle_native.so` | `cb3870d86268099cc23dcd8010316f2c130047bff15bc92404bb3fcc786bff11` |
| `thistle-eval-runs/baseline-report.json` | `6e29cb99f31c05ca652bea18c801ef716fab4efe80301cdee26b72aa86525d09`; historical pass before reader boundary coverage |
| Evaluator revision used for that report | `4f05823fbeccc804d34a6288402ced4ab9ce29893502e9e71d2e3c449a3aaa62` |
| Current `thistle-eval/evaluate.py` | `21baf119f6bc7d3eebe7b5e4105866cc039c27b533081773dab0fc16bfffffce` |
| Current `thistle-eval/compare.py` | `366a1350318a1552aad6d1688a0a8f340fe20ef8dc5ed9c99811290db21c567c` |
| `thistle-eval/benchmark_workload.rb` | `a29dbfbfee62a2d439c902bffacb50df03354cba8ea47a680c94ab5c1414a6ed` |
| `thistle-eval/parser_probe.rb` | `004d8361d8403fe2ae83864e453ffcd4bbd534439e7ca3b7eac0b8ce96bbe3de` |
| `thistle-eval/reader_boundary_probe.rb` | `766d99e26cd6f6cb02e6c7e4a8f701d4606f33a87e5a06403956ddabe8f48bc4` |
| Optional Map package `thistle/map/pkg/thistle-map-0.1.0.pre.1.gem` | `714b645e498ea2468311ee58dea81218b17bfbe8a7663084927bb8505ec9c697` |
| Map installed baseline report | `thistle/map/pkg/installed-baseline-report.json`, SHA `44f4a36ff92b24aaf5d733f3e1622eda6368951af35e2139c1d7b83ee1d531fb`; passed with historical core/native above |

The current evaluator/policy unit suite last passed **18 tests**. A baseline-versus-itself harness smoke passed at the full 400-class / 100-query fixture, with one pair plus one calibration pair per mode and no faults. It was harness validation only. **No optimized candidate was benchmarked; no speed improvement or retained optimization is claimed.**

Earlier evidence is intentionally retained: attempt 1 exposed the evaluator's misplaced RubyGems `--norc` flag; attempt 2 exposed a real package filter that omitted vendored directories named `target`; attempt 3 passed before Cargo-home isolation and the installed parser regression; attempt 4 passed with those additions. The package filter now preserves the entire vendored byte set. `pre-hardening-boundary-negative-control.json` records the later reader-boundary rejection. Do not overwrite these reports with new verdicts.

## First task in the new Codex session

Rebuild the **hardened baseline**, then qualify the actual installed gem before implementing the search optimization. Keep all correctness hardening in both arms of the later experiment.

1. Read the root handoff, `thistle/IMPLEMENTATION_CONTRACT.md`, `thistle/docs/experiment-001.md`, and `thistle-eval/README.md`.
2. Prepare Linux, Ruby 3.3.13, Rust 1.90.0, a C compiler and libclang. The Rust dependency set is vendored and locked. The local runtime paths below are scratch conveniences, not portable prerequisites.
3. Run current checkout native/Ruby tests and package checks. Preserve the complete vendored tree when building the gem.
4. Build into a **new** artifact directory; do not replace the historical `pkg/baseline` package.
5. Run the current independent evaluator with `--rails`, the parser probe and the reader-boundary probe against that installed package. Missing or failing new boundary evidence blocks acceptance. Fix the concrete issue and preserve each failed artifact/report if needed; do not relax the numerical performance policy.
6. Once the hardened baseline passes, capture its own packaged `engine/src/store.rs` using the accepted installed gem, preserve source/generation/native/compiler evidence, and only then prepare the bounded optimization.

From the `thistle/` directory with the selected toolchain on `PATH`:

```bash
cargo test --locked --offline --manifest-path engine/Cargo.toml
bundle exec rake test
mkdir -p pkg/hardened-baseline
gem build thistle.gemspec --output pkg/hardened-baseline/thistle-0.1.0.pre.1.gem
```

Example installed evaluation from the shared workspace (replace runtime/cache paths if the new session has a different environment):

```python
from pathlib import Path
import subprocess

workspace = Path('/workspace/scratch/bc08c0d3c126')
cache = Path('/tmp/thistle-runtime/install/lib/ruby/gems/3.3.0/cache')
command = [
    'python3', str(workspace / 'thistle-eval/evaluate.py'),
    '--ruby', '/tmp/thistle-runtime/install/bin/ruby',
    '--toolchain-bin', '/tmp/thistle-runtime/rustup/toolchains/1.90.0-x86_64-unknown-linux-gnu/bin',
    '--libclang-path', '/tmp/thistle-runtime/clang/clang/native',
    '--clang-args=-isystem /usr/lib/gcc/x86_64-linux-gnu/13/include',
    '--rails',
    '--gem', str(workspace / 'thistle/pkg/hardened-baseline/thistle-0.1.0.pre.1.gem'),
    '--forbid-source-root', str(workspace / 'thistle'),
    '--timeout', '300',
    '--work-dir', str(workspace / 'thistle-eval-runs/hardened-baseline'),
    '--report', str(workspace / 'thistle-eval-runs/hardened-baseline-report.json'),
]
for artifact in sorted(cache.glob('*.gem')):
    command.extend(['--dependency', str(artifact)])
subprocess.run(command, check=True)
```

The worker directory must not exist. The runtime dependency cache in this session contained 42 local gems; the historical report records their identities. In a new environment, prepare the needed Rails dependency artifacts explicitly before the isolated run. No `HOME` override is needed. Source-gem install and build are untrusted execution in the intended protected CI design.

After selecting the final exact core artifact, install the already-built Map package into that isolated gem home and run `thistle/map/test/installed_smoke.rb` from outside the checkout. This must record the actual final core/native/Map tuple; the historical Map pass cannot silently qualify a changed core.

## Frozen optimization experiment

`thistle-eval/policies/experiment-001.json` is frozen at:

`14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe`

The hypothesis is reusing immutable normalized search text rather than reconstructing it for every fact on every query. Only search preparation/reuse may differ between arms. Capture, semantics, ranking, limits, fixtures and evaluator policy remain the same. Charge extra cache allocation in admission accounting.

Required settings are 400 classes / 2,001 declarations, 100 queries, 20 randomized paired trials per mode, four A/A calibration pairs per mode, seed `20261028`. The **primary** measure is `process_until_results_seconds`, using the **median of paired candidate/baseline ratios**:

- Repeated session ratio must be at most **0.90**.
- Single-query session ratio must be at most **1.10**.
- Both initial and warm peak-RSS ratios must be at most **1.20** in each mode.
- A/A primary-timing median paired ratio must lie in **[0.95, 1.05]** for each mode.
- Both exact installed artifacts must pass the current independent quality lane, including both probes. Query results, ranking, coverage and source must agree exactly after the documented generation-identity normalization.

Failure, inconclusive evidence or excessive calibration noise retains the baseline. Warm-query/open timings are secondary diagnostics and cannot replace the primary metric after seeing results. This is one synthetic development experiment, not a Woods comparison, market claim or launch qualification.

Only after both hardened artifacts qualify:

```bash
python3 thistle-eval/compare.py \
  --ruby /path/to/ruby \
  --baseline-home /path/to/hardened-baseline/gems \
  --candidate-home /path/to/candidate/gems \
  --policy thistle-eval/policies/experiment-001.json \
  --baseline-quality-report /path/to/hardened-baseline-report.json \
  --candidate-quality-report /path/to/candidate-report.json \
  --pairs 20 --calibration-pairs 4 --classes 400 --queries 100 \
  --report /path/to/query-experiment-001.json
```

All launch-capability rows in `thistle/docs/capability-ledger.md` remain unqualified. The workflow files are candidate-owned development feedback and have not been run in GitHub or configured as independent required checks. Keep this distinction visible in the handoff and any later PR.
