'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { jvmFixture, runJvmFixture } = require('./jvm_fixture.cjs');

const fixture = (context) => jvmFixture(context, 'transcriber-jvm-regression-');

const runJvm = (setup) => runJvmFixture(setup, ['test']);

function ignoreTestClass(root, name) {
  const source = name.replaceAll('.', '/');
  const target = path.join(root, `android/app/src/test/kotlin/${source}Test.kt`);
  const className = `${name.split('.').at(-1)}Test`;
  const original = fs.readFileSync(target, 'utf8');
  const ignored = original.replace(`class ${className} {`, `@org.junit.Ignore\nclass ${className} {`);
  assert.notEqual(ignored, original, 'The actual test class must receive an ignore annotation.');
  fs.writeFileSync(target, ignored);
}

test('the independent JVM suite detects a real WAV header regression', { timeout: 240000 }, (context) => {
  const { repository, root, project } = fixture(context);
  const writer = path.join(root, 'android/app/src/main/kotlin/com/transcriber/app/BoundedWaveWriter.kt');
  const original = fs.readFileSync(writer, 'utf8');
  const broken = original.replace('put("RIFF".toByteArray', 'put("FAIL".toByteArray');
  assert.notEqual(broken, original, 'The injected defect must modify the actual production implementation.');
  fs.writeFileSync(writer, broken);
  const result = runJvm({ repository, project });
  assert.notEqual(result.status, 0, result.stdout);
  const report = path.join(project, 'build/test-results/test/TEST-com.transcriber.app.BoundedWaveWriterTest.xml');
  assert.ok(fs.existsSync(report), `${result.stdout}\n${result.stderr}`);
  const xml = fs.readFileSync(report, 'utf8');
  assert.match(xml, /name="exactAndOversizedChunksNeverExceedTheCapAndFinalizeValidPcmHeaders"/);
  assert.match(xml, /<failure /);
});

test('each configured JVM test class must execute an unskipped test', { timeout: 240000 }, (context) => {
  const setup = fixture(context);
  ignoreTestClass(setup.root, setup.classes[0]);
  const result = runJvm(setup);
  assert.notEqual(result.status, 0);
  assert.match(`${result.stdout}\n${result.stderr}`, /Every maintained test class must execute tests/);
});
