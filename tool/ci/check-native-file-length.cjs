'use strict';

const childProcess = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const FILE_LENGTH_LIMIT = 500;

function countLines(source) {
  if (source.length === 0) return 0;
  const lines = source.split(/\r\n|\n|\r/).length;
  return lines - (/[\r\n]$/.test(source) ? 1 : 0);
}

/** Preserve the complete non-Dart file-size gate without installing Dart. */
function checkNativeFileLengths(cwd = process.cwd()) {
  const output = childProcess.execFileSync('git', [
    'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', '*.kt', '*.kts', '*.sh',
  ], { cwd, encoding: 'utf8', timeout: 5000, maxBuffer: 256 * 1024, stdio: ['ignore', 'pipe', 'pipe'] });
  if (output && !output.endsWith('\0')) throw new Error('Incomplete native source file list.');
  const files = output ? output.slice(0, -1).split('\0') : [];
  const violations = [];
  for (const file of new Set(files)) {
    const absolute = path.join(cwd, file);
    if (!fs.existsSync(absolute)) continue;
    const lines = countLines(fs.readFileSync(absolute, 'utf8'));
    if (lines > FILE_LENGTH_LIMIT) {
      violations.push(`${file} has ${lines} lines (limit ${FILE_LENGTH_LIMIT}).`);
    }
  }
  return violations;
}

module.exports = { checkNativeFileLengths, countLines };

if (require.main === module) {
  try {
    const violations = checkNativeFileLengths();
    if (violations.length) {
      console.error(violations.join('\n'));
      process.exitCode = 1;
    } else {
      console.log('Native and shell source file lengths passed.');
    }
  } catch {
    console.error('Cannot reliably check native and shell source file lengths.');
    process.exitCode = 1;
  }
}
