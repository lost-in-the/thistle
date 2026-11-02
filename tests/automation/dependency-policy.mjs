// Explicit policy-change check using the real, separately installed Renovate.
// Usage: supported-node tests/automation/dependency-policy.mjs /path/to/renovate
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const installation = resolve(process.argv[2]);
const load = (name) => import(pathToFileURL(resolve(installation, `dist/${name}.js`)));
const { version } = JSON.parse(readFileSync(resolve(installation, 'package.json')));
assert.equal(version, '44.199.2', 'Review vendor semantics before changing the probe version');
assert.match(process.version, /^v24\./, 'Use Renovate\'s supported Node 24 runtime');
execFileSync(process.execPath, [resolve(installation, 'dist/config-validator.js'),
  '--strict', '--no-global', 'renovate.json'], { stdio: 'inherit' });
const { resolveConfigPresets } = await load('config/presets/index');
const { getFilteredFileList } = await load('workers/repository/extract/file-match');
const { getEnabledManagersList } = await load('modules/manager/index');
const raw = JSON.parse(readFileSync('renovate.json'));
const { config } = await resolveConfigPresets(raw);
const included = ['Gemfile', 'engine/Cargo.toml', 'Dockerfile', 'rust-toolchain.toml'];
const fixture = ['testbed/app/Gemfile', 'testbed/app/Gemfile.lock',
  'testbed/nested/.hidden/Gemfile', 'testbed/future/requirements.txt'];
const inherited = ['engine/vendor/example/Cargo.toml', 'node_modules/example/package.json',
  'test/fixtures/example/Gemfile', 'tests/example/Gemfile'];
const all = [...included, ...fixture, ...inherited];
const checkFiles = (candidate) => assert.deepEqual(getFilteredFileList(candidate, all), included);
checkFiles(config);
// A vulnerability override still cannot recover files removed before extraction.
checkFiles({ ...config, ...config.vulnerabilityAlerts });
assert.throws(() => checkFiles({ ...config, includePaths: [] }));
assert.throws(() => checkFiles({ ...config, includePaths: [...config.includePaths, '**'] }));
assert.throws(() => checkFiles({ ...config, ignorePaths: ['testbed/**'] }));
const checkManagers = (candidate) => assert.deepEqual(
  getEnabledManagersList(candidate.enabledManagers).sort(),
  ['bundler', 'cargo', 'dockerfile', 'rust-toolchain'].sort());
checkManagers(config);
for (const manager of ['github-actions', 'pip_requirements', 'pip_setup', 'pep621', 'poetry']) {
  assert.throws(() => checkManagers({ ...config, enabledManagers: [...config.enabledManagers, manager] }));
}
const checkSecurity = (candidate) => {
  assert.equal(candidate.automerge, false);
  assert.equal(candidate.vulnerabilityAlerts.enabled, true);
  assert.equal(candidate.vulnerabilityAlerts.automerge, false);
};
checkSecurity(config);
assert.throws(() => checkSecurity({ ...config, automerge: true }));
assert.throws(() => checkSecurity({ ...config, vulnerabilityAlerts: { enabled: false, automerge: false } }));
assert.throws(() => checkSecurity({ ...config, vulnerabilityAlerts: { enabled: true, automerge: true } }));
console.log(JSON.stringify({ renovate: version, node: process.version,
  included, excludedFixture: fixture, inheritedExclusions: inherited,
  managers: getEnabledManagersList(config.enabledManagers),
  negativeCases: 11, security: config.vulnerabilityAlerts }));
