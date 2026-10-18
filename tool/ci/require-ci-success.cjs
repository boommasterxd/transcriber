'use strict';

const REQUIRED_JOBS = [
  'workflow-lint', 'dart-quality', 'kotlin-quality', 'dependency-audit',
];
const FLAGS = ['docs_only', 'workflow', 'dart', 'native', 'build', 'dependency_audit'];

function jobPlan(outputs) {
  if (!outputs || Object.keys(outputs).length !== FLAGS.length
    || FLAGS.some((flag) => !['true', 'false'].includes(outputs[flag]))) {
    throw new Error('Change classification must produce a complete boolean plan.');
  }
  const flags = Object.fromEntries(FLAGS.map((flag) => [flag, outputs[flag] === 'true']));
  if (flags.docs_only !== !FLAGS.slice(1).some((flag) => flags[flag])) {
    throw new Error('Documentation-only classification contradicts the job plan.');
  }
  return {
    'workflow-lint': flags.workflow,
    'dart-quality': flags.dart || flags.native || flags.build,
    'kotlin-quality': flags.native,
    'dependency-audit': flags.dependency_audit,
  };
}

/** Validate each prerequisite, including intentional documentation-only skips. */
function requireCiSuccess(needs) {
  if (needs?.changes?.result !== 'success') {
    throw new Error('Change classification must succeed.');
  }
  if (Object.keys(needs).length !== REQUIRED_JOBS.length + 1) {
    throw new Error('CI prerequisites must match the complete expected job set.');
  }
  const plan = jobPlan(needs.changes.outputs);
  for (const job of REQUIRED_JOBS) {
    const expected = plan[job] ? 'success' : 'skipped';
    if (needs[job]?.result !== expected) {
      throw new Error(`Required job ${job} must be ${expected}.`);
    }
  }
}

module.exports = { requireCiSuccess, jobPlan };

if (require.main === module) {
  try {
    requireCiSuccess(JSON.parse(process.env.CI_NEEDS ?? 'null'));
    console.log('Every applicable CI job succeeded.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
