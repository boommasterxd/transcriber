'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const path = require('node:path');
const test = require('node:test');
const { requireCiSuccess } = require('../../../tool/ci/require-ci-success.cjs');

const jobs = [
  'workflow-lint', 'analyze', 'metrics', 'dead-code',
  'kotlin-quality', 'duplication', 'build', 'dependency-audit',
];

function prerequisites(docsOnly = 'false') {
  return {
    changes: { result: 'success', outputs: { docs_only: docsOnly } },
    ...Object.fromEntries(jobs.map((job) => [job, {
      result: docsOnly === 'true' ? 'skipped' : 'success',
    }])),
  };
}

test('full CI requires all quality, build and security jobs', () => {
  assert.doesNotThrow(() => requireCiSuccess(prerequisites()));
  for (const job of jobs) {
    for (const result of ['failure', 'cancelled', 'skipped', 'pending', undefined]) {
      const needs = prerequisites();
      needs[job].result = result;
      assert.throws(() => requireCiSuccess(needs), new RegExp(job));
    }
    const needs = prerequisites();
    delete needs[job];
    assert.throws(() => requireCiSuccess(needs), new RegExp(job));
  }
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
