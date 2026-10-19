'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

function fixture(context) {
  const repository = path.resolve(__dirname, '../../..');
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-jvm-regression-'));
  context.after(() => fs.rmSync(fixture, { recursive: true, force: true }));
  const project = path.join(fixture, 'tool/ci/jvm');
  fs.mkdirSync(path.dirname(project), { recursive: true });
  fs.cpSync(path.join(repository, 'tool/ci/jvm'), project, {
    recursive: true,
    filter: (file) => !file.split(path.sep).some((part) => ['build', '.gradle', '.kotlin'].includes(part)),
  });
  const classes = fs.readFileSync(path.join(project, 'sources.txt'), 'utf8').trim().split('\n');
  for (const name of classes) {
    const source = name.replaceAll('.', '/');
    for (const [directory, suffix] of [['main', '.kt'], ['test', 'Test.kt']]) {
      const relative = `android/app/src/${directory}/kotlin/${source}${suffix}`;
      const target = path.join(fixture, relative);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(path.join(repository, relative), target);
    }
  }
  return { repository, root: fixture, project, classes };
}

function runJvm({ repository, project }) {
  return childProcess.spawnSync(path.join(repository, 'android/gradlew'), [
    '-p', project, 'test', '--offline', '--no-daemon', '--console=plain',
  ], {
    encoding: 'utf8', timeout: 180000, maxBuffer: 1024 * 1024,
    env: { ...process.env, ANDROID_HOME: '/missing-android-sdk', ANDROID_SDK_ROOT: '/missing-android-sdk' },
  });
}

function ignoreTestClass(root, name) {
  const source = name.replaceAll('.', '/');
  const target = path.join(root, `android/app/src/test/kotlin/${source}Test.kt`);
  const className = `${name.split('.').at(-1)}Test`;
  const original = fs.readFileSync(target, 'utf8');
  const ignored = original.replace(`class ${className} {`, `@org.junit.Ignore\nclass ${className} {`);
  assert.notEqual(ignored, original, 'The actual test class must receive an ignore annotation.');
  fs.writeFileSync(target, ignored);
}

test('the independent JVM suite detects a real PCM production regression', { timeout: 240000 }, (context) => {
  const { repository, root, project } = fixture(context);
  const pcm = path.join(root, 'android/app/src/main/kotlin/com/transcriber/app/PcmLevelMeter.kt');
  const original = fs.readFileSync(pcm, 'utf8');
  const broken = original.replace('private const val minimumLevel = 0.05', 'private const val minimumLevel = 0.5');
  assert.notEqual(broken, original, 'The injected defect must modify the actual production implementation.');
  fs.writeFileSync(pcm, broken);
  const result = runJvm({ repository, project });
  assert.notEqual(result.status, 0, result.stdout);
  const report = path.join(project, 'build/test-results/test/TEST-com.transcriber.app.PcmLevelMeterTest.xml');
  assert.ok(fs.existsSync(report), `${result.stdout}\n${result.stderr}`);
  const xml = fs.readFileSync(report, 'utf8');
  assert.match(xml, /name="silenceUsesVisibleMinimumLevel"/);
  assert.match(xml, /<failure /);
});

test('entirely ignored JVM tests cannot report success', { timeout: 240000 }, (context) => {
  const setup = fixture(context);
  for (const name of setup.classes) ignoreTestClass(setup.root, name);
  const result = runJvm(setup);
  assert.notEqual(result.status, 0);
  assert.match(`${result.stdout}\n${result.stderr}`, /zero or entirely skipped tests cannot pass/);
});

test('each configured JVM test class must execute an unskipped test', { timeout: 240000 }, (context) => {
  const setup = fixture(context);
  ignoreTestClass(setup.root, setup.classes[0]);
  const result = runJvm(setup);
  assert.notEqual(result.status, 0);
  assert.match(`${result.stdout}\n${result.stderr}`, /Every maintained test class must execute tests/);
});

for (const ignored of [false, true]) {
  test(`Android-style source discovery checks tests outside the JVM manifest: ignored=${ignored}`,
    { timeout: 240000 }, (context) => {
      const setup = fixture(context);
      const source = path.join(setup.root,
        'android/app/src/test/kotlin/com/transcriber/app/AdditionalTest.kt');
      fs.writeFileSync(source, `package com.transcriber.app
${ignored ? '@org.junit.Ignore' : ''}
class AdditionalTest {
    @org.junit.Test
    fun newSessionRejectsMissingIdentity() {
        org.junit.Assert.assertFalse(EditorSessionGate().accepts(null))
    }
}
`);
      const script = path.join(setup.project, 'build.gradle.kts');
      const original = fs.readFileSync(script, 'utf8');
      const discovery = `kotlin.sourceSets.named("test") {
    kotlin.setIncludes(listOf("**/*Test.kt"))
}
tasks.test { filter.setIncludePatterns("*") }
extra["requiredTestSourceFiles"] = fileTree(repositoryRoot.dir("android/app/src/test/kotlin").asFile) {
    include("**/*Test.kt")
}.files
apply(from = "require_executed_tests.gradle.kts")`;
      const changed = original.replace('apply(from = "require_executed_tests.gradle.kts")', discovery);
      assert.notEqual(changed, original, 'The fixture must use Android-style maintained test discovery.');
      fs.writeFileSync(script, changed);
      const result = runJvm(setup);
      if (ignored) {
        assert.notEqual(result.status, 0);
        assert.match(`${result.stdout}\n${result.stderr}`,
          /Every maintained test class must execute tests: com\.transcriber\.app\.AdditionalTest/);
      } else {
        assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
      }
    });
}
