'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

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

module.exports = { jvmFixture };
