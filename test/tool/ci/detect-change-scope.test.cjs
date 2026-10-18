'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const childProcess = require('node:child_process');
const test = require('node:test');
const { detectDocsOnly, detectChangeScope, classifyPaths } = require('../../../tool/ci/detect-change-scope.cjs');

function scope(...checks) {
  return { docs_only: checks.length === 0,
    ...Object.fromEntries(['workflow', 'dart', 'native', 'build', 'dependency_audit']
      .map((name) => [name, checks.includes(name)
        || (name === 'dependency_audit' && checks.length > 0)])) };
}

test('fresh advisories remain a required gate even when dependency files are unchanged', () => {
  for (const file of ['lib/app.dart', 'test/example_test.dart', '.github/workflows/release.yml']) {
    assert.equal(classifyPaths([file]).dependency_audit, true);
  }
  assert.equal(classifyPaths(['docs/guide.md']).dependency_audit, false);
});

test('known paths request precisely their relevant checks', () => {
  const cases = [
    ['docs/nested/guide.md', []],
    ['.github/workflows/release.yml', ['workflow']],
    ['.github/dependabot.yml', ['workflow']],
    ['tool/ci/detect-change-scope.cjs', ['workflow']],
    ['test/tool/ci/detect-change-scope.test.cjs', ['workflow']],
    ['android/app/src/main/kotlin/Example.kt', ['dart', 'native']],
    ['android/app/src/main/AndroidManifest.xml', ['dart', 'native']],
    ['android/app/src/main/res/values/strings.xml', ['dart', 'native']],
    ['android/app/build.gradle.kts', ['dart', 'native']],
    ['android/app/src/test/kotlin/ExampleTest.kt', ['native']],
    ['android/app/src/androidTest/kotlin/ExampleTest.kt', ['native']],
    ['config/detekt.yml', ['native']],
    ['tool/quality/check_kotlin_quality.sh', ['workflow', 'native']],
    ['tool/package/version.sh', ['workflow', 'dart', 'build']],
    ['lib/services/example.dart', ['dart', 'build']],
    ['test/services/example_test.dart', ['dart']],
    ['tool/ci/select_tests.dart', ['dart']],
    ['assets/images/example.png', ['dart', 'build']],
  ];
  for (const [name, checks] of cases) {
    assert.deepEqual(classifyPaths([name]), scope(...checks), name);
  }
});

test('shared foundations, unknown paths and incomplete inputs require every check', () => {
  const full = scope('workflow', 'dart', 'native', 'build', 'dependency_audit');
  for (const name of ['pubspec.yaml', 'pubspec.lock', '.fvmrc', 'analysis_options.yaml',
    'test/flutter_test_config.dart', 'test/nested/flutter_test_config.dart', '.github/workflows/ci.yml',
    '.github/workflows/gitleaks.yml', '.github/workflows/update-gitleaks.yml',
    '.github/workflows/dependency-audit.yml', '.gitleaks.toml',
    '.github/actions/setup-flutter/action.yml', '.github/actions/new/action.yml',
    '.github/new-config.toml', 'README.md', 'new/config.toml', '']) {
    assert.deepEqual(classifyPaths([name]), full, name);
  }
  assert.deepEqual(classifyPaths([]), full);
  assert.deepEqual(classifyPaths(['docs/a.md', 'test/a_test.dart', 'android/a.kt']), scope('dart', 'native'));
});

/** @param {string} cwd @param {string[]} args */
function git(cwd, args) {
  return childProcess.execFileSync('git', args, { cwd, encoding: 'utf8', timeout: 5000 }).trim();
}

/** @param {string} cwd @param {string} name @param {string} content */
function write(cwd, name, content) {
  const file = path.join(cwd, name);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}

/** @param {string} cwd */
function commit(cwd) {
  git(cwd, ['add', '.']);
  git(cwd, ['commit', '-qm', 'test: update fixture']);
  return git(cwd, ['rev-parse', 'HEAD']);
}

