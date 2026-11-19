'use strict';

const assert = require('node:assert/strict');
const { spawnSync, execFileSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const scripts = path.resolve(__dirname, '../../../tool/package');

function runScript(name, args = [], options = {}) {
  return spawnSync('bash', [path.join(scripts, name), ...args], {
    encoding: 'utf8', timeout: 10000, ...options,
  });
}

function releaseRepository(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-release-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, {
    cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 10000,
  }).trim();
  git('init', '--initial-branch=main');
  git('config', 'user.name', 'Release Test');
  git('config', 'user.email', 'release@example.invalid');
  git('commit', '--allow-empty', '-m', 'Built commit');
  const built = git('rev-parse', 'HEAD');
  git('commit', '--allow-empty', '-m', 'Default branch advanced');
  const current = git('rev-parse', 'HEAD');
  // A local remote exercises Git's real ref/peeled-tag protocol without writes
  // to GitHub or use of credentials.
  git('remote', 'add', 'origin', root);
  return { root, git, built, current };
}

test('manual release retains the built commit after the default branch advances', (t) => {
  const { root, git, built, current } = releaseRepository(t);
  assert.notEqual(built, current);
  const result = runScript('verify_release_tag.sh', ['1.2.3', built], { cwd: root });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'v1.2.3\n');
  assert.equal(git('tag', '--list'), '');
});

test('existing lightweight and annotated tags must resolve to the built commit', (t) => {
  const { root, git, built, current } = releaseRepository(t);
  git('tag', 'v1.2.3', built);
  git('tag', '-a', 'v1.2.4', built, '-m', 'Matching annotation');
  git('tag', 'v1.2.5', current);
  git('tag', '-a', 'v1.2.6', current, '-m', 'Mismatched annotation');
  for (const version of ['1.2.3', '1.2.4']) {
    const result = runScript('verify_release_tag.sh', [version, built], { cwd: root });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, `v${version}\n`);
  }
  for (const version of ['1.2.5', '1.2.6']) {
    const result = runScript('verify_release_tag.sh', [version, built], { cwd: root });
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
    assert.match(result.stderr, /does not match/);
  }
});

test('unavailable authoritative remote refuses publication', (t) => {
  const { root, git, built } = releaseRepository(t);
  git('remote', 'set-url', 'origin', path.join(root, 'missing-remote'));
  const result = runScript('verify_release_tag.sh', ['1.2.3', built], { cwd: root });
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
});

test('version resolution accepts explicit, tag and pubspec release versions', () => {
  for (const [releaseVersion, ref, expected] of [
    ['1.2.3-rc.1', 'refs/heads/main', '1.2.3-rc.1'],
    ['', 'refs/tags/v2.3.4', '2.3.4'],
    ['v3.0.0', 'refs/tags/v2.3.4', '3.0.0'],
  ]) {
    const result = runScript('version.sh', [], {
      env: { ...process.env, RELEASE_VERSION: releaseVersion, GITHUB_REF: ref },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, `${expected}\n`);
  }
  const pubspec = fs.readFileSync(path.join(scripts, '../../pubspec.yaml'), 'utf8');
  const expected = /^version:\s*(.+?)(?:\+.*)?$/m.exec(pubspec)[1];
  const result = runScript('version.sh', [], {
    env: { ...process.env, RELEASE_VERSION: '', GITHUB_REF: 'refs/heads/main' },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `${expected}\n`);
});

test('untrusted version and build inputs fail without output or pubspec changes', () => {
  const pubspecPath = path.join(scripts, '../../pubspec.yaml');
  const before = fs.readFileSync(pubspecPath, 'utf8');
  for (const invalid of ['1.2.3\nname=other', '$(touch /tmp/injected)',
    '1.2.3;false', '1.2.3/other', '01.2.3', '1.2.3-01', '1.2.3+4', '1. 2.3']) {
    const result = runScript('version.sh', [], {
      env: { ...process.env, RELEASE_VERSION: invalid },
    });
    assert.notEqual(result.status, 0, invalid);
    assert.equal(result.stdout, '');
    assert.notEqual(runScript('stamp_version.sh', [invalid, '42']).status, 0);
  }
  assert.notEqual(runScript('stamp_version.sh', ['1.2.3', '42\nother: value']).status, 0);
  assert.notEqual(runScript('verify_release_tag.sh', ['1.2.3', 'main']).status, 0);
  assert.equal(fs.readFileSync(pubspecPath, 'utf8'), before);
});

test('stamping preserves the validated version and build number for packaging', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-stamp-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const targetScripts = path.join(root, 'tool/package');
  fs.mkdirSync(targetScripts, { recursive: true });
  for (const name of ['stamp_version.sh', 'validate_version.sh', 'version.sh']) {
    fs.copyFileSync(path.join(scripts, name), path.join(targetScripts, name));
  }
  const pubspec = path.join(root, 'pubspec.yaml');
  fs.writeFileSync(pubspec, 'name: fixture\nversion: 0.1.0+1\n');
  const result = spawnSync('bash', [path.join(targetScripts, 'stamp_version.sh'),
    '1.2.3-rc.1', '42'], { encoding: 'utf8', timeout: 10000 });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(pubspec, 'utf8'), 'name: fixture\nversion: 1.2.3-rc.1+42\n');
  assert.equal(fs.existsSync(`${pubspec}.bak`), false);
});

