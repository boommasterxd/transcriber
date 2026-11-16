'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const versions = ['28.0.13004108', '28.2.13676358'];
const script = path.resolve(__dirname, '../../../tool/ci/setup_android_ndk.sh');

function fixture(context) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-ndk-'));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const sdk = path.join(root, 'sdk');
  const manager = path.join(sdk, 'cmdline-tools/latest/bin/sdkmanager');
  const bin = path.join(root, 'bin');
  fs.mkdirSync(path.dirname(manager), { recursive: true });
  fs.mkdirSync(bin);
  fs.writeFileSync(manager, `#!/usr/bin/env bash
set -euo pipefail
sdk=\${ANDROID_SDK_ROOT:-$ANDROID_HOME}
[[ "$1" == "--sdk_root=$sdk" ]]
version=\${2#ndk;}
printf '%s\\n' "$version" >> "$MOCK_LOG"
if [[ "\${MOCK_FAILURE:-}" == true ]]; then exit 42; fi
marker="$MOCK_LOG.failed-$version"
if [[ "\${MOCK_RETRY_ONCE:-}" == true && ! -f "$marker" ]]; then
  touch "$marker"
  mkdir -p "$sdk/ndk/$version"
  touch "$sdk/ndk/$version/partial"
  exit 42
fi
mkdir -p "$sdk/ndk/$version"
revision=$version
if [[ "\${MOCK_INVALID:-}" == true ]]; then revision=0.0.0; fi
printf 'Pkg.Revision = %s\\n' "$revision" > "$sdk/ndk/$version/source.properties"
`, { mode: 0o755 });
  fs.writeFileSync(path.join(bin, 'sleep'), '#!/usr/bin/env bash\nprintf \'%s\\n\' "$1" >> "$MOCK_SLEEP_LOG"\n', { mode: 0o755 });
  return { root, sdk, manager, env: {
    ...process.env, ANDROID_SDK_ROOT: sdk, ANDROID_HOME: sdk,
    PATH: `${bin}:${process.env.PATH}`, MOCK_LOG: path.join(root, 'install.log'),
    MOCK_SLEEP_LOG: path.join(root, 'sleep.log'),
  } };
}

function install(setup, version, revision = version) {
  const directory = path.join(setup.sdk, 'ndk', version);
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, 'source.properties'), `Pkg.Revision = ${revision}\r\n`);
  fs.writeFileSync(path.join(directory, 'keep'), 'existing installation');
  return directory;
}

function run(setup, overrides = {}) {
  return childProcess.spawnSync('bash', [script], {
    env: { ...setup.env, ...overrides }, encoding: 'utf8', timeout: 10000,
  });
}

function lines(file) {
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf8').trim().split('\n') : [];
}

test('cold setup installs and validates both pinned NDK versions', (context) => {
  const setup = fixture(context);
  const result = run(setup);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(lines(setup.env.MOCK_LOG), versions);
  for (const version of versions) {
    assert.equal(fs.readFileSync(path.join(setup.sdk, 'ndk', version, 'source.properties'), 'utf8'),
      `Pkg.Revision = ${version}\n`);
  }
});

test('warm setup preserves validated installations and does not require sdkmanager', (context) => {
  const setup = fixture(context);
  const directories = versions.map((version) => install(setup, version));
  fs.rmSync(setup.manager);
  const result = run(setup);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(lines(setup.env.MOCK_LOG), []);
  for (const directory of directories) {
    assert.equal(fs.readFileSync(path.join(directory, 'keep'), 'utf8'), 'existing installation');
  }
});

test('partial cache restores replace only the invalid installation', (context) => {
  const setup = fixture(context);
  const preserved = install(setup, versions[0]);
  const replaced = install(setup, versions[1], '28.2.0');
  const result = run(setup);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(lines(setup.env.MOCK_LOG), [versions[1]]);
  assert.equal(fs.existsSync(path.join(preserved, 'keep')), true);
  assert.equal(fs.existsSync(path.join(replaced, 'keep')), false);
});

test('transient install failure clears partial files and recovers with bounded retry', (context) => {
  const setup = fixture(context);
  install(setup, versions[1]);
  const result = run(setup, { MOCK_RETRY_ONCE: 'true' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(lines(setup.env.MOCK_LOG), [versions[0], versions[0]]);
  assert.deepEqual(lines(setup.env.MOCK_SLEEP_LOG), ['5']);
  assert.equal(fs.existsSync(path.join(setup.sdk, 'ndk', versions[0], 'partial')), false);
});

test('persistent installation failure preserves its exit status and stops after four attempts', (context) => {
  const setup = fixture(context);
  const result = run(setup, { MOCK_FAILURE: 'true' });
  assert.equal(result.status, 42);
  assert.deepEqual(lines(setup.env.MOCK_LOG), Array(4).fill(versions[0]));
  assert.deepEqual(lines(setup.env.MOCK_SLEEP_LOG), ['5', '10', '15']);
  assert.match(result.stderr, /could not be installed and validated/);
});

test('sdkmanager success without the requested revision is rejected', (context) => {
  const setup = fixture(context);
  const result = run(setup, { MOCK_INVALID: 'true' });
  assert.equal(result.status, 1);
  assert.deepEqual(lines(setup.env.MOCK_LOG), Array(4).fill(versions[0]));
  assert.match(result.stderr, /could not be installed and validated/);
});

test('ANDROID_HOME fallback and versioned command-line tools remain supported', (context) => {
  const setup = fixture(context);
  const versioned = path.join(setup.sdk, 'cmdline-tools/19.0/bin/sdkmanager');
  fs.mkdirSync(path.dirname(versioned), { recursive: true });
  fs.renameSync(setup.manager, versioned);
  versions.forEach((version) => install(setup, version));
  assert.equal(run(setup, { ANDROID_SDK_ROOT: '' }).status, 0);
  fs.rmSync(path.join(setup.sdk, 'ndk', versions[0]), { recursive: true });
  const result = run(setup, { ANDROID_SDK_ROOT: '' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(lines(setup.env.MOCK_LOG), [versions[0]]);
});

test('missing SDK and missing sdkmanager fail before starting downloads', (context) => {
  const setup = fixture(context);
  const invalidRoot = run(setup, { ANDROID_SDK_ROOT: 'relative-sdk' });
  assert.equal(invalidRoot.status, 1);
  assert.match(invalidRoot.stderr, /existing absolute Android SDK root/);
  fs.rmSync(path.join(setup.sdk, 'cmdline-tools'), { recursive: true });
  const missing = run(setup);
  assert.equal(missing.status, 1);
  assert.match(missing.stderr, /sdkmanager is unavailable/);
  assert.deepEqual(lines(setup.env.MOCK_LOG), []);
});
