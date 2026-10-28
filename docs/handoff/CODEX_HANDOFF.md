# Thistle: Codex continuation task

## Start here

Continue implementing **Thistle**, a new competitor to the owner's Woods product. The owner authorized implementation and asked to hand this work to a Codex agent, creating a new repository if necessary. This transfer contains complete source, Git history, architecture, independent evaluation tooling and review evidence. **The private repository https://github.com/lost-in-the-agent/thistle has now been created through an authenticated browser.** It initially contains this bootstrap handoff. The originating session is preparing the Codex task; a task is not running until the Codex interface confirms it. The direct integration could not create repositories or launch Codex.

Read this file, `IMPLEMENTATION.md`, `EVALUATOR_HANDOFF.md`, `ARCHITECTURE_PLAN.md`, `thistle/IMPLEMENTATION_CONTRACT.md` and `thistle/docs/capability-ledger.md` before making changes. The architecture snapshot includes the owner's Rust requirement. Its original Page is https://chatgpt.com/space/page_83d1d4a1a4ec81918d7310c21061c4e4. This exported copy removes any need to access that Page from the coding environment.

## Owner decisions that govern the work

- **Rust is required for the core.** Ruby provides the gem interface and explicit Rails integration; the small C extension is a bridge. There is no Ruby engine fallback.
- Treat Thistle as a new competitor. Challenge the old design and implementation choices. Reimplement the engine without Woods engine code; legacy APIs and tools do not need compatibility.
- The owner permits Woods branding and Map reuse. Reused Map presentation/highlighting code is documented with its original MIT attribution. Preserve that provenance.
- **No console.** Do not build arbitrary evaluation, a REPL or an application-execution feature. A separate console gem is only a possible later product, outside this task.
- Preserve useful and marketable customer outcomes and at least match them for launch. The 17 launch-ledger rows remain unqualified; a small working slice is not launch parity.
- Optimize for measured total task cost and performance, including startup, capture, query, memory, native/Ruby crossings and Map interaction. “Absolute fastest” is a goal to test, not a claim the language choice establishes.
- Use Thistle to inspect its own source and inform bounded changes, with independent tests and frozen benchmark decisions. Do not implement uncontrolled production self-modification.
- Use literal, recognizable action names and word-finding-friendly navigation. Find, Source, Links and Check are the current labels. Home-row shortcuts are optional and off initially; preserve keyboard, text-entry, IME, no-JavaScript and accessible navigation behavior.
- PRs, CI, install hooks, untrusted source, parser/native boundaries and distribution security are part of the design. Keep independent qualification distinct from candidate-controlled CI.

## Exact frozen state

| Component | Identity and status |
|---|---|
| Core + optional Map source | Git commit `23ca426d8b2cc1da052492115748b60641ee4241`; clean worktree at transfer |
| Independent evaluator | Git commit `b81f5adc2c647083b6ce8688234012c6d2da0ee4`; clean worktree at transfer |
| Current checkout verification | Latest native build and Ruby suite: 28 tests, 237 assertions, no failures/errors/skips |
| Current locally built native library | SHA-256 `24d42578b938bd5498c476f43e5a1239bf41f3760035d30630d8a11b8d451f7b`; recorded for evidence, compiled file omitted from transfer |
| Historical source gem | SHA-256 `6a284dbf691f7fa3e3e97c9b1219b5d98242c0a1df1c5930d2bfa3d80d1de8bf`; passed 11 installed check groups before latest hardening |
| Historical loaded native library | SHA-256 `cb3870d86268099cc23dcd8010316f2c130047bff15bc92404bb3fcc786bff11` |
| Frozen optional Map gem | SHA-256 `714b645e498ea2468311ee58dea81218b17bfbe8a7663084927bb8505ec9c697`; needs installed smoke against newly built core |
| Optimization | No optimized candidate built, no candidate performance comparison, no speed improvement claimed |

The old gem is included as historical and negative-control evidence. **Do not promote it as the hardened baseline.** Its installed native fails the newer reader-boundary probe. Local tests show the source fixes work; a new installed artifact must prove them independently.

## Repository preparation

The private Thistle repository is already created at lost-in-the-agent/thistle. Create a separate private evaluator repository when available; its included Git bundle preserves its independent history. The evaluator may instead live in the independently controlled woods-testbed, but its policy and required checks must remain outside candidate authority. Creating the separate repositories is authorized; public publication, gem release and merging are not part of this handoff.

This repository contains Git bundles preserving complete source and local history. The expanded source directories and historical packaged gems are in the separately saved thistle-codex-handoff.zip transfer; they have not been added as redundant binaries here. Restore source from the bundles. HANDOFF_EVIDENCE.zip contains the reports and transfer manifest. From the extracted transfer directory, restore clean working clones without overwriting those expanded copies:

