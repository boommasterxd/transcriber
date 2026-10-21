'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const repository = path.resolve(__dirname, '../../..');
const quality = path.join(repository, 'tool/quality/node');

function lint(source, filename = 'tool/ci/quality_fixture.cjs') {
  return childProcess.spawnSync(process.execPath, [
    path.join(quality, 'node_modules/eslint/bin/eslint.js'),
    '--config', path.join(quality, 'eslint.config.js'), '--max-warnings', '0',
    '--stdin', '--stdin-filename', filename, '--format', 'json',
  ], { cwd: repository, input: source, encoding: 'utf8', timeout: 10000 });
}

test('the real ESLint CLI accepts supported CommonJS and ES module entrypoints', () => {
  for (const [source, filename] of [
    ["'use strict';\nmodule.exports = (value) => value;\n", 'tool/ci/quality_fixture.cjs'],
    ['export default (value) => value;\n', 'tool/ci/quality_fixture.mjs'],
  ]) {
    const result = lint(source, filename);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  }
});

const violations = [
  ['max-lines', 'module.exports = 1;\n' + '\n'.repeat(500)],
  ['max-lines-per-function', 'module.exports = function () {\n' + '\n'.repeat(100) + '};\n'],
  ['complexity', 'module.exports = (value) => {\n' +
    [...Array(20).keys()].map((index) => `  if (value === ${index}) return ${index};\n`).join('') +
    '};\n'],
  ['sonarjs/cognitive-complexity', 'module.exports = (value) => {\n' +
    '  if (value) {\n'.repeat(7) + '    return 1;\n' + '  }\n'.repeat(7) + '};\n'],
  ['max-params', 'module.exports = function (a, b, c, d, e, f, g) { return [a, b, c, d, e, f, g]; };\n'],
  ['max-depth', 'module.exports = (value) => {\n' +
    '  if (value) {\n'.repeat(5) + '    return 1;\n' + '  }\n'.repeat(5) + '};\n'],
  ['no-unused-vars', 'const unused = 1;\nmodule.exports = 1;\n'],
  ['@stylistic/quotes', 'module.exports = "double quotes";\n'],
  ['@stylistic/semi', 'module.exports = 1\n'],
];

for (const [rule, source] of violations) {
  test(`the real ESLint CLI blocks ${rule} violations`, () => {
    const result = lint(source);
    assert.equal(result.status, 1, result.stdout + result.stderr);
    const messages = JSON.parse(result.stdout).flatMap((file) => file.messages);
    assert.ok(messages.some((message) => message.ruleId === rule && message.severity === 2),
      `Expected a blocking ${rule} diagnostic: ${result.stdout}`);
  });
}

test('inline ESLint suppression cannot bypass the quality gate', () => {
  const result = lint('/* eslint-disable */\nconst unused = 1;\n');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  const messages = JSON.parse(result.stdout).flatMap((file) => file.messages);
  assert.ok(messages.some((message) => message.ruleId === 'no-unused-vars'));
});

test('the real duplication CLI rejects empty scope and repeated maintained JavaScript', (context) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'node-duplication-'));
  context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const source = [...Array(12).keys()].map((index) =>
    `console.log('distinct operation ${index}', process.cwd());\n`).join('');
  const scan = () => childProcess.spawnSync(path.join(quality, 'node_modules/.bin/jscpd'), [
    '--config', path.join(quality, 'jscpd.json'), '--fail-on-empty', directory,
  ], { cwd: repository, encoding: 'utf8', timeout: 10000 });
  const empty = scan();
  assert.equal(empty.status, 1, empty.stdout + empty.stderr);
  fs.writeFileSync(path.join(directory, 'first.cjs'), source);
  const clean = scan();
  assert.equal(clean.status, 0, clean.stdout + clean.stderr);
  fs.writeFileSync(path.join(directory, 'second.cjs'), source);
  const duplicated = scan();
  assert.equal(duplicated.status, 1, duplicated.stdout + duplicated.stderr);
  assert.match(duplicated.stdout + duplicated.stderr, /too many duplicates/);
});
