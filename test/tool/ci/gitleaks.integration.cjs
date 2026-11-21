'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const scanner = process.env.GITLEAKS_EXECUTABLE;
const config = path.resolve(__dirname, '../../../.gitleaks.toml');
const repositoryIgnore = path.resolve(__dirname, '../../../.gitleaksignore');

function scan(arguments_, cwd, ignorePath = repositoryIgnore) {
  const result = childProcess.spawnSync(scanner, [...arguments_, '--no-banner', '--redact',
    '--exit-code', '1', '--config', config, '--gitleaks-ignore-path', ignorePath], {
    cwd, encoding: 'utf8', timeout: 10000, maxBuffer: 1024 * 1024,
  });
  // Scanner output remains private even when a synthetic fixture fails.
  assert.equal(result.error, undefined, 'Scanner must start successfully.');
  assert.equal(result.signal, null, 'Scanner must finish without interruption.');
  return result.status;
}

function syntheticCredential() {
  return ['token=ghp_', 'aB3dE6gH9jK2mN5pQ8', 'rS1uV4xY7zA0cD3fG6', '\n'].join('');
}

function fixture(context) {
  assert.ok(scanner, 'GITLEAKS_EXECUTABLE must identify the checksum-verified scanner.');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'gitleaks-coverage-'));
  context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return directory;
}

function repositoryFixture(context) {
  const directory = fixture(context);
  function git(...arguments_) {
    return childProcess.execFileSync('git', arguments_, {
      cwd: directory, encoding: 'utf8', timeout: 5000,
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  }
  git('init', '-q', '--initial-branch=fixture');
  git('config', 'user.name', 'Scanner Fixture');
  git('config', 'user.email', 'scanner@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  fs.writeFileSync(path.join(directory, 'clean.txt'), 'Clean baseline.\n');
  git('add', '.');
  git('commit', '-qm', 'test: clean baseline');
  return { directory, git };
}

test('the pinned scanner detects synthetic credentials in every previously excluded path', (context) => {
  const root = fixture(context);
  const candidates = ['test/fixture.txt', 'nested/test/fixture.txt',
    'google-services.json', 'android/app/google-services.json'];
  for (const [index, candidate] of ['clean.txt', ...candidates].entries()) {
    const directory = path.join(root, String(index));
    const target = path.join(directory, candidate);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    // Construct a detector-shaped, nonfunctional credential only in an isolated fixture.
    const content = index === 0 ? 'No credential here.\n'
      : syntheticCredential();
    fs.writeFileSync(target, content);
    assert.equal(scan(['dir', directory], root), index === 0 ? 0 : 1, candidate);
  }
});

test('introduced history still fails after synthetic test credentials are deleted', (context) => {
  const { directory, git } = repositoryFixture(context);
  const base = git('rev-parse', 'HEAD');
  const target = path.join(directory, 'test', 'fixture.txt');
  fs.mkdirSync(path.dirname(target));
  fs.writeFileSync(target, syntheticCredential());
  git('add', '.');
  git('commit', '-qm', 'test: introduce synthetic detector fixture');
  fs.rmSync(target);
  git('add', '-u');
  git('commit', '-qm', 'test: remove synthetic detector fixture');
  const head = git('rev-parse', 'HEAD');
  assert.equal(scan(['dir', directory], directory), 0, 'Clean merge tree must pass.');
  assert.equal(scan(['git', '--log-opts', base + '..' + head, directory], directory), 1,
    'Introduced history must still reject a deleted synthetic credential.');
});

test('an exact historical fingerprint does not exempt later identical credentials', (context) => {
  const { directory, git } = repositoryFixture(context);
  const base = git('rev-parse', 'HEAD');
  const target = path.join(directory, 'fixture.txt');
  fs.writeFileSync(target, syntheticCredential());
  git('add', '.');
  git('commit', '-qm', 'test: introduce historical synthetic fixture');
  const historical = git('rev-parse', 'HEAD');
  const report = path.join(directory, 'report.json');
  const arguments_ = ['git', '--log-opts', base + '..' + historical, directory];
  assert.equal(scan([...arguments_, '--report-format', 'json', '--report-path', report],
    directory), 1, 'The historical synthetic credential must initially be detected.');
  const findings = JSON.parse(fs.readFileSync(report, 'utf8'));
  assert.equal(findings.length, 1, 'Exactly one synthetic finding is expected.');
  const fingerprint = findings[0].Fingerprint;
  assert.equal(fingerprint, historical + ':fixture.txt:github-pat:1',
    'The exemption must bind the commit, path, rule and line.');
  const ignorePath = path.join(directory, '.gitleaksignore');
  fs.writeFileSync(ignorePath, fingerprint + '\n');
  assert.equal(scan(arguments_, directory, ignorePath), 0,
    'The exact historical fingerprint must be ignored.');
  fs.rmSync(target);
  git('add', '-u');
  git('commit', '-qm', 'test: remove historical synthetic fixture');
  fs.writeFileSync(target, syntheticCredential());
  git('add', 'fixture.txt');
  git('commit', '-qm', 'test: reintroduce identical synthetic fixture');
  const head = git('rev-parse', 'HEAD');
  assert.equal(scan(['git', '--log-opts', historical + '..' + head, directory],
    directory, ignorePath), 1,
  'The same credential at the same path and line in a later commit must fail.');
});
