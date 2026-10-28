# Independent Map/product review

Date: 2026-10-28. Reviewed source: `23ca426d8b2cc1da052492115748b60641ee4241` in `/workspace/thistle`. Reviewer scope: Map presentation, reader seam, interaction controls, access policy, reuse provenance, and the installed-smoke evidence contract. No implementation or evaluator files were changed.

Disposition: no reproduced Map code blocker found in this bounded review. Exact-artifact Map qualification remains blocked until the newly accepted core and the chosen Map artifact actually run together with externally checked byte identities. This review does not qualify the package or close a launch row.

## Finding M1 — qualification evidence must bind the accepted core and Map bytes (P1 evidence gap)

`map/test/installed_smoke.rb:20–23` verifies loaded Ruby files reside below the isolated GEM_HOME, and lines 48–58 locate and report the loaded native library digest. The script does not compare those bytes to the accepted core quality report, nor report the Map package digest or hashes of its installed Ruby/assets. A different or modified same-version package can satisfy those path/version checks. The script is useful source-to-UI evidence, but by itself it cannot prove that the exact independently accepted core is the one used.

Required closure: retain the exact core and Map package digests, compare loaded core Ruby/native files against the accepted evaluator report, and compare installed Map Ruby/assets against the supplied Map package inventory. Perform identity checks after the smoke as well as before it. Preserve the actual script, report, source/evaluator/toolchain tuple and outside-checkout working directory. This can be an external qualification wrapper; weakening the independent evaluator is unnecessary. Do not promote the historical Map pass against `cb3870…` as a pass for a new hardened core.

## Finding M2 — browser regression coverage is narrower than the interaction requirement (P2 remaining evidence)

`map/assets/map.js:14–19` explicitly guards disabled preference, default prevention, repeat, composition, Ctrl/Alt/Meta/Shift, text widgets, focused-workbench containment, and noncollapsed text selection. The checked-in browser script exercises initial disablement, enable/disable, ordinary input typing and one synthetic `isComposing` event, but does not exercise the modifier/selection/repeat/defaultPrevented guards, textarea/select/contenteditable/ARIA text controls, focus outside the workbench, or a real IME/dictation journey. Existing code inspection supports these guards; the old browser report does not establish the full requirement.

Before broader accessibility or input claims, extend real-browser behavioral coverage and conduct the declared assistive/input user journeys. This is not a demonstrated navigation defect and is not permission to waive the user requirement.

## Reviewed controls and observed evidence

- Literal Find, Source, Links and Check labels are present in `map/lib/thistle/map/view.rb:128–157`; the form and navigation remain server rendered. Shortcuts default off, can be disabled, use only focus within the workbench, and are optional. There is no arbitrary application-execution endpoint.
- `map/lib/thistle/map/app.rb:94–121` checks exact allowed Host, port, same origin and cross-site fetch context before authorization. Default access also requires loopback peer plus a literal local Host; forwarded headers are not used. Remote authorization is explicitly delegated to the trusted host. No bypass was reproduced by this static review.
- Source/fact/query text uses HTML escaping, and the highlighter refuses lossy tokenization or lexer failure by returning escaped plain text. Source size refusal is explicit. Saved-generation links are carried throughout navigation, and generation substitution is refused.
- Reader cleanup is in App's ensure path (`app.rb:81–82`). The installed smoke must still exercise the actual new core; static inspection cannot establish native ownership.
- Reuse provenance lists upstream commit and blob identities. Independently ran `git hash-object map/assets/woods-map-tokens.css`: `28876d6fb3455381bb8c961e9e25654f77bb8451`, matching the recorded upstream blob. `LICENSE.woods-map.txt` preserves the MIT copyright and permission; the Map gemspec includes `LICENSE*`. This verifies the stylesheet identity and notice presence, not a complete legal audit.
- Independently ran Ruby syntax checks on all 12 Map `*.rb` files using Ruby `3.4.9 (2026-03-11 revision 76cca827ab) +PRISM [x86_64-linux]`: 12 succeeded. Raw record: `map-syntax.json`. This is syntax evidence only, on a different Ruby tuple from the requested baseline.
- No Ruby Map suite, native integration, installed-pair smoke, current browser session, screen-reader, speech/dictation, real IME, high-contrast, or intended-user study was run by this reviewer. Missing Rust/libclang and the currently incomplete baseline prevent using historical results as present qualification.

## Remaining launch gaps

L14–L17 remain unqualified, as do all other ledger rows. This slice supplies saved-source reading, bounded Find and labelled unresolved Links, rather than complete original/effective behavior, runtime/schema/history views, route/action-to-source investigations, saved/resumed/shared trails, or provider-backed help. Search is capped at 50 with explicit narrowing guidance; comprehensive discovery/pagination and approximate word finding are still open. Long-source handling refuses with a CLI instruction, whose usability still needs testing. Broader host authentication integration and hostile-input/resource qualification remain external requirements.

There is no basis here for full Map parity, complete accessibility, a market performance advantage, or protected independent controller authority. No agreement with other reviewers is assumed.


## Follow-up: candidate-owned qualification wrapper review

Reviewed `tools/qualify_baseline.py` as code, before treating any hosted run as executed evidence. The wrapper closes the main M1 installed-file gap in design: lines 73–86 check the frozen evaluator's runtime-file hashes before and after Map and require the smoke's native digest to be one of the accepted native digests; lines 88–93 compare each packaged regular core/Map file against installed bytes and retain the inventories. It labels its own authority as candidate-owned orchestration. These checks still require a successful actual run.

Two concrete review findings remain:

- **M3 (P2 artifact identity):** initial package digests are recorded at lines 47–55, while tuple verification computes fresh digests at line 116 without requiring equality to the initial digests or the evaluator's artifact record. A package replacement after evaluation can therefore produce inconsistent build/quality/tuple records. Require initial/final core and Map package digest equality and require the evaluator's supplied core digest equal the recorded core digest. Installed code-byte comparison is already present and should remain.
- **M4 (P2 failed-attempt evidence):** `run()` sets `check=True`, while the Map and self-inspection calls capture stdout/stderr at lines 81 and 110. On a failed subprocess they raise before lines 82–83 / 112–113 write those captured outputs. The command failure remains visible, but the decisive child diagnostics are discarded. Run these probes with `check=False`, persist both streams and return code, then raise for a failed status. A failed or missing probe must continue blocking tuple verification.

No implementation/evaluator edits were made by this reviewer. No newly hosted result was accepted or independently rerun as part of this follow-up.
