'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { checkNpmScope } = require('../../../tool/ci/check-osv-npm-scope.cjs');

function lock(packages) {
  return { lockfileVersion: 3, packages: { '': { name: 'fixture' }, ...packages } };
}

test('accepts real dev-only tooling and production dependencies shared with dev', () => {
  checkNpmScope(JSON.parse(fs.readFileSync('tool/quality/node/package-lock.json', 'utf8')));
  for (const lockfileVersion of [2, 3]) {
    checkNpmScope({ ...lock({
      'node_modules/shared': { version: '1.0.0' },
      'node_modules/tool/node_modules/shared': { version: '1.0.0', dev: true },
      'node_modules/dev-only': { version: '2.0.0', dev: true },
      'node_modules/dev-optional': { version: '2.0.0', dev: true, optional: true },
      'node_modules/prod-optional': { version: '3.0.0', optional: true },
    }), lockfileVersion });
  }
});

test('rejects OSV groups that could hide optional or bundled production packages', () => {
  assert.throws(() => checkNpmScope(lock({
    'node_modules/shared': { version: '1.0.0', devOptional: true },
  })), /cannot safely classify devOptional/);
  assert.throws(() => checkNpmScope(lock({
    'node_modules/@scope/shared': { version: '1.0.0', optional: true },
    'node_modules/tool/node_modules/alias': { name: '@scope/shared', version: '1.0.0', dev: true },
  })), /cannot safely merge dev and grouped production packages: @scope\/shared@1.0.0/);
  assert.throws(() => checkNpmScope(lock({
    'node_modules/shared': { version: '1.0.0', inBundle: true },
    'node_modules/tool/node_modules/shared': { version: '1.0.0', dev: true },
  })), /cannot safely merge dev and grouped production packages: shared@1.0.0/);
  checkNpmScope(lock({
    'node_modules/shared': { version: '1.0.0', optional: true },
    'node_modules/tool/node_modules/shared': { version: '2.0.0', dev: true },
  }));
  checkNpmScope(lock({
    'node_modules/shared': { version: '1.0.0', optional: true },
    'node_modules/tool/node_modules/shared': { version: '1.0.0', dev: true },
    'node_modules/consumer/node_modules/shared': { version: '1.0.0' },
  }));
  checkNpmScope(lock({
    'node_modules/shared': { version: '1.0.0', inBundle: true },
    'node_modules/tool/node_modules/shared': { version: '1.0.0', dev: true },
    'node_modules/consumer/node_modules/shared': { version: '1.0.0' },
  }));
});

test('rejects malformed input and unreviewed linked or Git identities', () => {
  for (const input of [null, {}, { lockfileVersion: 1 },
    { lockfileVersion: 3, packages: [] }, { lockfileVersion: 3, packages: {} },
    { lockfileVersion: 3, packages: { '': 'invalid' } },
    { lockfileVersion: 3, packages: { '': [] } }]) {
    assert.throws(() => checkNpmScope(input), /valid npm v2\/v3/);
  }
  for (const entry of [null, [], {}, { version: 1 }, { version: '' },
    { version: '1.0.0', name: '' }, { version: '1.0.0', dev: 'true' }]) {
    assert.throws(() => checkNpmScope(lock({ 'node_modules/pkg': entry })), /Invalid npm lockfile/);
  }
  assert.throws(() => checkNpmScope(lock({ invalid: { version: '1.0.0' } })), /Invalid npm/);
  for (const entry of [{ version: '1.0.0', link: true },
    { version: '1.0.0', resolved: 'git+https://example.test/lib#abc' }]) {
    assert.throws(() => checkNpmScope(lock({ 'node_modules/pkg': entry })), /requires review/);
  }
});

test('CLI exits unsuccessfully for missing, malformed and ambiguous scan input', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'osv-npm-scope-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const scriptPath = path.join(directory, 'ci/check-osv-npm-scope.cjs');
  const lockPath = path.join(directory, 'quality/node/package-lock.json');
  fs.mkdirSync(path.dirname(scriptPath), { recursive: true });
  fs.mkdirSync(path.dirname(lockPath), { recursive: true });
  fs.copyFileSync('tool/ci/check-osv-npm-scope.cjs', scriptPath);
  const run = () => spawnSync(process.execPath, [scriptPath], { encoding: 'utf8', timeout: 5000 });
  assert.equal(run().status, 1);
  fs.writeFileSync(lockPath, '{');
  assert.equal(run().status, 1);
  fs.writeFileSync(lockPath, JSON.stringify(lock({
    'node_modules/pkg': { version: '1.0.0', devOptional: true },
  })));
  const ambiguous = run();
  assert.equal(ambiguous.status, 1);
  assert.match(ambiguous.stderr, /devOptional/);
  fs.writeFileSync(lockPath, JSON.stringify(lock({
    'node_modules/pkg': { version: '1.0.0', dev: true },
  })));
  const valid = run();
  assert.equal(valid.status, 0, valid.stderr);
  assert.match(valid.stdout, /preserves production dependencies/);
});