/** @param {import('node:test').TestContext} context */
function fixture(context) {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'ci-change-scope-'));
  context.after(() => fs.rmSync(cwd, { recursive: true, force: true }));
  git(cwd, ['init', '-q', '--initial-branch=main']);
  git(cwd, ['config', 'user.email', 'test@example.com']);
  git(cwd, ['config', 'user.name', 'Test']);
  write(cwd, 'docs/guide.md', 'Guide\n');
  write(cwd, 'src/index.js', 'module.exports = 1;\n');
  return { cwd, base: commit(cwd) };
}

test('documentation additions, modifications and deletions skip full CI', (context) => {
  const { cwd, base } = fixture(context);
  write(cwd, 'docs/nested/notes.md', 'Notes\n');
  write(cwd, 'docs/guide.md', 'Updated guide\n');
  const added = commit(cwd);
  assert.equal(detectDocsOnly('pull_request', base, added, cwd), true);
  assert.equal(detectDocsOnly('push', base, added, cwd), true);
  fs.rmSync(path.join(cwd, 'docs/guide.md'));
  assert.equal(detectDocsOnly('push', added, commit(cwd), cwd), true);
});

test('code and mixed changes run full CI', (context) => {
  const { cwd, base } = fixture(context);
  write(cwd, 'src/index.js', 'module.exports = 2;\n');
  const code = commit(cwd);
  assert.equal(detectDocsOnly('push', base, code, cwd), false);
  write(cwd, 'docs/guide.md', 'Updated\n');
  assert.equal(detectDocsOnly('pull_request', base, commit(cwd), cwd), false);
});

test('only the root docs directory qualifies, including unusual filename characters', (context) => {
  const { cwd, base } = fixture(context);
  write(cwd, 'docs/quoted "file"\nname.md', 'Notes\n');
  const docs = commit(cwd);
  assert.equal(detectDocsOnly('push', base, docs, cwd), true);
  for (const name of ['doc/guide.md', 'nested/docs/guide.md', 'README.md', 'docs-other/guide.md']) {
    write(cwd, name, 'Outside root docs\n');
    assert.equal(detectDocsOnly('push', docs, commit(cwd), cwd), false);
  }
});

/** @type {[string, string, boolean][]} */
const renames = [
  ['src/index.js', 'docs/index.js', false],
  ['docs/guide.md', 'src/guide.md', false],
  ['docs/guide.md', 'docs/new-guide.md', true],
];
for (const [source, destination, expected] of renames) {
  test(`rename ${source} to ${destination} preserves both endpoints`, (context) => {
    const { cwd, base } = fixture(context);
    fs.renameSync(path.join(cwd, source), path.join(cwd, destination));
    assert.equal(detectDocsOnly('pull_request', base, commit(cwd), cwd), expected);
  });
}

test('the full multi-commit range includes earlier code changes', (context) => {
  const { cwd, base } = fixture(context);
  write(cwd, 'src/index.js', 'module.exports = 2;\n');
  const code = commit(cwd);
  write(cwd, 'docs/guide.md', 'Updated\n');
  const head = commit(cwd);
  assert.equal(detectDocsOnly('push', code, head, cwd), true);
  assert.equal(detectDocsOnly('push', base, head, cwd), false);
  assert.equal(detectDocsOnly('pull_request', base, head, cwd), false);
});

test('pull requests compare from the merge base while pushes compare exact endpoints', (context) => {
  const { cwd, base } = fixture(context);
  git(cwd, ['checkout', '-qb', 'feature']);
  write(cwd, 'docs/guide.md', 'Feature docs\n');
  const head = commit(cwd);
  git(cwd, ['checkout', '-q', 'main']);
  write(cwd, 'src/index.js', 'module.exports = 2;\n');
  const advancedBase = commit(cwd);
  assert.equal(detectDocsOnly('pull_request', advancedBase, head, cwd), true);
  assert.equal(detectDocsOnly('push', advancedBase, head, cwd), false);
  assert.equal(detectDocsOnly('push', base, head, cwd), true);
});

