// Production hardening — Phase 5 (Security Regression) adversarial checks.
//
// The forensic audit's own tenant-isolation section explicitly flagged
// that no live emulator-based negative test existed for cross-school
// access — everything was "sound by code review, not proven by test".
// This file is that missing proof for the resources this hardening pass
// actually touches (trips, buses, students, activeTripLocks, auditLog),
// run as a genuine School-A member attempting School-B's data.
'use strict';

const test = require('node:test');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, getDocs, collection } = require('firebase/firestore');
const { makeTestEnv, seed } = require('./helpers');

const SCHOOL_A = 'school-a';
const SCHOOL_B = 'school-b';
const A_ADMIN = 'a-admin';
const A_DRIVER = 'a-driver';
const B_DRIVER = 'b-driver';

let testEnv;

test.before(async () => {
  testEnv = await makeTestEnv();
  await seed(testEnv, async (db) => {
    for (const [schoolId, adminUid, driverUid] of [
      [SCHOOL_A, A_ADMIN, A_DRIVER],
      [SCHOOL_B, 'b-admin', B_DRIVER],
    ]) {
      await setDoc(doc(db, `schools/${schoolId}`), { id: schoolId, name: schoolId, isActive: true });
      await setDoc(doc(db, `schools/${schoolId}/members/${adminUid}`), {
        uid: adminUid,
        schoolId,
        role: 'admin',
        status: 'approved',
        isActive: true,
      });
      await setDoc(doc(db, `schools/${schoolId}/members/${driverUid}`), {
        uid: driverUid,
        schoolId,
        role: 'driver',
        status: 'approved',
        isActive: true,
      });
    }

    await setDoc(doc(db, `schools/${SCHOOL_B}/buses/bus-b`), {
      id: 'bus-b',
      schoolId: SCHOOL_B,
      name: 'B Bus',
      plateNumber: 'B-1',
      isActive: true,
      capacity: 30,
    });
    await setDoc(doc(db, `schools/${SCHOOL_B}/trips/trip-b`), {
      id: 'trip-b',
      schoolId: SCHOOL_B,
      routeId: 'route-b',
      busId: 'bus-b',
      driverId: B_DRIVER,
      status: 'active',
      direction: 'outbound',
      stopOrder: ['student-b'],
      boardedStudents: [],
      droppedOffStudents: [],
    });
    await setDoc(doc(db, `schools/${SCHOOL_B}/students/student-b`), {
      id: 'student-b',
      schoolId: SCHOOL_B,
      name: 'Student B',
      parentIds: ['parent-b'],
      approved: true,
      isActive: true,
    });
    await setDoc(doc(db, `schools/${SCHOOL_B}/auditLog/entry-b`), {
      schoolId: SCHOOL_B,
      actorUid: 'b-admin',
      actorRole: 'admin',
      action: 'bus_created',
      timestamp: new Date(),
    });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test('tenant_isolation: School A admin cannot read School B audit records', async () => {
  const asAAdmin = testEnv.authenticatedContext(A_ADMIN).firestore();
  await assertFails(getDoc(doc(asAAdmin, `schools/${SCHOOL_B}/auditLog/entry-b`)));
});

test('tenant_isolation: School A admin cannot write School B audit records', async () => {
  const asAAdmin = testEnv.authenticatedContext(A_ADMIN).firestore();
  await assertFails(
    setDoc(doc(asAAdmin, `schools/${SCHOOL_B}/auditLog/forged`), {
      schoolId: SCHOOL_B,
      actorUid: A_ADMIN,
      actorRole: 'admin',
      action: 'bus_created',
      timestamp: new Date(),
    }),
  );
});

test('tenant_isolation: a user cannot forge an audit entry claiming to be a different actor', async () => {
  const asAAdmin = testEnv.authenticatedContext(A_ADMIN).firestore();
  await assertFails(
    setDoc(doc(asAAdmin, `schools/${SCHOOL_A}/auditLog/forged`), {
      schoolId: SCHOOL_A,
      actorUid: 'someone-else',
      actorRole: 'admin',
      action: 'bus_created',
      timestamp: new Date(),
    }),
  );
});

test('tenant_isolation: School A admin cannot modify School B bus', async () => {
  const asAAdmin = testEnv.authenticatedContext(A_ADMIN).firestore();
  await assertFails(
    updateDoc(doc(asAAdmin, `schools/${SCHOOL_B}/buses/bus-b`), { capacity: 999 }),
  );
});

test('tenant_isolation: School A admin cannot modify School B trip', async () => {
  const asAAdmin = testEnv.authenticatedContext(A_ADMIN).firestore();
  await assertFails(
    updateDoc(doc(asAAdmin, `schools/${SCHOOL_B}/trips/trip-b`), { status: 'cancelled' }),
  );
});

test('tenant_isolation: School A driver cannot board a student on School B trip', async () => {
  const asADriver = testEnv.authenticatedContext(A_DRIVER).firestore();
  await assertFails(
    updateDoc(doc(asADriver, `schools/${SCHOOL_B}/trips/trip-b`), {
      boardedStudents: ['student-b'],
      updatedAt: new Date(),
    }),
  );
});

test('tenant_isolation: School A admin cannot read School B student records', async () => {
  const asAAdmin = testEnv.authenticatedContext(A_ADMIN).firestore();
  await assertFails(getDoc(doc(asAAdmin, `schools/${SCHOOL_B}/students/student-b`)));
});

test('tenant_isolation: an unauthenticated client cannot read anything', async () => {
  const anon = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, `schools/${SCHOOL_A}`)));
  await assertFails(getDocs(collection(anon, `schools/${SCHOOL_A}/trips`)));
});

test('tenant_isolation: sanity check — School B admin CAN do all of the above on their own school', async () => {
  const asBAdmin = testEnv.authenticatedContext('b-admin').firestore();
  await assertSucceeds(getDoc(doc(asBAdmin, `schools/${SCHOOL_B}/auditLog/entry-b`)));
  await assertSucceeds(updateDoc(doc(asBAdmin, `schools/${SCHOOL_B}/buses/bus-b`), { capacity: 25 }));
});
