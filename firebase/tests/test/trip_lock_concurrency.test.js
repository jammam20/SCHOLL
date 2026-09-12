// Production hardening — Phase 4 (Concurrency) + Phase 2 (Bus Capacity)
// concurrency proof.
//
// These tests fire genuinely concurrent Firestore transactions (via
// Promise.all, exactly mirroring TripsRepository.createTrip / the driver
// app's markBoarded) against the *same* emulator, and assert that exactly
// one of each racing pair wins — never zero, never both. This is a real
// race, not a simulated one: both transactions are in flight at once and
// the emulator's own optimistic-concurrency retry logic is what decides
// the outcome, exactly as it will in production.
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { doc, setDoc, runTransaction, getDoc } = require('firebase/firestore');
const { makeTestEnv, seed } = require('./helpers');

const SCHOOL = 'school-lock';
const BUS = 'bus-1';
const DRIVER_A = 'driver-a';
const DRIVER_B = 'driver-b';

let testEnv;

test.before(async () => {
  testEnv = await makeTestEnv();
});

test.after(async () => {
  await testEnv.cleanup();
});

/** Mirrors TripsRepository.createTrip's lock-claim transaction exactly. */
async function tryCreateTrip(db, { tripId, busId, driverId }) {
  const tripRef = doc(db, `schools/${SCHOOL}/trips/${tripId}`);
  const busLockRef = doc(db, `schools/${SCHOOL}/activeTripLocks/bus_${busId}`);
  const driverLockRef = doc(db, `schools/${SCHOOL}/activeTripLocks/driver_${driverId}`);

  return runTransaction(db, async (transaction) => {
    const busLock = await transaction.get(busLockRef);
    if (busLock.exists()) throw new Error('bus already locked');
    const driverLock = await transaction.get(driverLockRef);
    if (driverLock.exists()) throw new Error('driver already locked');

    transaction.set(tripRef, {
      id: tripId,
      schoolId: SCHOOL,
      busId,
      driverId,
      status: 'scheduled',
    });
    transaction.set(busLockRef, { schoolId: SCHOOL, tripId, busId, driverId });
    transaction.set(driverLockRef, { schoolId: SCHOOL, tripId, busId, driverId });
  });
}

