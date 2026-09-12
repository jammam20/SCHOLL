// Production hardening — Phase 2 (Bus Capacity Server Enforcement).
//
// Proves the capacity guard added to firestore.rules' `trips/{tripId}`
// driver-scoped update rule actually rejects a direct write that would
// exceed a bus's configured capacity — i.e. that enforcement lives at the
// trusted backend boundary, not only in the Flutter driver app's
// transaction logic (which a compromised/direct client could bypass
// entirely by calling the Firestore SDK/REST API directly, as this test
// does).
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc } = require('firebase/firestore');
const { makeTestEnv, seed } = require('./helpers');

const SCHOOL = 'school-a';
const BUS = 'bus-1';
const DRIVER = 'driver-1';
const TRIP = 'trip-1';

let testEnv;

test.before(async () => {
  testEnv = await makeTestEnv();
});

test.after(async () => {
  await testEnv.cleanup();
});

async function seedSchoolAndDriver(capacity) {
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${SCHOOL}`), { id: SCHOOL, name: 'A', isActive: true });
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
      plateNumber: 'ABC-123',
      isActive: true,
      ...(capacity === undefined ? {} : { capacity }),
    });
  });
}

async function seedTrip({ boarded, droppedOff, stopOrder }) {
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${SCHOOL}/trips/${TRIP}`), {
      id: TRIP,
      schoolId: SCHOOL,
      routeId: 'route-1',
      busId: BUS,
      driverId: DRIVER,
      status: 'active',
      direction: 'outbound',
      stopOrder,
      boardedStudents: boarded,
      droppedOffStudents: droppedOff,
    });
  });
}

test('bus_capacity: capacity 1 — boarding the first student succeeds', async () => {
  await seedSchoolAndDriver(1);
  await seedTrip({ boarded: [], droppedOff: [], stopOrder: ['s1', 's2'] });
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  await assertSucceeds(
    updateDoc(doc(asDriver, `schools/${SCHOOL}/trips/${TRIP}`), {
      boardedStudents: ['s1'],
      updatedAt: new Date(),
    }),
  );
});

test('bus_capacity: capacity 1 — boarding a second student while the first is aboard is rejected', async () => {
  await seedSchoolAndDriver(1);
  await seedTrip({ boarded: ['s1'], droppedOff: [], stopOrder: ['s1', 's2'] });
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  await assertFails(
    updateDoc(doc(asDriver, `schools/${SCHOOL}/trips/${TRIP}`), {
      boardedStudents: ['s1', 's2'],
      updatedAt: new Date(),
    }),
  );
});

test('bus_capacity: exactly at capacity (29 of 30) allows the 30th boarding', async () => {
  await seedSchoolAndDriver(30);
  const boarded = Array.from({ length: 29 }, (_, i) => `s${i}`);
  await seedTrip({ boarded, droppedOff: [], stopOrder: [...boarded, 's29'] });
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  await assertSucceeds(
    updateDoc(doc(asDriver, `schools/${SCHOOL}/trips/${TRIP}`), {
      boardedStudents: [...boarded, 's29'],
      updatedAt: new Date(),
    }),
  );
});

test('bus_capacity: one student over capacity (30 of 30) is rejected', async () => {
  await seedSchoolAndDriver(30);
  const boarded = Array.from({ length: 30 }, (_, i) => `s${i}`);
  await seedTrip({ boarded, droppedOff: [], stopOrder: [...boarded, 's30'] });
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  await assertFails(
    updateDoc(doc(asDriver, `schools/${SCHOOL}/trips/${TRIP}`), {
      boardedStudents: [...boarded, 's30'],
      updatedAt: new Date(),
    }),
  );
});

test('bus_capacity: a drop-off frees a seat for the next boarding', async () => {
  await seedSchoolAndDriver(1);
  // 1 boarded, then dropped off -> 0 truly onboard, so there's a free seat.
  await seedTrip({ boarded: ['s1'], droppedOff: ['s1'], stopOrder: ['s1', 's2'] });
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  await assertSucceeds(
    updateDoc(doc(asDriver, `schools/${SCHOOL}/trips/${TRIP}`), {
      boardedStudents: ['s1', 's2'],
      updatedAt: new Date(),
    }),
  );
});

test('bus_capacity: no configured capacity never blocks boarding', async () => {
  await seedSchoolAndDriver(undefined);
  const boarded = Array.from({ length: 500 }, (_, i) => `s${i}`);
  await seedTrip({ boarded, droppedOff: [], stopOrder: [...boarded, 's500'] });
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  await assertSucceeds(
    updateDoc(doc(asDriver, `schools/${SCHOOL}/trips/${TRIP}`), {
      boardedStudents: [...boarded, 's500'],
      updatedAt: new Date(),
    }),
  );
});

test('bus_capacity: a direct/unauthorized client cannot forge a smaller boardedStudents count to sneak past capacity while keeping extra passengers unaccounted for', async () => {
  // A malicious client can't just omit droppedOffStudents to make the
  // onboard count look smaller than it is, because the rule recomputes
  // onboard count from the *resulting* document, which still carries
  // whatever droppedOffStudents already existed (untouched by this write).
  await seedSchoolAndDriver(1);
  await seedTrip({ boarded: ['s1'], droppedOff: [], stopOrder: ['s1', 's2'] });
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  await assertFails(
    updateDoc(doc(asDriver, `schools/${SCHOOL}/trips/${TRIP}`), {
      boardedStudents: ['s1', 's2'],
      updatedAt: new Date(),
    }),
  );
});

test('bus_capacity: trip completion behavior — boardedStudents cannot be touched once the trip is no longer active', async () => {
  await seedSchoolAndDriver(30);
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${SCHOOL}/trips/${TRIP}`), {
      id: TRIP,
      schoolId: SCHOOL,
      routeId: 'route-1',
      busId: BUS,
      driverId: DRIVER,
      status: 'completed',
      direction: 'outbound',
      stopOrder: ['s1'],
      boardedStudents: [],
      droppedOffStudents: [],
    });
  });
  const asDriver = testEnv.authenticatedContext(DRIVER).firestore();

  await assertFails(
    updateDoc(doc(asDriver, `schools/${SCHOOL}/trips/${TRIP}`), {
      boardedStudents: ['s1'],
      updatedAt: new Date(),
    }),
  );
});
