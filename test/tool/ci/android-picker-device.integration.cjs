'use strict';

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const { mkdtempSync, rmSync, statSync, writeFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const test = require('node:test');
const { setTimeout: waitForNextRead } = require('node:timers/promises');

const app = 'com.transcriber.app';
const mainActivity = `${app}/.MainActivity`;
const audioName = `transcriber-picker-${randomUUID()}.wav`;
const deviceAudio = `/storage/emulated/0/Download/${audioName}`;
const dumpPath = '/data/local/tmp/transcriber-picker-fixture.xml';
const home = ['Choose an audio file', 'Audiodatei auswählen'];
const recovery = ['Audio selection recovered', 'Audioauswahl wiederhergestellt'];

function connectDevice() {
  const serial = process.env.ANDROID_SERIAL;
  const avd = process.env.TRANSCRIBER_TEST_AVD;
  assert.match(serial ?? '', /^emulator-\d+$/);
  assert.match(avd ?? '', /^(?:codex-)?transcriber-[a-z0-9-]+$/);
  const adb = (args, input) => execFileSync('adb', ['-s', serial, ...args], {
    encoding: 'utf8', input, timeout: 20_000, maxBuffer: 1024 * 1024,
  }).trim();
  assert.equal(adb(['shell', 'getprop ro.kernel.qemu']), '1');
  assert.equal(adb(['emu', 'avd', 'name']).split('\n')[0].trim(), avd);
  const shell = (command, input) => adb(['shell', '-T', command], input);
  return { adb, shell };
}

function clearFixtureApp(shell) {
  assert.equal(shell(`pm clear ${app}`), 'Success');
}

function installFixtureApp(adb, shell) {
  const apk = process.env.TRANSCRIBER_TEST_APK;
  assert.ok(apk && statSync(apk).isFile(), 'Expected a built debug APK');
  assert.match(adb(['install', '-r', apk]), /Success$/);
  shell(`run-as ${app} id`);
  clearFixtureApp(shell);
  shell(`run-as ${app} sh -c 'mkdir -p shared_prefs && cat > shared_prefs/FlutterSharedPreferences.xml'`, [
    '<?xml version="1.0" encoding="utf-8" standalone="yes"?>',
    '<map><string name="flutter.app_settings">{"onboarded":true,"language":"en","summarizeEnabled":false}</string></map>',
  ].join('\n'));
}

function silentWave() {
  const samples = 32_000;
  const data = Buffer.alloc(44 + samples);
  data.write('RIFF', 0);
  data.writeUInt32LE(36 + samples, 4);
  data.write('WAVEfmt ', 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20);
  data.writeUInt16LE(1, 22);
  data.writeUInt32LE(16_000, 24);
  data.writeUInt32LE(32_000, 28);
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write('data', 36);
  data.writeUInt32LE(samples, 40);
  return data;
}

function pushFixtureAudio(adb, shell, directory) {
  const source = join(directory, audioName);
  writeFileSync(source, silentWave());
  shell('mkdir -p /storage/emulated/0/Download');
  adb(['push', source, deviceAudio]);
  scanFixtureAudio(shell);
}

function scanFixtureAudio(shell) {
  shell(`content call --uri content://media --method scan_file --arg ${deviceAudio}`);
}

function readNodes(adb, shell) {
  try {
    const report = shell(`uiautomator dump ${dumpPath}`);
    if (!report.includes(dumpPath)) return [];
    const xml = adb(['exec-out', 'cat', dumpPath]);
    return Array.from(xml.matchAll(/<node\b[^>]+>/g), ([node]) => {
      const bounds = node.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
      const labels = Array.from(node.matchAll(/\b(?:text|content-desc)="([^"]+)"/g), (match) => match[1]);
      const resourceId = node.match(/\bresource-id="([^"]+)"/)?.[1];
      return { bounds, labels, resourceId };
    });
  } finally {
    shell(`rm -f ${dumpPath}`);
  }
}

function findNode(nodes, labels) {
  return nodes.find(({ bounds, labels: names }) => bounds && names.some((name) =>
    labels.some((label) => name.split('&#10;').includes(label) || name.startsWith(`${label}. `))));
}

