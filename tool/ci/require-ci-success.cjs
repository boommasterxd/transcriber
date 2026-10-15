'use strict';

const REQUIRED_JOBS = [
  'workflow-lint', 'analyze', 'metrics', 'dead-code',
  'kotlin-quality', 'duplication', 'build', 'dependency-audit',
];

/** Validate each prerequisite, including intentional documentation-only skips. */
function requireCiSuccess(needs) {
  if (needs?.changes?.result !== 'success') {
    throw new Error('Change classification must succeed.');
  }
  const docsOnly = needs.changes.outputs?.docs_only;
  if (docsOnly !== 'true' && docsOnly !== 'false') {
    throw new Error('Change classification must produce true or false.');
  }
  const expected = docsOnly === 'true' ? 'skipped' : 'success';
  for (const job of REQUIRED_JOBS) {
    if (needs[job]?.result !== expected) {
      throw new Error(`Required job ${job} must be ${expected}.`);
    }
  }
}

module.exports = { requireCiSuccess };

if (require.main === module) {
  try {
    requireCiSuccess(JSON.parse(process.env.CI_NEEDS ?? 'null'));
    console.log('Every applicable CI job succeeded.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
