'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { runJvmFixture } = require('./jvm_fixture.cjs');

test('warmup resolves external artifacts across projects without building project outputs', (context) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-gradle-cache-'));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const repository = path.resolve(__dirname, '../../..');
  const artifact = path.join(root, 'repo/example/cache-fixture/1.0');
  fs.mkdirSync(artifact, { recursive: true });
  fs.writeFileSync(path.join(artifact, 'cache-fixture-1.0.pom'), `<project>
  <modelVersion>4.0.0</modelVersion><groupId>example</groupId>
  <artifactId>cache-fixture</artifactId><version>1.0</version>
</project>`);
  fs.writeFileSync(path.join(artifact, 'cache-fixture-1.0.jar'), 'synthetic artifact');
  fs.writeFileSync(path.join(root, 'settings.gradle'), "include 'plugin'\n");
  fs.writeFileSync(path.join(root, 'gradle.properties'), 'org.gradle.parallel=true\n');
  fs.mkdirSync(path.join(root, 'plugin'));
  fs.writeFileSync(path.join(root, 'plugin/build.gradle'), `
configurations { exported { canBeConsumed = true; canBeResolved = false } }
tasks.register('packagePlugin') {
    doLast { throw new GradleException('Warmup must not build project artifacts') }
}
artifacts { exported(file('build/plugin.jar')) { builtBy('packagePlugin') } }
configurations.create('releaseRuntimeClasspath')
dependencies.add('releaseRuntimeClasspath', 'example:cache-fixture:1.0')
`);
  fs.writeFileSync(path.join(root, 'build.gradle'), `
allprojects { repositories { maven { url = rootProject.file('repo').toURI() } } }
configurations { compileClasspath; debugRuntimeClasspath; robolectricSdk0; lintClassPath }
dependencies {
    compileClasspath project(path: ':plugin', configuration: 'exported')
    debugRuntimeClasspath 'example:cache-fixture:1.0'
    robolectricSdk0 'example:cache-fixture:1.0'
    lintClassPath 'example:cache-fixture:1.0'
}
if (providers.gradleProperty('missingDependency').isPresent()) {
    dependencies.add('debugRuntimeClasspath', 'example:missing:1.0')
}
`);
  const args = ['-I', path.join(repository, 'tool/ci/warm-gradle-cache.init.gradle')];
  const setup = { repository, project: root };
  const result = runJvmFixture(setup, ['warmDependencyCache'], args);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  for (const configuration of ['::compileClasspath', '::debugRuntimeClasspath',
    '::robolectricSdk0', '::lintClassPath', ':plugin:releaseRuntimeClasspath']) {
    assert.ok(result.stdout.includes(`Warming ${configuration}`), result.stdout);
  }
  assert.equal(fs.existsSync(path.join(root, 'plugin/build/plugin.jar')), false);
  const failed = runJvmFixture(setup, ['warmDependencyCache'], [...args, '-PmissingDependency=true']);
  assert.notEqual(failed.status, 0);
  assert.match(failed.stderr, /Could not find example:missing:1.0/);
});