async function awaitCondition(description, query) {
  const deadline = Date.now() + 25_000;
  while (Date.now() < deadline) {
    const result = query();
    if (result) return result;
    await waitForNextRead(150);
  }
  assert.fail(`Timed out waiting for ${description}`);
}

function tapNode(shell, node) {
  const [, left, top, right, bottom] = node.bounds.map(Number);
  assert.ok(right > left && bottom > top, 'Control has visible bounds');
  shell(`input tap ${Math.floor((left + right) / 2)} ${Math.floor((top + bottom) / 2)}`);
}

function processId(shell) {
  return shell(`pidof ${app} || true`);
}

function privateAudioFiles(shell) {
  return shell(`run-as ${app} sh -c 'if test -d cache/shared; then find cache/shared -type f; fi'`);
}

function downloadsRoot(nodes) {
  return findNode(nodes.filter(({ resourceId }) => resourceId === 'android:id/title'), ['Downloads']);
}

async function openDownloads(nodes, shell) {
  const picker = await awaitCondition('Android document picker', () => {
    const current = nodes();
    const file = findNode(current, [audioName]);
    const root = downloadsRoot(current);
    const menu = findNode(current, ['Show roots', 'Wurzeln anzeigen']);
    return file || root || menu ? { file, root, menu } : null;
  });
  if (picker.file) return;
  if (!picker.root) tapNode(shell, picker.menu);
  const root = picker.root ?? await awaitCondition('Downloads in the root drawer', () => downloadsRoot(nodes()));
  tapNode(shell, root);
  await awaitCondition('Downloads drawer closing', () => {
    const current = nodes();
    return !downloadsRoot(current) && findNode(current, ['Show roots', 'Wurzeln anzeigen']);
  });
}

async function recoverSelection(adb, shell) {
  const nodes = () => readNodes(adb, shell);
  const label = (labels) => awaitCondition(labels.join(' / '), () => findNode(nodes(), labels));
  shell(`am start -W -n ${mainActivity}`);
  tapNode(shell, await label(home));
  const originalPid = await awaitCondition('app PID before the picker returns', () => processId(shell));
  await openDownloads(nodes, shell);
  await label([audioName]);
  shell(`am kill ${app}`);
  await awaitCondition('background app process exit', () => processId(shell) === '');
  tapNode(shell, await label([audioName]));
  await label(recovery);
  assert.notEqual(processId(shell), originalPid, 'Android created a fresh app process');
  assert.ok(processId(shell), 'Android restarted the app');
  assert.equal(privateAudioFiles(shell).split('\n').filter(Boolean).length, 1, 'The picker imports one private copy');
  tapNode(shell, await label(['Cancel', 'Abbrechen']));
  await awaitCondition('home after cancellation', () => {
    const current = nodes();
    return findNode(current, home) && !findNode(current, recovery);
  });
  await awaitCondition('private copy removal', () => privateAudioFiles(shell) === '');
  shell(`test -s ${deviceAudio}`);
}

test('the Android picker delivers a selection after process recreation', { timeout: 180_000 }, async () => {
  const { adb, shell } = connectDevice();
  const airplaneMode = shell('settings get global airplane_mode_on');
  const wifi = shell('settings get global wifi_on');
  const directory = mkdtempSync(join(tmpdir(), 'transcriber-picker-device-'));
  let installed = false;
  try {
    shell('cmd connectivity airplane-mode enable');
    shell('svc wifi disable');
    assert.equal(shell('settings get global airplane_mode_on'), '1');
    installFixtureApp(adb, shell);
    installed = true;
    pushFixtureAudio(adb, shell, directory);
    await recoverSelection(adb, shell);
  } finally {
    rmSync(directory, { force: true, recursive: true });
    try {
      shell(`rm -f ${deviceAudio} ${dumpPath}`);
      scanFixtureAudio(shell);
      if (installed) clearFixtureApp(shell);
    } finally {
      if (airplaneMode !== '1') shell('cmd connectivity airplane-mode disable');
      if (wifi === '1') shell('svc wifi enable');
    }
  }
});
