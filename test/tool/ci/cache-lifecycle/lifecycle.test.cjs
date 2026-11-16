'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { registerTests, registerTransportTests } = require('./register.cjs');
const { registerRecoveryTests } = require('./recovery.cjs');
const { registerIoTests } = require('./io.cjs');

const directory = path.resolve(__dirname, '../../../../tool/ci/cache-lifecycle');
registerTests(test, assert, directory);
registerTransportTests(test, assert, directory);
registerRecoveryTests(test, assert, directory);
registerIoTests(test, assert, directory);