test('empty ranges and invalid, missing or unavailable commit inputs run full CI', (context) => {
  const { cwd, base } = fixture(context);
  assert.equal(detectDocsOnly('push', base, base, cwd), false);
  assert.equal(detectDocsOnly('workflow_dispatch', base, base, cwd), false);
  assert.equal(detectDocsOnly(undefined, base, base, cwd), false);
  for (const invalid of [undefined, '', 'HEAD', '--help', 'a'.repeat(39), 'z'.repeat(40), '0'.repeat(40), '0'.repeat(64)]) {
    assert.equal(detectDocsOnly('push', invalid, base, cwd), false);
    assert.equal(detectDocsOnly('push', base, invalid, cwd), false);
  }
  assert.equal(detectDocsOnly('push', 'f'.repeat(40), base, cwd), false);
  assert.equal(detectDocsOnly('push', 'f'.repeat(64), base, cwd), false);
  assert.equal(detectDocsOnly('push', base, base, path.join(cwd, 'missing')), false);
});

test('unrelated histories cannot qualify as documentation-only pull requests', (context) => {
  const { cwd, base } = fixture(context);
  git(cwd, ['checkout', '--orphan', 'unrelated']);
  git(cwd, ['rm', '-rf', '.']);
  write(cwd, 'docs/unrelated.md', 'Unrelated\n');
  assert.equal(detectDocsOnly('pull_request', base, commit(cwd), cwd), false);
});

test('Git overflow, timeout, cancellation, failure and incomplete output never skip CI', (context) => {
  const sha = 'a'.repeat(40);
  const errors = ['ENOBUFS', 'ETIMEDOUT', 'ENOENT', 'SIGTERM', 'SIGKILL'];
  for (const code of errors) {
    const mock = context.mock.method(childProcess, 'execFileSync', () => {
      throw Object.assign(new Error(code), { code });
    });
    assert.equal(detectDocsOnly('push', sha, sha), false);
    mock.mock.restore();
  }
  const mock = context.mock.method(childProcess, 'execFileSync', () => 'docs/guide.md');
  assert.equal(detectDocsOnly('push', sha, sha), false);
  mock.mock.restore();
});

test('a real documentation diff exceeding the output bound runs full CI', (context) => {
  const { cwd, base } = fixture(context);
  for (let index = 0; index < 1500; index += 1) {
    write(cwd, `docs/${index}-${'a'.repeat(190)}.md`, 'Bounded output fixture\n');
  }
  assert.equal(detectDocsOnly('push', base, commit(cwd), cwd), false);
});

test('CLI emits the complete GitHub output plan and exits successfully on uncertainty', (context) => {
  const { cwd, base } = fixture(context);
  write(cwd, 'docs/guide.md', 'Updated\n');
  const head = commit(cwd);
  const script = path.join(__dirname, '../../../tool/ci/detect-change-scope.cjs');
  for (const event of ['push', 'pull_request', '']) {
    const output = childProcess.execFileSync(process.execPath, [script], {
      cwd, encoding: 'utf8', timeout: 5000,
      env: { ...process.env, CHANGE_EVENT: event, CHANGE_BASE_SHA: base, CHANGE_HEAD_SHA: head },
    });
    const expected = detectChangeScope(event, base, head, cwd);
    assert.equal(output, Object.entries(expected).map(([name, value]) => `${name}=${value}\n`).join(''));
  }
});

test('real deletions and cross-category renames include both affected check sets', (context) => {
  const { cwd, base } = fixture(context);
  write(cwd, 'lib/example.dart', 'void main() {}\n');
  const source = commit(cwd);
  fs.mkdirSync(path.join(cwd, 'test'), { recursive: true });
  fs.renameSync(path.join(cwd, 'lib/example.dart'), path.join(cwd, 'test/example_test.dart'));
  const moved = commit(cwd);
  assert.deepEqual(detectChangeScope('pull_request', source, moved, cwd), scope('dart', 'build'));
  fs.rmSync(path.join(cwd, 'test/example_test.dart'));
  assert.deepEqual(detectChangeScope('pull_request', moved, commit(cwd), cwd), scope('dart'));
  assert.equal(detectChangeScope('push', base, moved, cwd).docs_only, false);
});
