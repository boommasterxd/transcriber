'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const childProcess = require('node:child_process');
const test = require('node:test');
const { detectDocsOnly } = require('../../../tool/ci/detect-change-scope.cjs');

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

test('CLI emits a single GitHub output assignment and exits successfully on uncertainty', (context) => {
  const { cwd, base } = fixture(context);
  write(cwd, 'docs/guide.md', 'Updated\n');
  const head = commit(cwd);
  const script = path.join(__dirname, '../../../tool/ci/detect-change-scope.cjs');
  for (const [event, expected] of [['push', 'true'], ['pull_request', 'true'], ['', 'false']]) {
    const output = childProcess.execFileSync(process.execPath, [script], {
      cwd, encoding: 'utf8', timeout: 5000,
      env: { ...process.env, CHANGE_EVENT: event, CHANGE_BASE_SHA: base, CHANGE_HEAD_SHA: head },
    });
    assert.equal(output, `docs_only=${expected}\n`);
  }
});
