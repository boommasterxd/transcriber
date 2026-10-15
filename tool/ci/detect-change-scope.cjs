'use strict';

const childProcess = require('node:child_process');

/** @param {string | undefined} value */
function isCommitSha(value) {
  return typeof value === 'string' && /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/i.test(value)
    && !/^0+$/.test(value);
}

/**
 * Unknown or incomplete change scope must run the full CI.
 * @param {string | undefined} event
 * @param {string | undefined} baseSha
 * @param {string | undefined} headSha
 * @param {string} cwd
 * @returns {boolean}
 */
function detectDocsOnly(event, baseSha, headSha, cwd = process.cwd()) {
  if (!['pull_request', 'push'].includes(event ?? '') || !isCommitSha(baseSha) || !isCommitSha(headSha)) {
    return false;
  }
  const separator = event === 'pull_request' ? '...' : '..';
  try {
    // Disabling rename detection keeps both endpoints visible at directory boundaries.
    const output = childProcess.execFileSync('git', [
      'diff', '--name-only', '--no-renames', '-z', `${baseSha}${separator}${headSha}`, '--',
    ], { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 5000, maxBuffer: 256 * 1024 });
    if (!output || !output.endsWith('\0')) return false;
    return output.slice(0, -1).split('\0').every((path) => path.startsWith('docs/') && path.length > 5);
  } catch {
    return false;
  }
}

module.exports = { detectDocsOnly };

if (require.main === module) {
  const { CHANGE_EVENT, CHANGE_BASE_SHA, CHANGE_HEAD_SHA } = process.env;
  console.log(`docs_only=${detectDocsOnly(CHANGE_EVENT, CHANGE_BASE_SHA, CHANGE_HEAD_SHA)}`);
}
