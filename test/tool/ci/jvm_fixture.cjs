'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const childProcess = require('node:child_process');
const { after } = require('node:test');

let session;

function gradleSession() {
  if (session) return session;
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'transcriber-jvm-session-'));
  const dependencies = process.env.GRADLE_USER_HOME ?? path.join(os.homedir(), '.gradle');
  for (const name of ['caches', 'wrapper']) {
    const source = path.join(dependencies, name);
    if (fs.existsSync(source)) fs.symlinkSync(source, path.join(home, name), 'dir');
  }
  session = { ...process.env, GRADLE_USER_HOME: home,
    ANDROID_HOME: '/missing-android-sdk', ANDROID_SDK_ROOT: '/missing-android-sdk' };
  return session;
}

function daemonPids() {
  const root = path.join(session.GRADLE_USER_HOME, 'daemon');
  if (!fs.existsSync(root)) return [];
  return fs.readdirSync(root, { withFileTypes: true }).filter((entry) => entry.isDirectory())
    .flatMap((entry) => fs.readdirSync(path.join(root, entry.name)))
    .map((name) => /^daemon-([1-9][0-9]*)\.out\.log$/.exec(name))
    .filter(Boolean).map((match) => Number(match[1]));
}

async function waitForDaemonExit(pid) {
  const deadline = Date.now() + 10000;
  while (true) {
    try {
      process.kill(pid, 0);
    } catch (error) {
      if (error.code === 'ESRCH') return;
      throw error;
    }
    if (Date.now() >= deadline) throw new Error('The isolated Gradle daemon did not exit.');
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}

after(async () => {
  if (!session) return;
  try {
    const pids = daemonPids();
    const wrapper = path.resolve(__dirname, '../../../android/gradlew');
    const result = childProcess.spawnSync(wrapper, ['--stop'], {
      env: session, encoding: 'utf8', timeout: 30000, maxBuffer: 1024 * 1024,
    });
    if (result.status !== 0) throw new Error('The isolated Gradle daemon did not stop.');
    await Promise.all(pids.map(waitForDaemonExit));
  } finally {
    fs.rmSync(session.GRADLE_USER_HOME, { recursive: true, force: true });
  }
});

function runJvmFixture(setup, tasks, arguments_ = []) {
  return childProcess.spawnSync(path.join(setup.repository, 'android/gradlew'), [
    '-p', setup.project, ...tasks, '--offline', '--daemon',
    '-Dorg.gradle.daemon.idletimeout=60000', '--console=plain', ...arguments_,
  ], {
    env: gradleSession(), encoding: 'utf8', timeout: 180000, maxBuffer: 1024 * 1024,
  });
}

function jvmFixture(context, prefix) {
  const repository = path.resolve(__dirname, '../../..');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const project = path.join(root, 'tool/ci/jvm');
  fs.mkdirSync(path.dirname(project), { recursive: true });
  fs.cpSync(path.join(repository, 'tool/ci/jvm'), project, {
    recursive: true,
    filter: (file) => !file.split(path.sep).some((part) => ['build', '.gradle', '.kotlin'].includes(part)),
  });
  const classes = fs.readFileSync(path.join(project, 'sources.txt'), 'utf8').trim().split('\n');
  for (const name of classes) {
    for (const [directory, suffix] of [['main', '.kt'], ['test', 'Test.kt']]) {
      const relative = `android/app/src/${directory}/kotlin/${name.replaceAll('.', '/')}${suffix}`;
      const target = path.join(root, relative);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(path.join(repository, relative), target);
    }
  }
  return { repository, root, project, classes };
}

module.exports = { jvmFixture, runJvmFixture };
