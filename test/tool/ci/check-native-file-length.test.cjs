'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { checkNativeFileLengths, countLines } = require('../../../tool/ci/check-native-file-length.cjs');

function fixture(context) {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'native-file-length-'));
  context.after(() => fs.rmSync(cwd, { recursive: true, force: true }));
  childProcess.execFileSync('git', ['init', '-q'], { cwd });
  return cwd;
}

test('line counting matches empty, unterminated, LF, CRLF and CR source lines', () => {
  for (const [source, expected] of [['', 0], ['line', 1], ['line\n', 1],
    ['a\r\nb\r\n', 2], ['a\rb', 2], ['\n', 1], ['\n\n', 2]]) {
    assert.equal(countLines(source), expected);
  }
});

test('the native gate covers tracked and untracked Kotlin, Gradle and shell files', (context) => {
  const cwd = fixture(context);
  assert.deepEqual(checkNativeFileLengths(cwd), []);
  fs.writeFileSync(path.join(cwd, 'tracked.kt'), 'line\n'.repeat(500));
  childProcess.execFileSync('git', ['add', '.'], { cwd });
  fs.writeFileSync(path.join(cwd, 'build.gradle.kts'), 'line\r\n'.repeat(501));
  fs.writeFileSync(path.join(cwd, 'script "quoted"\nname.sh'), 'line\n'.repeat(501));
  fs.writeFileSync(path.join(cwd, 'outside.dart'), 'line\n'.repeat(501));
  assert.deepEqual(checkNativeFileLengths(cwd), [
    'build.gradle.kts has 501 lines (limit 500).',
    'script "quoted"\nname.sh has 501 lines (limit 500).',
  ]);
  fs.rmSync(path.join(cwd, 'tracked.kt'));
  assert.equal(checkNativeFileLengths(cwd).length, 2);
});

test('Git errors and incomplete output fail closed', (context) => {
  for (const output of [new Error('unavailable'), 'incomplete.kt']) {
    const mock = context.mock.method(childProcess, 'execFileSync', () => {
      if (output instanceof Error) throw output;
      return output;
    });
    assert.throws(() => checkNativeFileLengths());
    mock.mock.restore();
  }
});

test('CLI rejects an over-limit file and unavailable source enumeration', (context) => {
  const cwd = fixture(context);
  const script = path.join(__dirname, '../../../tool/ci/check-native-file-length.cjs');
  const run = () => childProcess.spawnSync(process.execPath, [script], {
    cwd, encoding: 'utf8', timeout: 5000,
  });
  assert.equal(run().status, 0);
  fs.writeFileSync(path.join(cwd, 'oversized.kt'), 'line\n'.repeat(501));
  const oversized = run();
  assert.equal(oversized.status, 1);
  assert.match(oversized.stderr, /oversized.kt has 501 lines/);
  fs.rmSync(path.join(cwd, '.git'), { recursive: true });
  const unavailable = run();
  assert.equal(unavailable.status, 1);
  assert.match(unavailable.stderr, /Cannot reliably check/);
});
