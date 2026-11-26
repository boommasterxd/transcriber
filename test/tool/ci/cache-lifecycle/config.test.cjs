'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const childProcess = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '../../../..');
const policy = JSON.parse(fs.readFileSync(path.join(root, 'tool/ci/cache-lifecycle/policy.json'), 'utf8'));
const covered = (file) => policy.producerInputs.some((input) =>
  input.endsWith('/') ? file.startsWith(input) : file === input);

test('every blocking workflow completion can resume deferred cache cleanup', () => {
  const directory = path.join(root, '.github/workflows');
  const source = fs.readFileSync(path.join(directory, 'cache-lifecycle.yml'), 'utf8');
  const trigger = source.split('    workflows:\n')[1].split('    types:')[0];
  const subscriptions = [...trigger.matchAll(/^ {6}- (.+)$/gm)].map((match) => match[1]);
  const workflows = fs.readdirSync(directory).filter((file) => file.endsWith('.yml')
    && file !== 'cache-lifecycle.yml').map((file) => {
    return fs.readFileSync(path.join(directory, file), 'utf8').match(/^name: (.+)$/m)[1];
  });
  assert.deepEqual(subscriptions.toSorted(), workflows.toSorted());
});

test('producer ancestry proof covers native hash inputs and setup entrypoints', () => {
  const action = fs.readFileSync(path.join(root, '.github/actions/dependency-cache/action.yml'), 'utf8');
  const patterns = [...action.matchAll(/hashFiles\(([^)]+)\)/g)]
    .flatMap((match) => [...match[1].matchAll(/'([^']+)'/g)].map((part) => part[1]));
  const files = childProcess.execFileSync('git', [
    'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--',
    ...patterns.map((pattern) => `:(glob)${pattern}`),
  ], { cwd: root, encoding: 'utf8', timeout: 5000 }).split('\0')
    .filter((file) => file && fs.existsSync(path.join(root, file)));
  assert.ok(files.length > 0);
  for (const file of [...files, '.github/actions/setup-node-tools/action.yml',
    '.github/workflows/dependency-cache.yml', 'tool/ci/setup_android_ndk.sh',
    'tool/ci/warm-gradle-cache.init.gradle', 'android/gradlew']) {
    assert.ok(covered(file), `Unprotected producer input: ${file}`);
  }
  assert.equal(covered('lib/main.dart'), false);
  assert.equal(covered('android/app/src/main/kotlin/com/transcriber/app/MainActivity.kt'), false);
});

test('every protected producer input refreshes the trusted warmup', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/dependency-cache.yml'), 'utf8');
  const trigger = workflow.split('    paths:\n')[1].split('  workflow_dispatch:')[0];
  const patterns = [...trigger.matchAll(/^ {6}- (.+)$/gm)].map((match) => match[1]);
  for (const input of policy.producerInputs) {
    const candidate = input.endsWith('/') ? `${input}file` : input;
    const matched = patterns.some((pattern) => {
      const expression = pattern.split('**/').map((segment) => segment.split('**')
        .map((part) => part.split('*').map((literal) =>
          literal.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('[^/]*')).join('.*')).join('(?:.*/)?');
      return new RegExp(`^${expression}$`).test(candidate);
    });
    assert.ok(matched, `Producer input does not refresh its cache: ${input}`);
  }
});

test('cleanup alone can delete caches and read private pull-request state', () => {
  for (const file of ['cache-lifecycle.yml', 'dependency-cache.yml']) {
    const source = fs.readFileSync(path.join(root, '.github/workflows', file), 'utf8');
    const cleanup = source.split('\n  cleanup:\n')[1];
    const permissions = cleanup.split('    permissions:\n')[1].split('    steps:')[0];
    const entries = [...permissions.matchAll(/^ {6}([a-z-]+): (read|write)$/gm)]
      .map((match) => [match[1], match[2]]);
    assert.deepEqual(Object.fromEntries(entries), {
      contents: 'read', actions: 'write', 'pull-requests': 'read',
    });
    assert.doesNotMatch(source.split('\n  cleanup:\n')[0], /actions: write/);
  }
  for (const file of ['ci.yml', 'codeql.yml', 'build-apk.yml']) {
    const source = fs.readFileSync(path.join(root, '.github/workflows', file), 'utf8');
    assert.doesNotMatch(source, /actions: write/, `${file} must not gain cache deletion access`);
  }
  const release = fs.readFileSync(path.join(root, '.github/workflows/release.yml'), 'utf8');
  assert.doesNotMatch(release.split('\n  release:\n')[0], /actions: write/);
});
