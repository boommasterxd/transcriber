'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { jvmFixture } = require('./jvm_fixture.cjs');

const fixture = (context) => jvmFixture(context, 'transcriber-native-coverage-');

function run(setup) {
  return childProcess.spawnSync(path.join(setup.repository, 'android/gradlew'), [
    '-p', setup.project, 'test', 'verifyNativeCoverage', '--offline', '--no-daemon', '--console=plain',
  ], { encoding: 'utf8', timeout: 180000, maxBuffer: 1024 * 1024 });
}

test('native coverage fails closed for missing sources, counters, reports and execution data',
  { timeout: 900000 }, (context) => {
    const setup = fixture(context);
    const script = path.join(setup.project, 'build.gradle.kts');
    const original = fs.readFileSync(script, 'utf8');
    const complete = run(setup);
    assert.equal(complete.status, 0, `${complete.stdout}\n${complete.stderr}`);
    for (const [mutation, expected] of [
      ['report.writeText(report.readText().replace("PcmLevelMeter.kt", "Missing.kt"))', /inventory mismatch/],
      ['report.writeText(report.readText().replace(Regex("covered=\\"[0-9]+\\""), "covered=\\"0\\""))', /no measured executable lines|below 85%/],
      ['report.delete()', /XML is missing/],
      ['file("build/jacoco/test.exec").delete()', /execution data is missing/],
    ]) {
      fs.writeFileSync(script, `${original}
tasks.named("nativeCoverageReport") {
    outputs.upToDateWhen { false }
    doLast {
        val report = file("build/reports/jacoco/nativeCoverageReport/nativeCoverageReport.xml")
        ${mutation}
    }
}
`);
      const result = run(setup);
      assert.notEqual(result.status, 0, `Mutation unexpectedly passed: ${mutation}`);
      assert.match(`${result.stdout}\n${result.stderr}`, expected);
    }
  });
