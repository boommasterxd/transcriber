'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const test = require('node:test');

const filter = path.join(__dirname, '../../../tool/ci/read_gitleaks_release.jq');
const sha256 = 'a'.repeat(64);
const archive = { name: 'gitleaks_8.30.2_linux_x64.tar.gz', digest: `sha256:${sha256}` };

function parseRelease(release) {
  return spawnSync('jq', ['-ce', '-f', filter], {
    encoding: 'utf8', input: JSON.stringify(release), timeout: 3000,
  });
}

test('Gitleaks updater selects the unique verified Linux x64 archive', () => {
  const result = parseRelease({
    tag_name: 'v8.30.2',
    assets: [{ ...archive, name: 'gitleaks_8.30.2_darwin_x64.tar.gz' }, archive],
  });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { version: '8.30.2', sha256 });
});

test('Gitleaks updater rejects an invalid release or missing, ambiguous or invalid checksum', () => {
  for (const release of [
    { assets: [archive] },
    { tag_name: 'v8.30.2\n', assets: [archive] },
    { tag_name: 'v8.30.2' },
    { tag_name: 'v8.30.2', assets: { archive } },
    { tag_name: 'v8.30.2', assets: [{ ...archive, name: `${archive.name}.sig` }] },
    { tag_name: 'v8.30.2', assets: [archive, archive] },
    { tag_name: 'v8.30.2', assets: [{ name: archive.name }] },
    { tag_name: 'v8.30.2', assets: [{ ...archive, digest: 'sha256:ab' }] },
  ]) {
    const result = parseRelease(release);
    assert.ok(Number.isInteger(result.status) && result.status > 0, JSON.stringify(release));
    assert.equal(result.stdout, '');
  }
});
