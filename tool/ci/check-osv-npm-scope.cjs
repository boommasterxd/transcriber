'use strict';

const fs = require('node:fs');
const path = require('node:path');

function packageIdentity(location, entry) {
  const match = location.match(/(?:^|\/)node_modules\/((?:@[^/]+\/)?[^/]+)$/);
  if (!match || !entry || typeof entry !== 'object' || Array.isArray(entry)
    || typeof entry.version !== 'string' || !entry.version
    || (entry.name !== undefined && (typeof entry.name !== 'string' || !entry.name))) {
    throw new Error(`Invalid npm lockfile package: ${location}`);
  }
  for (const flag of ['dev', 'optional', 'devOptional', 'inBundle', 'link']) {
    if (entry[flag] !== undefined && typeof entry[flag] !== 'boolean') {
      throw new Error(`Invalid npm lockfile ${flag} flag: ${location}`);
    }
  }
  if (entry.link || /^(git(?:\+[^:]+)?|ssh|github|gitlab|bitbucket|file):|\.git(?:#|$)/i.test(entry.resolved ?? '')) {
    throw new Error(`OSV npm dev filtering requires review for linked or Git packages: ${location}`);
  }
  if (entry.devOptional) {
    throw new Error(`OSV npm dev filtering cannot safely classify devOptional: ${location}`);
  }
  return `${entry.name ?? match[1]}@${entry.version}`;
}

/** OSV v2.7.0 merges grouped production and dev packages, so reject ambiguity. */
function checkNpmScope(lockfile) {
  if (!lockfile || ![2, 3].includes(lockfile.lockfileVersion)
    || !lockfile.packages || typeof lockfile.packages !== 'object'
    || Array.isArray(lockfile.packages) || !lockfile.packages['']
    || typeof lockfile.packages[''] !== 'object' || Array.isArray(lockfile.packages[''])) {
    throw new Error('OSV npm dev filtering requires a valid npm v2/v3 packages lockfile.');
  }
  const groups = new Map();
  for (const [location, entry] of Object.entries(lockfile.packages)) {
    if (!location) continue;
    const identity = packageIdentity(location, entry);
    const state = groups.get(identity) ?? { dev: false, groupedProduction: false, regularProduction: false };
    state.dev ||= entry.dev === true;
    state.groupedProduction ||= entry.dev !== true && [entry.optional, entry.inBundle].includes(true);
    state.regularProduction ||= ![entry.dev, entry.optional, entry.inBundle].includes(true);
    groups.set(identity, state);
  }
  for (const [identity, state] of groups) {
    if (state.dev && state.groupedProduction && !state.regularProduction) {
      throw new Error(`OSV npm dev filtering cannot safely merge dev and grouped production packages: ${identity}`);
    }
  }
}

module.exports = { checkNpmScope };

if (require.main === module) {
  try {
    const lockPath = path.join(__dirname, '../quality/node/package-lock.json');
    checkNpmScope(JSON.parse(fs.readFileSync(lockPath, 'utf8')));
    console.log('OSV npm dev-group filtering preserves production dependencies.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
