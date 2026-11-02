'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { jvmFixture, runJvmFixture } = require('./jvm_fixture.cjs');

const fixture = (context) => jvmFixture(context, 'transcriber-native-coverage-');

const run = (setup, mutation) => runJvmFixture(setup, ['test', 'verifyNativeCoverage'],
  mutation ? [`-PfixtureCoverageMutation=${mutation}`] : []);

test('native coverage fails closed for missing sources, counters, reports and execution data',
  { timeout: 900000 }, (context) => {
    const setup = fixture(context);
    const script = path.join(setup.project, 'build.gradle.kts');
    const original = fs.readFileSync(script, 'utf8');
    fs.writeFileSync(script, `${original}
tasks.named("nativeCoverageReport") {
    outputs.upToDateWhen { false }
    doLast {
        val report = file("build/reports/jacoco/nativeCoverageReport/nativeCoverageReport.xml")
        when (providers.gradleProperty("fixtureCoverageMutation").orNull) {
            "sources" -> report.writeText(report.readText().replace("PcmLevelMeter.kt", "Missing.kt"))
            "counters" -> report.writeText(report.readText().replace(Regex("covered=\\"[0-9]+\\""), "covered=\\"0\\""))
            "report" -> report.delete()
            "execution" -> file("build/jacoco/test.exec").delete()
        }
    }
}
`);
    const complete = run(setup);
    assert.equal(complete.status, 0, `${complete.stdout}\n${complete.stderr}`);
    for (const [mutation, expected] of [
      ['sources', /inventory mismatch/],
      ['counters', /no measured executable lines|below 85%/],
      ['report', /XML is missing/],
      ['execution', /execution data is missing/],
    ]) {
      const result = run(setup, mutation);
      assert.notEqual(result.status, 0, `Mutation unexpectedly passed: ${mutation}`);
      assert.match(`${result.stdout}\n${result.stderr}`, expected);
    }
  });
