// Production hardening — Phase 2 (Bus Capacity) concurrency proof.
//
// Mirrors the driver app's StopOrderRepository.markBoarded transaction
// exactly (read trip, read bus capacity, compute onboard count, write if
// eligible) and fires two of them at the *same last open seat*
// concurrently — the exact scenario from the brief: "Capacity = 30,
// current passengers = 29, two simultaneous boarding requests arrive...
// must NOT allow both to succeed and create 31 passengers."
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { doc, setDoc, runTransaction } = require('firebase/firestore');
const { makeTestEnv, seed } = require('./helpers');

const SCHOOL = 'school-race';
const BUS = 'bus-1';
const DRIVER = 'driver-1';
const TRIP = 'trip-1';

let testEnv;

test.before(async () => {
  testEnv = await makeTestEnv();
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${SCHOOL}`), { id: SCHOOL, isActive: true });
    await setDoc(doc(db, `schools/${SCHOOL}/members/${DRIVER}`), {
      uid: DRIVER,
      schoolId: SCHOOL,
      role: 'driver',
      status: 'approved',
      isActive: true,
    });
    await setDoc(doc(db, `schools/${SCHOOL}/buses/${BUS}`), {
      id: BUS,
      schoolId: SCHOOL,
      name: 'Bus 1',
      isActive: true,
      capacity: 30,
    });
    const initialBoarded = Array.from({ length: 29 }, (_, i) => `existing-${i}`);
    await setDoc(doc(db, `schools/${SCHOOL}/trips/${TRIP}`), {
      id: TRIP,
      schoolId: SCHOOL,
      busId: BUS,
      driverId: DRIVER,
      status: 'active',
      stopOrder: [...initialBoarded, 'race-student-1', 'race-student-2'],
      boardedStudents: initialBoarded,
      droppedOffStudents: [],
    });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

/** Mirrors StopOrderRepository.markBoarded's transaction body. */
async function tryBoard(db, studentId) {
  const tripRef = doc(db, `schools/${SCHOOL}/trips/${TRIP}`);
  const busRef = doc(db, `schools/${SCHOOL}/buses/${BUS}`);

  return runTransaction(db, async (transaction) => {
    const tripSnap = await transaction.get(tripRef);
    const trip = tripSnap.data();
    const busSnap = await transaction.get(busRef);
    const capacity = busSnap.data().capacity;

    const boarded = trip.boardedStudents ?? [];
    const droppedOff = trip.droppedOffStudents ?? [];
    if (boarded.includes(studentId)) return 'already-boarded';

    const onboardNow = boarded.length - droppedOff.length;
    if (capacity != null && onboardNow >= capacity) {
      throw new Error('bus at capacity');
    }

    transaction.update(tripRef, { boardedStudents: [...boarded, studentId] });
    return 'boarded';
  });
}

test('boarding_race: two simultaneous boarding requests for the last open seat — only one succeeds', async () => {
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  const results = await Promise.allSettled([
    tryBoard(asDriver, 'race-student-1'),
    tryBoard(asDriver, 'race-student-2'),
  ]);

  const succeeded = results.filter((r) => r.status === 'fulfilled');
  const failed = results.filter((r) => r.status === 'rejected');

  assert.equal(succeeded.length, 1, 'exactly one racing boarding must win the last seat');
  assert.equal(failed.length, 1, 'the other must be rejected, not silently dropped or double-counted');

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const { getDoc } = require('firebase/firestore');
    const snap = await getDoc(doc(context.firestore(), `schools/${SCHOOL}/trips/${TRIP}`));
    const boarded = snap.data().boardedStudents;
    assert.equal(boarded.length, 30, 'the bus must end at exactly capacity, never 31');
  });
});
