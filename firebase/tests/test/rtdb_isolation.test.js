// Production hardening — Phase 5 (Security Regression), RTDB half.
//
// Confirms the existing authorizedSchools-gated RTDB location rule (not
// modified by this hardening pass, but must not have regressed) still
// denies a School-A driver reading/writing School-B's live location node,
// and that a driver cannot hijack another driver's location claim on the
// same trip.
'use strict';

const test = require('node:test');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeTestEnv, seedRtdb } = require('./helpers');
const { ref, set, get } = require('firebase/database');

const SCHOOL_A = 'school-a';
const SCHOOL_B = 'school-b';
const DRIVER_A = 'driver-a';
const DRIVER_B = 'driver-b';

let testEnv;

test.before(async () => {
  testEnv = await makeTestEnv();
  await seedRtdb(testEnv, async (db) => {
    await set(ref(db, `authorizedSchools/${DRIVER_A}/${SCHOOL_A}`), true);
    await set(ref(db, `authorizedSchools/${DRIVER_B}/${SCHOOL_B}`), true);
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test('rtdb_isolation: a driver authorized only for School A cannot write School B live location', async () => {
  const asDriverA = testEnv.authenticatedContext(DRIVER_A).database();
  await assertFails(
    set(ref(asDriverA, `schools/${SCHOOL_B}/trips/trip-1/location`), {
      latitude: 30,
      longitude: 31,
      driverId: DRIVER_A,
      timestamp: Date.now(),
    }),
  );
});

test('rtdb_isolation: a driver authorized only for School A cannot read School B live location', async () => {
  await seedRtdb(testEnv, async (db) => {
    await set(ref(db, `schools/${SCHOOL_B}/trips/trip-1/location`), {
      latitude: 30,
      longitude: 31,
      driverId: DRIVER_B,
      timestamp: Date.now(),
    });
  });
  const asDriverA = testEnv.authenticatedContext(DRIVER_A).database();
  await assertFails(get(ref(asDriverA, `schools/${SCHOOL_B}/trips/trip-1/location`)));
});

test('rtdb_isolation: a driver CAN write their own school\'s live location', async () => {
  const asDriverA = testEnv.authenticatedContext(DRIVER_A).database();
  await assertSucceeds(
    set(ref(asDriverA, `schools/${SCHOOL_A}/trips/trip-a/location`), {
      latitude: 30,
      longitude: 31,
      driverId: DRIVER_A,
      timestamp: Date.now(),
    }),
  );
});

test('rtdb_isolation: driver B cannot overwrite driver A\'s location claim on the same trip', async () => {
  const asDriverB = testEnv.authenticatedContext(DRIVER_B).database();
  await seedRtdb(testEnv, async (db) => {
    await set(ref(db, `authorizedSchools/${DRIVER_B}/${SCHOOL_A}`), true);
  });
  await assertFails(
    set(ref(asDriverB, `schools/${SCHOOL_A}/trips/trip-a/location`), {
      latitude: 1,
      longitude: 1,
      driverId: DRIVER_B,
      timestamp: Date.now(),
    }),
  );
});
