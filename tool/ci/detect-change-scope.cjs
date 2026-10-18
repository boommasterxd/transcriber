'use strict';

const childProcess = require('node:child_process');

/** @param {string | undefined} value */
function isCommitSha(value) {
  return typeof value === 'string' && /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/i.test(value)
    && !/^0+$/.test(value);
}

const CHECKS = ['workflow', 'dart', 'native', 'build', 'dependency_audit'];

function fullScope() {
  return { docs_only: false, ...Object.fromEntries(CHECKS.map((name) => [name, true])) };
}

/** A deliberately closed allowlist: new, unrecognized paths run every check. */
function checksForPath(path) {
  if (path.startsWith('docs/') && path.length > 5) return [];
  if (path.endsWith('/flutter_test_config.dart')) return CHECKS;
  if (['pubspec.yaml', 'pubspec.lock', '.fvmrc', 'analysis_options.yaml', '.github/workflows/ci.yml',
    '.github/workflows/gitleaks.yml', '.github/workflows/update-gitleaks.yml',
    '.github/workflows/dependency-audit.yml',
    '.github/actions/setup-flutter/action.yml'].includes(path)) return CHECKS;
  if (/^\.github\/workflows\/[^/]+\.ya?ml$/.test(path)
    || ['.github/dependabot.yml', '.github/release.yml'].includes(path)) return ['workflow'];
  if (/^(tool|test\/tool)\/ci\/[^/]+\.cjs$/.test(path)) return ['workflow'];
  if (/^android\/app\/src\/(test|androidTest)\//.test(path)
    || path === 'config/detekt.yml') return ['native'];
  if (/^android\/app\/src\/main\/kotlin\/com\/transcriber\/app\/(EditorFieldPolicy|EditorSessionGate|ImeNavigationBarAppearance|PcmLevelMeter|ShareFileNamePolicy)\.kt$/.test(path)) {
    return ['native'];
  }
  if (path.startsWith('android/')) return ['dart', 'native'];
  if (path === 'tool/quality/check_kotlin_quality.sh') return ['workflow', 'native'];
  if (/^tool\/package\/.*\.sh$/.test(path)) return ['workflow', 'dart', 'build'];
  // Native entrypoint names and channel payloads are runtime contracts.
  if (['lib/main.dart', 'lib/share_entrypoint.dart', 'lib/keyboard_entrypoint.dart',
    'lib/services/dictation/dictation_platform.dart'].includes(path)) return ['dart', 'native', 'build'];
  if (/^lib\/.*\.dart$/.test(path)) return ['dart'];
  if (/^(test|tool)\/.*\.dart$/.test(path)) return ['dart'];
  if (path.startsWith('assets/')) return ['dart', 'build'];
  return CHECKS;
}

function classifyPaths(paths) {
  if (paths.length === 0 || paths.some((path) => !path)) return fullScope();
  const required = new Set(paths.flatMap(checksForPath));
  // Advisory databases change independently of the lockfile and import graph.
  if (required.size !== 0) required.add('dependency_audit');
  return { docs_only: required.size === 0,
    ...Object.fromEntries(CHECKS.map((name) => [name, required.has(name)])) };
}

/** Unknown or incomplete scope must run full CI, never an optimistic partial plan. */
function detectChangeScope(event, baseSha, headSha, cwd = process.cwd()) {
  if (!['pull_request', 'push'].includes(event ?? '') || !isCommitSha(baseSha) || !isCommitSha(headSha)) {
    return fullScope();
  }
  const separator = event === 'pull_request' ? '...' : '..';
  try {
    // Disabling rename detection keeps both endpoints visible at directory boundaries.
    const output = childProcess.execFileSync('git', [
      'diff', '--name-only', '--no-renames', '-z', `${baseSha}${separator}${headSha}`, '--',
    ], { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 5000, maxBuffer: 256 * 1024 });
    if (!output || !output.endsWith('\0')) return fullScope();
    return classifyPaths(output.slice(0, -1).split('\0'));
  } catch {
    return fullScope();
  }
}

function detectDocsOnly(...arguments_) {
  return detectChangeScope(...arguments_).docs_only;
}

module.exports = { detectChangeScope, detectDocsOnly, classifyPaths };

if (require.main === module) {
  const { CHANGE_EVENT, CHANGE_BASE_SHA, CHANGE_HEAD_SHA } = process.env;
  const scope = detectChangeScope(CHANGE_EVENT, CHANGE_BASE_SHA, CHANGE_HEAD_SHA);
  for (const [name, value] of Object.entries(scope)) console.log(`${name}=${value}`);
}
