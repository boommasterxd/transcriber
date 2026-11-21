'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

function fixture(context) {
  const repository = path.resolve(__dirname, '../../..');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-kotlin-quality-'));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  childProcess.execFileSync('git', ['init', '-q'], { cwd: root });
  fs.mkdirSync(path.join(root, 'config'));
  fs.copyFileSync(path.join(repository, 'config/detekt.yml'), path.join(root, 'config/detekt.yml'));
  return { root, script: path.join(repository, 'tool/quality/check_kotlin_quality.sh') };
}

function run(setup) {
  return childProcess.spawnSync('bash', [setup.script], {
    cwd: setup.root, encoding: 'utf8', timeout: 120000, maxBuffer: 1024 * 1024,
  });
}

test('the real Kotlin gate checks tests and Gradle scripts and fails closed',
  { timeout: 300000 }, (context) => {
    const setup = fixture(context);
    const empty = run(setup);
    assert.notEqual(empty.status, 0);
    assert.match(empty.stderr, /No maintained Kotlin sources/);
    const sources = ['android/app/src/test/kotlin/QualityTest.kt',
      'android/app/src/androidTest/kotlin/DeviceQualityTest.kt', 'build.gradle.kts'];
    for (const source of sources) {
      const file = path.join(setup.root, source);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, 'fun accepted(value: String): String = value\n');
    }
    childProcess.execFileSync('git', ['add', sources[0]], { cwd: setup.root });
    const accepted = run(setup);
    assert.equal(accepted.status, 0, `${accepted.stdout}\n${accepted.stderr}`);
    for (const source of sources) {
      fs.writeFileSync(path.join(setup.root, source), `fun rejected(
    first: String,
    second: String,
    third: String,
    fourth: String,
    fifth: String,
    sixth: String,
    seventh: String,
): String = first + second + third + fourth + fifth + sixth + seventh
`);
    }
    const rejected = run(setup);
    assert.equal(rejected.status, 2, `${rejected.stdout}\n${rejected.stderr}`);
    for (const source of sources) {
      const diagnostic = rejected.stdout.split('\n').find((line) => line.includes(`${source}:`));
      assert.match(diagnostic ?? '', /\[LongParameterList\]/);
    }
    fs.rmSync(path.join(setup.root, '.git'), { recursive: true });
    const unavailable = run(setup);
    assert.notEqual(unavailable.status, 0);
    assert.match(unavailable.stderr, /not a git repository/);
  });
