# Issue #81 platform development evidence

Candidate-owned development checks on branch `codex/macos-linux-development`,
based on `74ab9d9ca3395980d092da87044733b3e3391014`. The containing PR records
the final signed source commit. These are local implementation receipts, not
independent qualification, performance evidence or acceptance of a launch row.

## Tested environments

- Native Apple Silicon macOS 27.0.1, Darwin 27; Ruby 4.0.9 and 3.4.12 installed
  with mise, Rust/Cargo 1.90.0, Apple clang 21, Homebrew libclang 18.1.8.
- Dedicated Linux arm64 container, Ubuntu 24.04; Ruby 4.0.9, Rust/Cargo 1.90.0,
  GCC 13.3 and libclang 18. Image ID
  `sha256:72234597b8a9ddb7fe192388db8593128c0f229c0c52a9f1079e9bf8fa969832`.
  Final installed checks ran without network or host mounts, as the image's
  unprivileged user, with 4 CPUs, 4 GiB memory and 256 PIDs configured, dropped
  capabilities and no-new-privileges. These settings are development isolation.
- Rails 8.1.4 and Rouge 4.7.0 in all cohorts. Each directory retains the exact
  development and fresh consumer locks, with hashes in its `report.json`.
  Ruby's platform string reports its build target, not the running macOS release.

## Results

On both operating systems: 34 Rust tests passed; source core tests passed with
36 tests / 305 assertions; Map passed with 38 tests / 697 assertions. Both macOS
Ruby versions passed the source core and Map suites. A real Ruby 4.0 → 3.4 → 4.0
switch passed after making the C bridge rebuild on each compile task.

Each of the three retained install receipts passed 36 core tests / 305 assertions,
the existing installed Map smoke, and the installed capture/Find/Source/Links/Check
journey. The consumer uses `bundle install --local` with canonical source-gem
filenames outside the checkout. The report hashes the actually loaded native
extension and verifies it resides under the isolated consumer bundle. The worker
and its test fixtures are removed after execution; source gems remain in the
local ignored `pkg/install-check-*` output. Compiled binaries are not committed.

The primary macOS and Linux builds produced the same core/Map source-gem bytes.
The minimum-Ruby archives have different digests; comparison of every extracted
payload file found identical names and content to the primary archives. Archive
reproducibility is not claimed. Each receipt retains its own actual package hashes.

Linux also passed all 50 automation tests, the release-note filesystem check
(29 files), and both pinned Towncrier draft builds. Actionlint passed the changed
workflow. No deprecation or compiler-warning annotation was found in the final
source and installed logs. The existing Linux installed/evaluator formats remain
unchanged; these receipts do not relabel historical evidence.

## Attempts and review dispositions

The initial macOS extension refused non-Linux hosts. After the platform build
changes, Darwin's unsupported `RLIMIT_AS` setting was reproduced and the shared
test helper now retains CPU/wall deadlines while leaving that memory ceiling to
Linux. Physical temporary fixture paths handle macOS's system symlink aliases
without relaxing the store's no-follow policy. Directory sync, locking, symlink
and special-file rejection passed on both platforms. Only the Ruby initializer
was exported from the macOS extension.

The first container build failed because `/workspace` was root-owned. Explicit
directory ownership fixed it. Early installed checks used gem-install-only
workers; review found that the documented application cache needed canonical gem
filenames. The final checks use a fresh Bundler consumer and observe its loaded
extension. The first minimum-Ruby consumer attempt failed because it inherited
the developer's Bundler as an application dependency. Excluding Bundler tooling
from consumer dependencies fixed that mismatch; the retained minimum receipt
records the actual default Bundler 2.6.9. Primary consumers used Bundler 4.0.20.
These failures were not relabeled as successful attempts.

Injecting `THISTLE_CARGO=/usr/bin/false` produced a nonzero Rust-build failure,
stopped dependent tests and left no passing report. The normal installed checks
subsequently passed. The scoped static review found no native safety blocker;
its application-cache finding was fixed. The final receipt refactor was checked
locally; independent PR review and owner acceptance remain outstanding.

No engine algorithm, capture schema, reader ownership or publication guarantee
was broadened. Reusing vendored errno adds no new vendor bytes or reset allocation.
The C bridge clean/recompile adds small build work to prevent stale Ruby ABI
objects. Fresh install checks intentionally pay for compilation in an isolated
bundle; the container retains toolchain layers but rebuilds after source edits.

## Remaining scope

Hosted Apple Silicon/Intel macOS and Linux x86_64 checks remain to run on the PR.
Linux minimum Ruby is covered by the selected existing CI lane, not this local
container receipt. Other Unix systems, Windows, precompiled distribution, broader
Rails support, hostile-parser isolation and power-loss durability are unqualified.
The macOS probes enforce CPU/wall deadlines but no address-space ceiling. All
launch capability rows retain their existing unqualified status.

Project-stage reconciliation could not be performed: the available CLI token
lacks `read:project`, and the connected repository tools expose no project-field
operation. The issue/PR carry the current claim and next action; no credential
scope was broadened.
