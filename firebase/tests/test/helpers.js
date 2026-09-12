// Shared setup for every rules-emulator test in this directory. Never
// touches the real `sharlok-ef2b4` Firebase project — @firebase/rules-unit-
// testing's initializeTestEnvironment only ever opens a connection to the
// local emulator host/port given below; there is no code path here that
// can reach a live backend.
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'demo-jammam-rules-test';
const FIRESTORE_PORT = 8180;
const DATABASE_PORT = 9100;

async function makeTestEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', '..', 'firestore.rules'),
        'utf8',
      ),
      host: '127.0.0.1',
      port: FIRESTORE_PORT,
    },
    database: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', '..', 'database.rules.json'),
        'utf8',
      ),
      host: '127.0.0.1',
      port: DATABASE_PORT,
    },
  });
}

/// Seeds Firestore documents bypassing security rules entirely — the
/// emulator equivalent of the Admin SDK, used only to set up fixtures so
/// each test can start from known, realistic state before exercising the
/// rules as a specific authenticated user.
async function seed(testEnv, fn) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await fn(context.firestore());
  });
}

async function seedRtdb(testEnv, fn) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await fn(context.database());
  });
}

module.exports = { makeTestEnv, seed, seedRtdb, PROJECT_ID };
