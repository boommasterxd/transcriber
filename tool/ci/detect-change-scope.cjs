'use strict';

const childProcess = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

/** @param {string | undefined} value */
function isCommitSha(value) {
  return typeof value === 'string' && /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/i.test(value)
    && !/^0+$/.test(value);
}

const CHECKS = ['workflow', 'dart', 'jvm', 'native', 'build', 'dependency_audit'];

function parseJvmClasses(source) {
  const names = source.split(/\r?\n/).filter((name) => name.length > 0);
  if (!names.length || new Set(names).size !== names.length
    || names.some((name) => !/^com\.transcriber\.app\.[A-Z][A-Za-z0-9]*$/.test(name))) {
    throw new Error('The JVM source manifest must contain distinct qualified class names.');
  }
  return names;
}

const JVM_CLASSES = parseJvmClasses(fs.readFileSync(path.join(__dirname, 'jvm/sources.txt'), 'utf8'));

function fullScope() {
  return { docs_only: false, ...Object.fromEntries(CHECKS.map((name) => [name, true])) };
}

/** A deliberately closed allowlist: new, unrecognized paths run every check. */
function checksForPath(path) {
  if (path.startsWith('docs/') && path.length > 5) return [];
  if (path.endsWith('/flutter_test_config.dart')) return CHECKS;
  // Selection, execution and quality gates control the complete CI contract.
  if (/^(tool|test\/tool)\/(ci|quality)\/[^/]+\.dart$/.test(path)) return CHECKS;
  if (['pubspec.yaml', 'pubspec.lock', 'android/app/gradle.lockfile',
    '.fvmrc', 'analysis_options.yaml', '.github/workflows/ci.yml',
    '.github/workflows/gitleaks.yml', '.github/workflows/update-gitleaks.yml',
    '.github/workflows/dependency-audit.yml',
    'tool/ci/detect-change-scope.cjs', 'test/tool/ci/detect-change-scope.test.cjs',
    'tool/ci/require-ci-success.cjs', 'test/tool/ci/require-ci-success.test.cjs',
    'test/tool/ci/gitleaks.integration.cjs',
    '.github/actions/setup-flutter/action.yml'].includes(path)) return CHECKS;
  // Workflows define CI, release, build, and maintenance behavior. Any edit can
  // change the effective project gates or artifact pipeline, so validate fully.
  if (/^\.github\/workflows\/[^/]+\.ya?ml$/.test(path)
    || ['.github/dependabot.yml', '.github/release.yml'].includes(path)) return CHECKS;
  if (['test/tool/ci/jvm-test-failure.integration.cjs',
    'test/tool/ci/native-coverage.integration.cjs',
    'test/tool/ci/jvm_fixture.cjs',
    'test/tool/ci/kotlin-quality.integration.cjs'].includes(path)) return ['workflow', 'jvm'];
  if (/^(tool|test\/tool)\/ci\/[^/]+\.cjs$/.test(path)) return ['workflow'];
  const native = nativeChecksForPath(path);
  if (native) return native;
  if (path === 'tool/quality/check_kotlin_quality.sh') return ['workflow', 'native'];
  if (/^tool\/package\/.*\.sh$/.test(path)) return ['workflow', 'dart', 'build'];
  // Native entrypoint names and channel payloads are runtime contracts.
  if (['lib/main.dart', 'lib/share_entrypoint.dart', 'lib/keyboard_entrypoint.dart',
    'lib/services/dictation/dictation_platform.dart',
    'lib/services/audio/audio_recorder_service.dart'].includes(path)) return ['dart', 'native', 'build'];
  if (/^lib\/.*\.dart$/.test(path)) return ['dart'];
  if (/^(test|tool)\/.*\.dart$/.test(path)) return ['dart'];
  if (path.startsWith('assets/')) return ['dart', 'build'];
  return CHECKS;
}

function nativeChecksForPath(path) {
  for (const name of JVM_CLASSES) {
    const classPath = name.replaceAll('.', '/');
    if (path === `android/app/src/test/kotlin/${classPath}Test.kt`) return ['jvm'];
    if (path === `android/app/src/main/kotlin/${classPath}.kt`) return ['jvm', 'native'];
  }
  if (/^android\/app\/src\/(test|androidTest)\//.test(path)
    || path === 'config/detekt.yml') return ['native'];
  if (/^android\/app\/src\/main\/kotlin\/com\/transcriber\/app\/(EditorFieldPolicy|ImeNavigationBarAppearance|ShareFileNamePolicy)\.kt$/.test(path)) {
    return ['native'];
  }
  if (path.startsWith('android/')) return ['dart', 'native'];
  return null;
}

function classifyPaths(paths) {
  if (paths.length === 0 || paths.some((path) => !path)) return fullScope();
  const required = new Set(paths.flatMap(checksForPath));
  // Advisory databases change independently of the lockfile and import graph.
  if (required.size !== 0) required.add('dependency_audit');
  // The complete Android test task also fulfills the pure JVM test scope.
  if (required.has('native')) required.add('jvm');
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

function createChangePlan(event, baseSha, headSha, cwd = process.cwd()) {
  const mergeSha = childProcess.execFileSync('git', ['rev-parse', 'HEAD'], {
    cwd, encoding: 'utf8', timeout: 5000, maxBuffer: 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
  const base = event === 'workflow_dispatch' ? mergeSha : baseSha;
  const head = event === 'workflow_dispatch' ? mergeSha : headSha;
  if (![base, head, mergeSha].every(isCommitSha)) {
    throw new Error('The CI plan requires valid base, head and checkout revisions.');
  }
  return {
    ...detectChangeScope(event, base, head, cwd),
    base_sha: base, head_sha: head, merge_sha: mergeSha,
  };
}

module.exports = { detectChangeScope, detectDocsOnly, classifyPaths, parseJvmClasses, createChangePlan };

if (require.main === module) {
  const { CHANGE_EVENT, CHANGE_BASE_SHA, CHANGE_HEAD_SHA } = process.env;
  try {
    const plan = createChangePlan(CHANGE_EVENT, CHANGE_BASE_SHA, CHANGE_HEAD_SHA);
    for (const [name, value] of Object.entries(plan)) console.log(`${name}=${value}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
