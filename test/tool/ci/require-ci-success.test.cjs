'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const path = require('node:path');
const test = require('node:test');
const { requireCiSuccess } = require('../../../tool/ci/require-ci-success.cjs');

const jobs = [
  'workflow-lint', 'dart-quality', 'jvm-quality', 'kotlin-quality', 'dependency-audit',
];
const flags = ['workflow', 'dart', 'jvm', 'native', 'device', 'build', 'dependency_audit', 'gitleaks_updater_only'];
const revisions = { base_sha: 'a'.repeat(40), head_sha: 'b'.repeat(40), merge_sha: 'c'.repeat(40) };

function prerequisites(docsOnly = 'false') {
  return {
    changes: { result: 'success', outputs: { ...revisions, docs_only: docsOnly,
      ...Object.fromEntries(flags.map((flag) => [flag,
        flag === 'gitleaks_updater_only' || docsOnly === 'true' ? 'false' : 'true'])) } },
    ...Object.fromEntries(jobs.map((job) => [job, {
      result: docsOnly === 'true' || job === 'jvm-quality' ? 'skipped' : 'success',
      ...(job === 'kotlin-quality' ? { outputs: { device_tests: docsOnly === 'true' ? 'skipped' : 'success' } } : {}),
      ...(job === 'workflow-lint' ? { outputs: { gitleaks_updater_tests: 'skipped' } } : {}),
    }])),
  };
}

test('full CI requires all quality, build and security jobs', () => {
  assert.doesNotThrow(() => requireCiSuccess(prerequisites(), revisions));
  for (const job of jobs) {
    const expected = prerequisites()[job].result;
    for (const result of ['failure', 'cancelled', 'skipped', 'success', 'pending', undefined]
      .filter((result) => result !== expected)) {
      const needs = prerequisites();
      needs[job].result = result;
      assert.throws(() => requireCiSuccess(needs, revisions), new RegExp(job));
    }
    const needs = prerequisites();
    delete needs[job];
    assert.throws(() => requireCiSuccess(needs, revisions));
  }
});

test('scoped plans require only their exact jobs, and every other job must be skipped', () => {
  const cases = [
    [['workflow'], ['workflow-lint']],
    [['workflow', 'gitleaks_updater_only'], ['workflow-lint']],
    [['dart'], ['dart-quality']],
    [['jvm'], ['jvm-quality']],
    [['jvm', 'native'], ['kotlin-quality']],
    [['build'], ['dart-quality']],
    [['build', 'jvm', 'native'], ['kotlin-quality']],
    [['dependency_audit'], ['dependency-audit']],
    [['workflow', 'dart', 'build'], ['workflow-lint', 'dart-quality']],
  ];
  for (const [selected, required] of cases) {
    const needs = prerequisites('true');
    needs.changes.outputs.docs_only = 'false';
    for (const flag of selected) needs.changes.outputs[flag] = 'true';
    needs.changes.outputs.dependency_audit = 'true';
    needs['dependency-audit'].result = 'success';
    needs['kotlin-quality'].outputs.device_tests = selected.includes('device') ? 'success' : 'skipped';
    const updaterOnly = selected.includes('gitleaks_updater_only');
    if (updaterOnly) needs['workflow-lint'].outputs.gitleaks_updater_tests = 'success';
    for (const job of required) needs[job].result = 'success';
    assert.doesNotThrow(() => requireCiSuccess(needs, revisions));
    for (const job of jobs) {
      const expected = needs[job].result;
      for (const wrong of ['failure', 'cancelled', 'pending', undefined,
        expected === 'success' ? 'skipped' : 'success']) {
        needs[job].result = wrong;
        assert.throws(() => requireCiSuccess(needs, revisions), new RegExp(job));
      }
      needs[job].result = expected;
    }
    if (updaterOnly) {
      const outputs = needs['workflow-lint'].outputs;
      for (const result of ['failure', 'cancelled', 'skipped', '', undefined]) {
        outputs.gitleaks_updater_tests = result;
        assert.throws(() => requireCiSuccess(needs, revisions), /Gitleaks updater test step must be success/);
      }
    }
  }
});

test('selected Android device tests need an actual successful step result', () => {
  for (const result of ['failure', 'skipped', 'cancelled', '', undefined]) {
    const needs = prerequisites();
    needs['kotlin-quality'].outputs.device_tests = result;
    assert.throws(() => requireCiSuccess(needs, revisions), /device tests must be success/);
  }
  const needs = prerequisites();
  needs.changes.outputs.native = 'false';
  assert.throws(() => requireCiSuccess(needs, revisions), /device tests require the Android quality job/);
  needs.changes.outputs.native = 'true';
  needs.changes.outputs.device = 'false';
  assert.throws(() => requireCiSuccess(needs, revisions), /device tests must be skipped/);
});