test('trip_lock_concurrency: two admins racing to book the SAME bus — exactly one wins', async () => {
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${SCHOOL}`), { id: SCHOOL, isActive: true });
    await setDoc(doc(db, `schools/${SCHOOL}/members/admin-1`), {
      uid: 'admin-1',
      schoolId: SCHOOL,
      role: 'admin',
      status: 'approved',
      isActive: true,
    });
  });
  const asAdmin = testEnv.authenticatedContext('admin-1').firestore();

  const attempts = await Promise.allSettled([
    tryCreateTrip(asAdmin, { tripId: 'race-trip-1', busId: BUS, driverId: DRIVER_A }),
    tryCreateTrip(asAdmin, { tripId: 'race-trip-2', busId: BUS, driverId: DRIVER_B }),
  ]);

  const succeeded = attempts.filter((r) => r.status === 'fulfilled');
  const failed = attempts.filter((r) => r.status === 'rejected');

  assert.equal(succeeded.length, 1, 'exactly one of the two concurrent bookings must win');
  assert.equal(failed.length, 1, 'the other must fail deterministically, not silently succeed');

  // No orphan/partial data: the losing attempt's trip document must not
  // exist at all — a partial write would be a real data-integrity bug.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const trip1 = await getDoc(doc(db, `schools/${SCHOOL}/trips/race-trip-1`));
    const trip2 = await getDoc(doc(db, `schools/${SCHOOL}/trips/race-trip-2`));
    const existing = [trip1, trip2].filter((d) => d.exists());
    assert.equal(existing.length, 1, 'exactly one trip document must exist, no partial writes');

    const busLock = await getDoc(doc(db, `schools/${SCHOOL}/activeTripLocks/bus_${BUS}`));
    assert.equal(busLock.exists(), true);
    assert.equal(busLock.data().tripId, existing[0].id);
  });
});

test('trip_lock_concurrency: two admins racing to book DIFFERENT buses both succeed (no false contention)', async () => {
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${SCHOOL}-2`), { id: `${SCHOOL}-2`, isActive: true });
    await setDoc(doc(db, `schools/${SCHOOL}-2/members/admin-2`), {
      uid: 'admin-2',
      schoolId: `${SCHOOL}-2`,
      role: 'admin',
      status: 'approved',
      isActive: true,
    });
  });
  const asAdmin = testEnv.authenticatedContext('admin-2').firestore();

  async function tryCreateTripFor(schoolSuffix, tripId, busId, driverId) {
    const school = `${SCHOOL}${schoolSuffix}`;
    const tripRef = doc(asAdmin, `schools/${school}/trips/${tripId}`);
    const busLockRef = doc(asAdmin, `schools/${school}/activeTripLocks/bus_${busId}`);
    const driverLockRef = doc(asAdmin, `schools/${school}/activeTripLocks/driver_${driverId}`);
    return runTransaction(asAdmin, async (transaction) => {
      const busLock = await transaction.get(busLockRef);
      if (busLock.exists()) throw new Error('bus already locked');
      const driverLock = await transaction.get(driverLockRef);
      if (driverLock.exists()) throw new Error('driver already locked');
      transaction.set(tripRef, { id: tripId, schoolId: school, busId, driverId, status: 'scheduled' });
      transaction.set(busLockRef, { schoolId: school, tripId, busId, driverId });
      transaction.set(driverLockRef, { schoolId: school, tripId, busId, driverId });
    });
  }

  const attempts = await Promise.allSettled([
    tryCreateTripFor('-2', 'trip-x', 'bus-x', 'driver-x'),
    tryCreateTripFor('-2', 'trip-y', 'bus-y', 'driver-y'),
  ]);

  assert.equal(
    attempts.filter((r) => r.status === 'fulfilled').length,
    2,
    'two genuinely independent bookings must never contend with each other',
  );
});

test('trip_lock_concurrency: releasing a lock (trip completed) frees the bus for a new trip', async () => {
  const school = `${SCHOOL}-3`;
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${school}`), { id: school, isActive: true });
    await setDoc(doc(db, `schools/${school}/members/admin-3`), {
      uid: 'admin-3',
      schoolId: school,
      role: 'admin',
      status: 'approved',
      isActive: true,
    });
    await setDoc(doc(db, `schools/${school}/trips/old-trip`), {
      id: 'old-trip',
      schoolId: school,
      busId: 'bus-z',
      driverId: 'driver-z',
      status: 'active',
    });
    await setDoc(doc(db, `schools/${school}/activeTripLocks/bus_bus-z`), {
      schoolId: school,
      tripId: 'old-trip',
      busId: 'bus-z',
      driverId: 'driver-z',
    });
  });
  const asAdmin = testEnv.authenticatedContext('admin-3').firestore();

  // Simulates the driver/admin completing the old trip and releasing its lock.
  await runTransaction(asAdmin, async (transaction) => {
    transaction.update(doc(asAdmin, `schools/${school}/trips/old-trip`), { status: 'completed' });
    transaction.delete(doc(asAdmin, `schools/${school}/activeTripLocks/bus_bus-z`));
  });

  const newTripRef = doc(asAdmin, `schools/${school}/trips/new-trip`);
  const newBusLockRef = doc(asAdmin, `schools/${school}/activeTripLocks/bus_bus-z`);
  await runTransaction(asAdmin, async (transaction) => {
    const lock = await transaction.get(newBusLockRef);
    if (lock.exists()) throw new Error('should be free');
    transaction.set(newTripRef, { id: 'new-trip', schoolId: school, busId: 'bus-z', driverId: 'driver-z', status: 'scheduled' });
    transaction.set(newBusLockRef, { schoolId: school, tripId: 'new-trip', busId: 'bus-z', driverId: 'driver-z' });
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const snap = await getDoc(doc(db, `schools/${school}/trips/new-trip`));
    assert.equal(snap.exists(), true, 'the new trip must have been created once the lock was freed');
  });
});
