/* Run against browser_server.rb. Browser, Playwright and axe are test-only. */
"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require(require.resolve("playwright", {
  paths: [process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES || process.cwd()]
}));

const [base, executablePath, axePath, output] = process.argv.slice(2);
if (!/^http:\/\/(127\.0\.0\.1|localhost):[0-9]+$/.test(base || "") || !executablePath || !axePath || !output) {
  throw new Error("Usage: node browser_test.js http://127.0.0.1:PORT CHROME_PATH AXE_PATH OUTPUT_DIR");
}
fs.mkdirSync(output, { recursive: true });
let browser;

(async () => {
  browser = await chromium.launch({ executablePath, headless: true, args: ["--no-sandbox"] });
  const context = await browser.newContext();
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  const axeSource = fs.readFileSync(axePath, "utf8");
  const reports = [];
  let axeVersion;
  for (const width of [1440, 960, 640, 390]) {
    await page.setViewportSize({ width, height: 1000 });
    for (const view of ["Find", "Source", "Links", "Check"]) {
      await page.goto(`${base}/?q=Demo`);
      if (view !== "Find") {
        await page.locator("[data-result-link]").first().click();
        if (view !== "Source") await page.getByRole("link", { name: view, exact: true }).click();
      }
      await page.waitForLoadState("load");
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      await page.evaluate(axeSource);
      axeVersion = await page.evaluate(() => axe.version);
      const result = await page.evaluate(() => axe.run(document, {
        runOnly: { type: "tag", values: ["wcag2a", "wcag2aa", "wcag21aa", "best-practice"] }
      }));
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
      assert.equal(overflow, false, `${view} at ${width}px overflows the page`);
      reports.push({ width, view, violations: result.violations, incomplete: result.incomplete.map(x => x.id) });
      await page.screenshot({ path: path.join(output, `${view.toLowerCase()}-${width}.png`), fullPage: true });
    }
  }

  await page.goto(`${base}/?q=Demo`);
  await page.locator("#workbench").focus();
  await page.keyboard.press("f");
  assert.equal(await page.evaluate(() => document.activeElement.id), "workbench", "shortcuts start off");
  await page.getByLabel("Use letter shortcuts", { exact: true }).check();
  await page.locator("#workbench").focus();
  await page.keyboard.press("f");
  assert.equal(await page.evaluate(() => document.activeElement.id), "find-query");
  const beforeTyping = page.url();
  await page.locator("#find-query").fill("fsgjk");
  await page.keyboard.press("s");
  assert.equal(page.url(), beforeTyping, "typing does not navigate");
  assert.equal(await page.evaluate(() => document.activeElement.id), "find-query");
  await page.locator("#workbench").focus();
  await page.evaluate(() => document.getElementById("workbench").dispatchEvent(
    new KeyboardEvent("keydown", { key: "f", bubbles: true, isComposing: true })
  ));
  assert.equal(await page.evaluate(() => document.activeElement.id), "workbench", "composition is ignored");
  await page.locator("[data-result-link]").first().click();
  await page.waitForLoadState("load");
  await page.waitForFunction(() => !document.getElementById("letter-shortcuts").closest("label").hidden);
  const generation = new URL(page.url()).searchParams.get("generation");
  assert.match(generation, /^[a-f0-9]{64}$/);
  assert.equal(await page.locator("main img").count(), 0, "source markup is inert");
  await page.locator("#workbench").focus();
  await page.keyboard.press("g");
  await page.waitForURL(/\/links\?/);
  assert.equal(new URL(page.url()).searchParams.get("generation"), generation);
  await page.getByLabel("Use letter shortcuts", { exact: true }).uncheck();
  await page.locator("#workbench").focus();
  const noKeysUrl = page.url();
  await page.keyboard.press("s");
  assert.equal(page.url(), noKeysUrl, "shortcuts can be disabled");

  const noJsContext = await browser.newContext({ javaScriptEnabled: false });
  const noJs = await noJsContext.newPage();
  await noJs.goto(`${base}/?q=Demo`);
  await noJs.locator("[data-result-link]").first().click();
  await noJs.getByRole("link", { name: "Links", exact: true }).click();
  assert.match(noJs.url(), /\/links\?/);
  assert.equal(await noJs.getByLabel("Use letter shortcuts", { exact: true }).isVisible(), false);
  assert.deepEqual(errors, []);
  const violations = reports.flatMap(report => report.violations.map(x => ({ width: report.width, view: report.view, id: x.id, nodes: x.nodes.length })));
  const report = {
    browser: await browser.version(), axe: axeVersion,
    pages: reports, violations, keyboard: "passed", no_javascript_navigation: "passed", page_errors: errors
  };
  fs.writeFileSync(path.join(output, "browser-report.json"), JSON.stringify(report, null, 2));
  await browser.close();
  console.log(JSON.stringify({ browser: report.browser, pages: reports.length, violations, keyboard: report.keyboard, no_javascript_navigation: report.no_javascript_navigation }));
  assert.deepEqual(violations, [], "axe violations require resolution");
})().catch(async error => {
  console.error(error);
  if (browser) await browser.close();
  process.exitCode = 1;
});