test('release source requires a manual dispatch from protected main with reachable code', (t) => {
  const { root, git, built, current } = releaseRepository(t);
  const verify = (...args) => runScript('verify_release_source.sh', args, { cwd: root });
  git('update-ref', 'refs/remotes/origin/main', built);
  assert.match(verify('workflow_dispatch', 'refs/heads/main', 'true').stderr, /reachable from main/);

  git('update-ref', 'refs/remotes/origin/main', current);
  const approved = verify('workflow_dispatch', 'refs/heads/main', 'true');
  assert.equal(approved.status, 0, approved.stderr);
  for (const args of [
    ['workflow_dispatch', 'refs/heads/main', 'false'],
    ['workflow_dispatch', 'refs/heads/feature', 'true'],
    ['workflow_dispatch', 'refs/tags/v2.0.0', 'true'],
    ['push', 'refs/tags/v2.0.0', 'true'],
  ]) {
    const rejected = verify(...args);
    assert.notEqual(rejected.status, 0);
    assert.match(rejected.stderr, /manual dispatch from protected main/);
  }
});

test('release version code supersedes old APKs and stays within Android bounds', () => {
  const first = runScript('android_release_version_code.sh', ['1']);
  assert.equal(first.status, 0, first.stderr);
  assert.equal(first.stdout, '1001\n');
  const last = runScript('android_release_version_code.sh', ['2099999000']);
  assert.equal(last.status, 0, last.stderr);
  assert.equal(last.stdout, '2100000000\n');
  for (const input of ['0', '08', '2099999001', '9223372036854775808']) {
    assert.notEqual(runScript('android_release_version_code.sh', [input]).status, 0);
  }
});

test('publisher accepts exactly the expected APK and its verified checksum', (t) => {
  const artifact = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-artifact-'));
  t.after(() => fs.rmSync(artifact, { recursive: true, force: true }));
  const apk = 'transcriber-2.0.0-android.apk';
  const contents = 'APK fixture bytes';
  const checksum = createHash('sha256').update(contents).digest('hex');
  const verify = () => runScript('verify_release_assets.sh', ['2.0.0', artifact]);
  fs.writeFileSync(path.join(artifact, 'SHA256SUMS'), `${checksum}  ${apk}\n`);
  assert.notEqual(verify().status, 0, 'reject checksum-only artifact');

  fs.writeFileSync(path.join(artifact, apk), 'different bytes');
  assert.notEqual(verify().status, 0, 'reject checksum mismatch');
  fs.writeFileSync(path.join(artifact, apk), contents);
  const correct = verify();
  assert.equal(correct.status, 0, correct.stderr);

  fs.writeFileSync(path.join(artifact, 'unexpected.apk'), contents);
  assert.notEqual(verify().status, 0, 'reject extra APKs');
});