```sh
git clone thistle.git.bundle work/thistle
git clone thistle-eval.git.bundle work/thistle-eval
```

Keep the root handoff documents and `evidence/` available to the coding task. If preparing a cloud environment, copy these handoff documents into repository documentation before pushing. On a new review branch, import the core source at this repository’s root from commit 23ca426d8b2cc1da052492115748b60641ee4241, preserving the original source history where practical and the handoff evidence. Move bootstrap documents under docs/handoff and update their relative links. Do not force-push or merge to main. Do not add historical gem binaries or build products to source history just to make the handoff available. `MANIFEST.json` and `SHA256SUMS` identify transfer contents. Temporary toolchains, installed worker directories and browser screenshots are intentionally absent.

## First implementation task: qualify the hardened baseline

1. Prepare the Linux source-build route: Ruby 3.3.13, Rust 1.90.0, C compiler, Ruby development headers and libclang. Cargo dependencies are vendored and locked. The recorded runtime paths under `/tmp/thistle-runtime` belonged to the originating session and must not be assumed to exist elsewhere.
2. Run `cargo test --locked --offline --manifest-path engine/Cargo.toml` and `bundle exec rake test` from the core clone. Run the evaluator's Python unit suite separately. Investigate concrete failures rather than weakening expected evidence.
3. Build a new source gem under a new `pkg/hardened-baseline/` directory. Preserve the entire vendored dependency tree, including legitimate `src/target` subdirectories. Earlier package filters broke this and the installed evaluator caught it.
4. Run the current independent evaluator from outside the implementation checkout with fresh gem and Cargo homes, explicit local dependency artifacts, the real Rails route lane and both parser and reader-boundary probes. Exact commands and identities are in `EVALUATOR_HANDOFF.md`.
5. Preserve failed attempts and exact package/native/evaluator/compiler identities. A missing probe, crash, timeout or unavailable toolchain is not a pass.
6. Install the frozen optional Map gem with the newly accepted core and run its installed smoke from outside the checkout. Record the exact core/native/Map tuple.

The first reviewable PR should contain any changes needed to complete this hardened installed baseline, its attributable evidence, and CI setup that does not overstate independence. If the baseline passes unchanged, preserve that result and proceed to the bounded experiment without inventing unnecessary fixes.

## Next task: introspective search experiment 001

After baseline qualification, use the exact accepted installed gem to capture and inspect its own packaged `engine/src/store.rs`. Record the source generation/digest and build identity. The hypothesis is to prepare immutable normalized search records once at reader-open time instead of reconstructing lowercase text on every query. Charge any cache in admission accounting. Keep this optimization separate from correctness fixes.

The frozen policy is `thistle-eval/policies/experiment-001.json`, SHA-256 `14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe`. It requires 20 randomized paired trials and four A/A calibration pairs per mode on the declared workload. Median paired ratios for complete process-until-results time must be at most 0.90 for repeated sessions and 1.10 for single sessions; initial and warm peak-RSS ratios must each be at most 1.20. A/A timing ratios must remain within [0.95, 1.05]. Both installed artifacts must pass current quality checks, with equivalent semantics, ranking, source and coverage. Preserve the baseline after failure or inconclusive evidence. Warm-query-only gains cannot replace the primary metric after observing results.

## Remaining roadmap and boundaries

This is a private first slice. Required follow-on work includes full Rails/application evidence, effective runtime/source coherence, incremental capture and lifecycle, retention and recovery, wider encodings/platforms, native fuzz/sanitizer and hostile-parser qualification, process isolation and cancellation, precompiled gems, complete Map/Guide journeys, remote/MCP interfaces, independent protected CI and release provenance, intended-user studies and the full competitor outcome comparison.

Current CI is development feedback owned by the candidate repository. It has not run on GitHub and no external required check or branch protection has been deployed. Build/install and candidate execution belong in disposable unprivileged workers; an independently versioned controller must own fixtures, policies and verdicts. Do not grant PR code release credentials, run fork code under privileged workflows, or accept candidate-produced assertions as independent proof.

The current parser worker is a tested mitigation with a larger stack, not a process sandbox or proof of C parser safety. Encoded-data budgets are not physical memory caps. Integrity checks explicitly do not establish source freshness. Preserve these distinctions in code, product text, reviews and claims.

Report the repository/task URL if actually created, exact commits, the selected package/native tuple, which checks passed, and what remains unqualified. Keep the owner informed. Do not claim that another agent is running unless a real task was successfully started.
