'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '../../../..');

function runBlock(file, heading) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  const step = source.slice(source.indexOf(`- name: ${heading}`));
  const match = step.match(/\n( +)run: \|\n/);
  const indent = ' '.repeat(match[1].length + 2);
  const body = step.slice(match.index + match[0].length);
  const lines = [];
  for (const line of body.split('\n')) {
    if (line && !line.startsWith(indent)) break;
    lines.push(line.slice(indent.length));
  }
  return lines.join('\n');
}

function fixture(context) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-cache-identity-'));
  context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.writeFileSync(path.join(directory, '.fvmrc'), JSON.stringify({ flutter: '3.35.0' }));
  return { directory, output: path.join(directory, 'outputs') };
}

function identity(setup, store, mode) {
  const result = childProcess.spawnSync('bash', ['-euo', 'pipefail', '-c', runBlock(
    '.github/actions/dependency-cache/action.yml', 'Resolve compatible store identity',
  )], {
    cwd: setup.directory, encoding: 'utf8', timeout: 5000,
    env: { ...process.env, BASH_ENV: '', STORE: store, MODE: mode, RUNNER_OS: 'Linux', RUNNER_ARCH: 'X64',
      RUNNER_TOOL_CACHE: '/tool-cache', RUNNER_TEMP: '/runner-temp', HOME: '/test-home',
      FLUTTER_INPUTS: 'flutter-digest', PUB_INPUTS: 'pub-digest', NPM_INPUTS: 'npm-digest',
      GRADLE_RUNTIME: 'gradle-runtime', GRADLE_INPUTS: 'gradle-digest', GITHUB_OUTPUT: setup.output },
  });
  assert.equal(result.status, 0, result.stderr);
  const assignments = fs.readFileSync(setup.output, 'utf8');
  fs.rmSync(setup.output);
  return assignments;
}

test('native dependency outputs preserve exact producer and consumer identities', (context) => {
  const setup = fixture(context);
  for (const store of ['flutter-sdk', 'pub', 'npm', 'gradle']) {
    const restore = identity(setup, store, 'restore');
    assert.equal(identity(setup, store, 'save'), restore);
    const key = restore.match(/^key=(.+)$/m)[1];
    const prefix = restore.match(/^prefix=(.+)$/m)[1];
    assert.ok(key.startsWith(prefix), `${store} must preserve compatibility prefix`);
    assert.ok(prefix.startsWith('deps-v1-Linux-X64-'));
    assert.match(restore, /^paths<<CACHE_PATHS\n.+\nCACHE_PATHS$/ms);
  }
});

test('warmup publishes native outputs without recomputing cache identities', (context) => {
  const setup = fixture(context);
  const env = { ...process.env, BASH_ENV: '', GITHUB_OUTPUT: setup.output, RUNNER_TEMP: setup.directory };
  for (const store of ['NPM', 'PUB', 'GRADLE', 'FLUTTER', 'NDK']) {
    env[`${store}_KEY`] = `native-${store}-key`;
    env[`${store}_PREFIX`] = `native-${store}-`;
  }
  const result = childProcess.spawnSync('bash', ['-euo', 'pipefail', '-c', runBlock(
    '.github/workflows/dependency-cache.yml', 'Publish native replacement identities',
  )], { cwd: setup.directory, env, encoding: 'utf8', timeout: 5000 });
  assert.equal(result.status, 0, result.stderr);
  const replacements = JSON.parse(fs.readFileSync(setup.output, 'utf8').trim().slice(5));
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(setup.directory, 'replacements.json'), 'utf8')),
    replacements);
  assert.deepEqual(replacements.map(({ family }) => family), ['npm', 'pub', 'gradle', 'flutter-sdk', 'ndk']);
  for (const { family, key, prefix } of replacements) {
    const name = family === 'flutter-sdk' ? 'FLUTTER' : family.toUpperCase();
    assert.equal(key, env[`${name}_KEY`]);
    assert.equal(prefix, env[`${name}_PREFIX`]);
  }
});

test('NDK identity exposes its exact replacement without installing SDK packages', (context) => {
  const setup = fixture(context);
  const result = childProcess.spawnSync('bash', ['-euo', 'pipefail', '-c', runBlock(
    '.github/actions/setup-android-ndk/action.yml', 'Validate cache writer and locate Android SDK',
  )], {
    cwd: setup.directory, encoding: 'utf8', timeout: 5000,
    env: { ...process.env, BASH_ENV: '', SAVE_CACHE: 'true', CURRENT_REF: 'refs/heads/main',
      CURRENT_EVENT: 'push', CURRENT_WORKFLOW: 'Dependency cache warmup',
      CACHE_KEY: 'native-ndk-key', CACHE_PREFIX: 'native-ndk-',
      ANDROID_SDK_ROOT: setup.directory, GITHUB_OUTPUT: setup.output },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(setup.output, 'utf8'),
    `sdk-root=${setup.directory}\nkey=native-ndk-key\nprefix=native-ndk-\n`);
});
