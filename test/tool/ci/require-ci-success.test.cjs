'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const path = require('node:path');
const test = require('node:test');
const { requireCiSuccess } = require('../../../tool/ci/require-ci-success.cjs');

const jobs = [
  'workflow-lint', 'dart-quality', 'jvm-quality', 'kotlin-quality', 'dependency-audit',
];
const flags = ['workflow', 'dart', 'jvm', 'native', 'build', 'dependency_audit'];

function prerequisites(docsOnly = 'false') {
  return {
    changes: { result: 'success', outputs: { docs_only: docsOnly,
      ...Object.fromEntries(flags.map((flag) => [flag, docsOnly === 'true' ? 'false' : 'true'])) } },
    ...Object.fromEntries(jobs.map((job) => [job, {
      result: docsOnly === 'true' || job === 'jvm-quality' ? 'skipped' : 'success',
    }])),
  };
}

test('full CI requires all quality, build and security jobs', () => {
  assert.doesNotThrow(() => requireCiSuccess(prerequisites()));
  for (const job of jobs) {
    const expected = prerequisites()[job].result;
    for (const result of ['failure', 'cancelled', 'skipped', 'success', 'pending', undefined]
      .filter((result) => result !== expected)) {
      const needs = prerequisites();
      needs[job].result = result;
      assert.throws(() => requireCiSuccess(needs), new RegExp(job));
    }
    const needs = prerequisites();
    delete needs[job];
    assert.throws(() => requireCiSuccess(needs));
  }
});

test('scoped plans require only their exact jobs, and every other job must be skipped', () => {
  const cases = [
    [['workflow'], ['workflow-lint']],
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
    for (const job of required) needs[job].result = 'success';
    assert.doesNotThrow(() => requireCiSuccess(needs));
    for (const job of jobs) {
      const expected = needs[job].result;
      for (const wrong of ['failure', 'cancelled', 'pending', undefined,
        expected === 'success' ? 'skipped' : 'success']) {
        needs[job].result = wrong;
        assert.throws(() => requireCiSuccess(needs), new RegExp(job));
      }
      needs[job].result = expected;
    }
  }
});

test('Android owns the JVM scope when both are selected', () => {
  const needs = prerequisites();
  assert.equal(needs['jvm-quality'].result, 'skipped');
  assert.doesNotThrow(() => requireCiSuccess(needs));
  needs.changes.outputs.jvm = 'false';
  assert.throws(() => requireCiSuccess(needs), /JVM test scope/);
});

test('a non-documentation plan cannot intentionally skip fresh dependency advisories', () => {
  const needs = prerequisites();
  needs.changes.outputs.dependency_audit = 'false';
  needs['dependency-audit'].result = 'skipped';
  assert.throws(() => requireCiSuccess(needs), /fresh dependency audit/);
});

test('invalid, contradictory, additional and incomplete plans cannot pass', () => {
  for (const flag of ['docs_only', ...flags]) {
    for (const value of [undefined, '', true, false, 'TRUE', 'false\n']) {
      const needs = prerequisites();
      needs.changes.outputs[flag] = value;
      assert.throws(() => requireCiSuccess(needs));
    }
    const needs = prerequisites();
    delete needs.changes.outputs[flag];
    assert.throws(() => requireCiSuccess(needs));
  }
  const contradiction = prerequisites('true');
  contradiction.changes.outputs.dart = 'true';
  assert.throws(() => requireCiSuccess(contradiction));
  const empty = prerequisites('true');
  empty.changes.outputs.docs_only = 'false';
  assert.throws(() => requireCiSuccess(empty));
  const extraOutput = prerequisites();
  extraOutput.changes.outputs.unknown = 'true';
  assert.throws(() => requireCiSuccess(extraOutput));
  const extraJob = prerequisites();
  extraJob.unknown = { result: 'success' };
  assert.throws(() => requireCiSuccess(extraJob));
});

test('documentation-only CI requires deliberate skips for every expensive job', () => {
  assert.doesNotThrow(() => requireCiSuccess(prerequisites('true')));
  for (const job of jobs) {
    for (const result of ['failure', 'cancelled', 'success', undefined]) {
      const needs = prerequisites('true');
      needs[job].result = result;
      assert.throws(() => requireCiSuccess(needs), new RegExp(job));
    }
  }
});

test('failed, cancelled, absent or malformed classification cannot pass', () => {
  for (const needs of [null, {}, undefined]) {
    assert.throws(() => requireCiSuccess(needs));
  }
  for (const result of ['failure', 'cancelled', 'skipped', undefined]) {
    const needs = prerequisites();
    needs.changes.result = result;
    assert.throws(() => requireCiSuccess(needs));
  }
  for (const output of [undefined, '', true, false, 'TRUE', 'false\n']) {
    const needs = prerequisites();
    needs.changes.outputs.docs_only = output;
    assert.throws(() => requireCiSuccess(needs));
  }
  const needs = prerequisites();
  delete needs.changes.outputs;
  assert.throws(() => requireCiSuccess(needs));
});

test('CLI fails closed for invalid input and failed prerequisites', () => {
  const script = path.join(__dirname, '../../../tool/ci/require-ci-success.cjs');
  for (const [input, expected] of [
    [JSON.stringify(prerequisites()), 0],
    [JSON.stringify(prerequisites('true')), 0],
    ['{}', 1], ['null', 1], ['invalid JSON', 1], ['', 1],
  ]) {
    const result = childProcess.spawnSync(process.execPath, [script], {
      encoding: 'utf8', timeout: 5000, env: { ...process.env, CI_NEEDS: input },
    });
    assert.equal(result.status, expected, result.stderr);
  }
});
