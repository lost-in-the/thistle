// Authored UNRUN. Root supplies an ACTUAL installed/served, generation-pinned
// registry overview URL and an existing private output directory under a finite
// browser/process lease. No server, app boot, dependency install or route guess.
import { chromium } from 'playwright';
import { open, lstat } from 'node:fs/promises';
import { constants } from 'node:fs';
import path from 'node:path';

const target = new URL(process.env.LOS148_MAP_URL);
const output = process.env.LOS148_SCREENSHOT_DIR;
if (!target.searchParams.get('generation')) throw new Error('Pinned generation URL required');
const stat = await lstat(output);
if (!stat.isDirectory() || stat.isSymbolicLink() || (stat.mode & 0o777) !== 0o700) throw new Error('Private existing output directory required');

async function saveImage(page, name) {
  const bytes = await page.screenshot({ fullPage: true, type: 'png' });
  if (bytes.length > 2 * 1024 * 1024) throw new Error('Screenshot exceeds 2 MiB');
  const handle = await open(path.join(output, name), constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW | constants.O_WRONLY, 0o600);
  try {
    const actual = await handle.stat();
    if (!actual.isFile() || actual.nlink !== 1 || (actual.mode & 0o777) !== 0o600) throw new Error('Unsafe screenshot file');
    await handle.writeFile(bytes);
  } finally { await handle.close(); }
}
const demand = (value, text) => { if (!value) throw new Error(text); };
async function follow(page, label) {
  const link = page.getByRole('link', { name: label, exact: true });
  demand(await link.count() === 1, `Expected one visible ${label} link`);
  await link.focus();
  await page.keyboard.press('Enter');
  await page.waitForLoadState('domcontentloaded');
  demand(new URL(page.url()).searchParams.get('generation') === target.searchParams.get('generation'), 'Navigation lost saved generation');
}
async function candidate(page, text) {
  const card = page.locator('article').filter({ hasText: text }).first();
  await card.getByRole('link', { name: /^Inspect saved / }).focus();
  await page.keyboard.press('Enter');
  await page.waitForLoadState('domcontentloaded');
}
const browser = await chromium.launch();
try {
  // Actual no-JavaScript keyboard journey, separately labelled from a person test.
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 1280, height: 900 } });
  const page = await context.newPage();
  page.setDefaultTimeout(5000);
  await page.goto(target.href, { waitUntil: 'domcontentloaded' });
  await follow(page, 'Inspect registrations');
  let text = await page.locator('body').innerText();
  for (const expected of ['DeliveryTimeout', 'MissingRecipient', 'UnloadedDeliveryError']) demand(text.includes(expected), `Missing ${expected}`);
  await page.goBack({ waitUntil: 'domcontentloaded' });
  await follow(page, 'Inspect declarations');
  const declarations = page.url();
  await candidate(page, 'superclass');
  await follow(page, 'Inspect policy');
  text = await page.locator('body').innerText();
  for (const expected of ['retry_on', 'polynomially_longer', 'attempts', '4']) demand(text.includes(expected), `Inherited policy missing ${expected}`);
  await page.goto(declarations, { waitUntil: 'domcontentloaded' });
  await candidate(page, 'perform');
  await follow(page, 'Inspect handoff');
  text = await page.locator('body').innerText();
  demand(text.includes('ambiguous') && text.includes('unknown'), 'Ambiguity/unknowns missing');
  const handoff = page.url();
  await candidate(page, 'ReceiptMailer#receipt');
  await follow(page, 'Inspect handoff');
  await candidate(page, 'receipt.html.erb');
  await follow(page, 'Inspect template references');
  text = await page.locator('body').innerText();
  for (const expected of ['@recipient', 'receipt_heading', 'receipt_mailer/footer']) demand(text.includes(expected), `ERB evidence missing ${expected}`);
  demand(!text.includes('@comment_only') && !text.includes('@escaped_only'), 'Escaped/comment text became a Ruby reference');
  await saveImage(page, 'job-mail-erb-desktop-nojs.png');
  await page.setViewportSize({ width: 390, height: 844 });
  await saveImage(page, 'job-mail-erb-narrow-nojs.png');
  await page.goto(handoff, { waitUntil: 'domcontentloaded' });
  let pages = 0;
  while (await page.getByRole('link', { name: 'Continue this evidence family', exact: true }).count()) {
    if (++pages > 8) throw new Error('Continuation exceeded fixture bound');
    await follow(page, 'Continue this evidence family');
  }
  demand(pages > 0, 'Fixture did not exercise continuation beyond first page');
  console.log(JSON.stringify({ result: 'agent-browser no-JS keyboard journey passed', generation: target.searchParams.get('generation'), screenshots: 2,
    limits: 'No person/IME/screen-reader acceptance or runtime delivery proof; package/native identities are supplied by Root separately' }));
  await context.close();
} finally { await browser.close(); }