test('a non-documentation plan cannot intentionally skip fresh dependency advisories', () => {
  const needs = prerequisites();
  needs.changes.outputs.dependency_audit = 'false';
  needs['dependency-audit'].result = 'skipped';
  assert.throws(() => requireCiSuccess(needs, revisions), /fresh dependency audit/);
});

test('invalid, contradictory, additional and incomplete plans cannot pass', () => {
  for (const flag of ['docs_only', ...flags]) {
    for (const value of [undefined, '', true, false, 'TRUE', 'false\n']) {
      const needs = prerequisites();
      needs.changes.outputs[flag] = value;
      assert.throws(() => requireCiSuccess(needs, revisions));
    }
    const needs = prerequisites();
    delete needs.changes.outputs[flag];
    assert.throws(() => requireCiSuccess(needs, revisions));
  }
  const contradiction = prerequisites('true');
  contradiction.changes.outputs.dart = 'true';
  assert.throws(() => requireCiSuccess(contradiction, revisions));
  const empty = prerequisites('true');
  empty.changes.outputs.docs_only = 'false';
  assert.throws(() => requireCiSuccess(empty, revisions));
  const contradictoryUpdater = prerequisites();
  contradictoryUpdater.changes.outputs.gitleaks_updater_only = 'true';
  assert.throws(() => requireCiSuccess(contradictoryUpdater, revisions), /Gitleaks updater test-only plan/);
  const extraOutput = prerequisites();
  extraOutput.changes.outputs.unknown = 'true';
  assert.throws(() => requireCiSuccess(extraOutput, revisions));
  const extraJob = prerequisites();
  extraJob.unknown = { result: 'success' };
  assert.throws(() => requireCiSuccess(extraJob, revisions));
});

test('documentation-only CI requires deliberate skips for every expensive job', () => {
  assert.doesNotThrow(() => requireCiSuccess(prerequisites('true'), revisions));
  for (const job of jobs) {
    for (const result of ['failure', 'cancelled', 'success', undefined]) {
      const needs = prerequisites('true');
      needs[job].result = result;
      assert.throws(() => requireCiSuccess(needs, revisions), new RegExp(job));
    }
  }
});

test('failed, cancelled, absent or malformed classification cannot pass', () => {
  for (const needs of [null, {}, undefined]) {
    assert.throws(() => requireCiSuccess(needs, revisions));
  }
  for (const result of ['failure', 'cancelled', 'skipped', undefined]) {
    const needs = prerequisites();
    needs.changes.result = result;
    assert.throws(() => requireCiSuccess(needs, revisions));
  }
  for (const output of [undefined, '', true, false, 'TRUE', 'false\n']) {
    const needs = prerequisites();
    needs.changes.outputs.docs_only = output;
    assert.throws(() => requireCiSuccess(needs, revisions));
  }
  const needs = prerequisites();
  delete needs.changes.outputs;
  assert.throws(() => requireCiSuccess(needs, revisions));
});

test('old and malformed revision bindings cannot approve even a docs-only plan', () => {
  for (const key of Object.keys(revisions)) {
    for (const value of [undefined, '', 'HEAD', '0'.repeat(40), 'f'.repeat(40)]) {
      const needs = prerequisites('true');
      needs.changes.outputs[key] = value;
      assert.throws(() => requireCiSuccess(needs, revisions), new RegExp(key));
    }
    const needs = prerequisites('true');
    delete needs.changes.outputs[key];
    assert.throws(() => requireCiSuccess(needs, revisions), new RegExp(key));
    assert.throws(() => requireCiSuccess(prerequisites(), {
      ...revisions, [key]: 'd'.repeat(40),
    }), new RegExp(key));
  }
  assert.throws(() => requireCiSuccess(prerequisites()));
});

test('CLI rejects a complete successful plan from a different workflow revision', () => {
  const script = path.join(__dirname, '../../../tool/ci/require-ci-success.cjs');
  const result = childProcess.spawnSync(process.execPath, [script], {
    encoding: 'utf8', timeout: 5000,
    env: { ...process.env, CI_NEEDS: JSON.stringify(prerequisites('true')),
      CI_BASE_SHA: revisions.base_sha, CI_HEAD_SHA: revisions.head_sha,
      CI_MERGE_SHA: 'd'.repeat(40) },
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /merge_sha/);
});
