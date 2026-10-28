# Map validation record

## Current evidence

Local platform: Linux x86-64, Ruby 3.3.13, Rouge 4.7.0, Minitest 5.26.2. The browser test server uses development-only WEBrick 1.9.2. These results establish only the first private implementation slice.

- **21 tests, 165 assertions: passed** against the compiled Rust engine and Ruby facade. The suite includes real capture/publication/source, old-generation retention after mutation, Woods absence, Rack 3.2.7 response lint, source escaping and request/authorization cases. Earlier presentation-only runs used controlled readers; the final suite exercises the real core integration as well.
- **16 browser view/width combinations: passed** for Find, Source, Links and Check at 1440, 960, 640 and 390 CSS pixels, in Chrome for Testing 134.0.6998.35 with axe-core 4.10.3. The complete run was repeated against a real Rust-produced capture and Reader, and passed. There were zero reported axe violations after the capture-status landmark fix. The scan includes WCAG 2.0 A/AA, 2.1 AA and best-practice rules; automated scans cannot establish complete accessibility conformance. Some source-text contrast checks were marked incomplete by axe and remain explicitly recorded in the report.
- Browser interaction checks passed for initially disabled letter keys, explicit enable/disable, input and composition exclusion, pinned-generation navigation, inert source text, and navigation with JavaScript disabled. No page JavaScript exceptions were observed.
- Source and Links screenshots were visually inspected at 390px and 640px, and the final real-core Source view was inspected at 1440px and 390px. A stylesheet-specificity fix restored sans-serif human guidance while keeping code and identifiers monospace. Source has one horizontal scroll region with stable line numbers; the page itself did not overflow at any tested width.
- A manual calculation of the fixed dark-theme syntax colours found comments needed a brighter token on selected rows: the original dim token was about 4.43:1 against the selection tint. Selected rows now use the muted-text token for comments, about 5.68:1. This is a narrow check of declared colour pairs, not a substitute for assistive-technology testing.
- **Installed core + Map pair: passed** in an isolated `GEM_HOME`, executed from `/tmp` with no checkout added to the Ruby load path. The smoke test captured a new fixture with the installed Rust engine, rendered its source through the installed Map gem, checked escaping/CSP/read-only methods and generation-carrying URLs, and verified all loaded Thistle files came from the installed gems with Woods absent. Exact package/native digests are retained in the overall implementation evidence.
- Reused `woods-map-tokens.css` Git blob hash is exactly `28876d6fb3455381bb8c961e9e25654f77bb8451`, matching the pinned upstream file.

The condensed results are `browser-fixture-results.json` and `browser-native-results.json`. The latter records the actual native capture generation. Early validation caught and fixed a missing landmark; another early scan raced stylesheet loading after navigation, so the browser test now waits for load and paint before scanning. Failed attempts were not counted as passes. The first native integration run also caught an end-byte/end-line mismatch for whole-file facts in the core capture; that bug was corrected without weakening the strict validator, and the full suite then passed.

## Remaining qualification

Any change to either package requires a new installed-pair run of `test/installed_smoke.rb`; workspace-only results do not qualify changed artifacts. The installed smoke is a focused source-to-UI check, not the full outcome or platform matrix.

Intended-user naming, interruption recovery, speech input, screen-reader operation, high-contrast modes, broader browser/platform coverage, authentication integration, complete Map outcome coverage and performance qualification remain open. No launch-parity or general accessibility claim follows from these checks.

## Reproduction

After compiling the core extension and installing development dependencies:

```sh
ruby -Ilib -Imap/lib -e 'Dir["map/test/*_test.rb"].sort.each { |f| require_relative f }'
ruby -Ilib -Imap/lib map/test/browser_server.rb
node map/test/browser_test.js http://127.0.0.1:41237 /path/to/chrome-headless-shell /path/to/axe.min.js /tmp/thistle-map-browser-results
```

Set `THISTLE_MAP_TEST_STORE` to use a real saved store in the browser server; otherwise it uses the controlled fixture explicitly. The test server binds only to loopback and is not a shipped deployment server. Run browser checks in an isolated test environment; the headless invocation uses `--no-sandbox` because this container cannot launch the Chromium sandbox.
