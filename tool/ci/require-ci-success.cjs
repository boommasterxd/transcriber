'use strict';

const REQUIRED_JOBS = [
  'workflow-lint', 'dart-quality', 'jvm-quality', 'kotlin-quality', 'dependency-audit',
];
const FLAGS = ['docs_only', 'workflow', 'dart', 'jvm', 'native', 'device', 'build', 'dependency_audit',
  'gitleaks_updater_only'];
const REVISIONS = ['base_sha', 'head_sha', 'merge_sha'];

function validateRevisionBinding(outputs, revisions) {
  for (const key of REVISIONS) {
    const value = outputs?.[key];
    if (typeof value !== 'string' || !/^(?:[a-f0-9]{40}|[a-f0-9]{64})$/.test(value)
      || /^0+$/.test(value) || value !== revisions?.[key]) {
      throw new Error(`CI plan revision ${key} must match the current workflow.`);
    }
  }
}

function jobPlan(outputs) {
  if (!outputs || Object.keys(outputs).length !== FLAGS.length + REVISIONS.length
    || FLAGS.some((flag) => !['true', 'false'].includes(outputs[flag]))) {
    throw new Error('Change classification must produce a complete boolean plan.');
  }
  const flags = Object.fromEntries(FLAGS.map((flag) => [flag, outputs[flag] === 'true']));
  if (flags.docs_only !== !FLAGS.slice(1).some((flag) => flags[flag])) {
    throw new Error('Documentation-only classification contradicts the job plan.');
  }
  if (!flags.docs_only && !flags.dependency_audit) {
    throw new Error('Non-documentation changes require a fresh dependency audit.');
  }
  if (flags.native && !flags.jvm) {
    throw new Error('Android checks must include the JVM test scope.');
  }
  if (flags.device && !flags.native) {
    throw new Error('Android device tests require the Android quality job.');
  }
  if (flags.gitleaks_updater_only
    && (!flags.workflow || ['dart', 'jvm', 'native', 'device', 'build'].some((flag) => flags[flag]))) {
    throw new Error('The Gitleaks updater test-only plan requires only workflow lint and dependency audit.');
  }
  return {
    'workflow-lint': flags.workflow,
    'dart-quality': flags.dart || (flags.build && !flags.native),
    'jvm-quality': flags.jvm && !flags.native,
    'kotlin-quality': flags.native,
    'dependency-audit': flags.dependency_audit,
  };
}

/** Validate each prerequisite, including intentional documentation-only skips. */
function requireCiSuccess(needs, revisions) {
  if (needs?.changes?.result !== 'success') {
    throw new Error('Change classification must succeed.');
  }
  if (Object.keys(needs).length !== REQUIRED_JOBS.length + 1) {
    throw new Error('CI prerequisites must match the complete expected job set.');
  }
  validateRevisionBinding(needs.changes.outputs, revisions);
  const plan = jobPlan(needs.changes.outputs);
  for (const job of REQUIRED_JOBS) {
    const expected = plan[job] ? 'success' : 'skipped';
    if (needs[job]?.result !== expected) {
      throw new Error(`Required job ${job} must be ${expected}.`);
    }
  }
  if (plan['workflow-lint']) {
    const expected = needs.changes.outputs.gitleaks_updater_only === 'true' ? 'success' : 'skipped';
    if (needs['workflow-lint'].outputs?.gitleaks_updater_tests !== expected) {
      throw new Error(`The dedicated Gitleaks updater test step must be ${expected}.`);
    }
  }
  if (plan['kotlin-quality']) {
    const expected = needs.changes.outputs.device === 'true' ? 'success' : 'skipped';
    if (needs['kotlin-quality'].outputs?.device_tests !== expected) {
      throw new Error(`Android device tests must be ${expected}.`);
    }
  }
}

module.exports = { requireCiSuccess, jobPlan };

if (require.main === module) {
  try {
    requireCiSuccess(JSON.parse(process.env.CI_NEEDS ?? 'null'), {
      base_sha: process.env.CI_BASE_SHA,
      head_sha: process.env.CI_HEAD_SHA,
      merge_sha: process.env.CI_MERGE_SHA,
    });
    console.log('Every applicable CI job succeeded.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
