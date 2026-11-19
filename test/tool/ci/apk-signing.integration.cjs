'use strict';

const assert = require('node:assert/strict');
const { execFileSync, spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const scripts = path.resolve(__dirname, '../../../tool/package');
const fixturePassword = 'synthetic-fixture-password';
const commandOptions = { stdio: ['ignore', 'pipe', 'pipe'], timeout: 20000 };

function createKey(root, alias) {
  const store = path.join(root, `${alias}.p12`);
  const storeArgs = ['-alias', alias, '-keystore', store, '-storepass', fixturePassword];
  execFileSync('keytool', [
    '-genkeypair', '-noprompt', '-storetype', 'PKCS12', '-keyalg', 'RSA', '-keysize', '2048',
    '-validity', '365', '-dname', `CN=${alias}`, ...storeArgs,
  ], commandOptions);
  const certificate = execFileSync('keytool', ['-exportcert', ...storeArgs], commandOptions);
  return {
    alias,
    base64: fs.readFileSync(store).toString('base64'),
    fingerprint: createHash('sha256').update(certificate).digest('hex'),
  };
}

function createUnsignedApk(root, buildTools, androidJar) {
  const manifest = path.join(root, 'AndroidManifest.xml');
  const apk = path.join(root, 'unsigned.apk');
  fs.writeFileSync(manifest, `
    <manifest xmlns:android="http://schemas.android.com/apk/res/android"
        package="com.transcriber.app" android:versionCode="1001" android:versionName="2.0.0">
      <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="36" />
      <application />
    </manifest>
  `);
  execFileSync(path.join(buildTools, 'aapt'),
    ['package', '-f', '-M', manifest, '-I', androidJar, '-F', apk], commandOptions);
  return apk;
}

function runSigning(buildTools, args, key) {
  return spawnSync('bash', [path.join(scripts, 'sign_release_apk.sh'), ...args], {
    ...commandOptions,
    encoding: 'utf8',
    env: {
      ...process.env,
      ANDROID_BUILD_TOOLS: buildTools,
      RELEASE_KEY_ALIAS: key.alias,
      RELEASE_KEY_PASSWORD: fixturePassword,
      RELEASE_KEYSTORE_BASE64: key.base64,
      RELEASE_KEYSTORE_PASSWORD: fixturePassword,
    },
  });
}

test('release packaging requires the established signer and an unsigned Android APK', (t) => {
  const buildTools = process.env.ANDROID_BUILD_TOOLS;
  const sdk = process.env.ANDROID_HOME;
  assert.ok(buildTools && sdk, 'set ANDROID_HOME and ANDROID_BUILD_TOOLS to the Android SDK');
  const androidJar = path.join(sdk, 'platforms/android-36/android.jar');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-sign-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));

  const expected = createKey(root, 'established');
  const wrong = createKey(root, 'replacement');
  const apk = createUnsignedApk(root, buildTools, androidJar);
  const correctDirectory = path.join(root, 'verified');
  const wrongDirectory = path.join(root, 'rejected');
  const correct = runSigning(buildTools, ['2.0.0', apk, correctDirectory, expected.fingerprint], expected);
  assert.equal(correct.status, 0, correct.stderr);
  const verified = spawnSync('bash', [path.join(scripts, 'verify_release_assets.sh'), '2.0.0', correctDirectory],
    { ...commandOptions, encoding: 'utf8' });
  assert.equal(verified.status, 0, verified.stderr);

  const invalid = runSigning(buildTools, ['2.0.0', apk, wrongDirectory, expected.fingerprint], wrong);
  assert.equal(invalid.status, 1);
  assert.match(invalid.stderr, /does not match the established release certificate/);
  assert.equal(fs.existsSync(path.join(wrongDirectory, 'SHA256SUMS')), false);

  const alreadySigned = path.join(correctDirectory, 'transcriber-2.0.0-android.apk');
  const replay = runSigning(buildTools, ['2.0.0', alreadySigned, path.join(root, 'replay'), expected.fingerprint], expected);
  assert.equal(replay.status, 1);
  assert.match(replay.stderr, /Expected an unsigned Android APK/);
});
