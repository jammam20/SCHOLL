// Production hardening — Phase 3 (Complete Audit Trail) security proof.
//
// Proves: (1) a system admin (school_super_admin — not a member of the
// target school) can now append to that school's auditLog, closing the
// gap that left the entire super_admin app with zero audit trail; (2) an
// ordinary member still cannot forge another actor's entry or touch a
// different school's log; (3) every audit entry remains immutable
// (create-only — no update, no delete) for everyone, including admins and
// system admins.
'use strict';

const test = require('node:test');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');
const { makeTestEnv, seed } = require('./helpers');

const SCHOOL = 'school-audit';
const ADMIN = 'admin-1';
const SYSTEM_ADMIN = 'system-admin-1';

let testEnv;

test.before(async () => {
  testEnv = await makeTestEnv();
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${SCHOOL}`), { id: SCHOOL, isActive: true });
    await setDoc(doc(db, `schools/${SCHOOL}/members/${ADMIN}`), {
      uid: ADMIN,
      schoolId: SCHOOL,
      role: 'admin',
      status: 'approved',
      isActive: true,
    });
    await setDoc(doc(db, `systemAdmins/${SYSTEM_ADMIN}`), { isActive: true });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test('audit_trail: a system admin (not a member of the school) CAN append an audit entry for a platform action', async () => {
  const asSystemAdmin = testEnv.authenticatedContext(SYSTEM_ADMIN).firestore();
  await assertSucceeds(
    setDoc(doc(asSystemAdmin, `schools/${SCHOOL}/auditLog/school-created`), {
      schoolId: SCHOOL,
      actorUid: SYSTEM_ADMIN,
      actorRole: 'systemAdmin',
      action: 'school_created',
      timestamp: new Date(),
    }),
  );
});

test('audit_trail: an ordinary signed-in user who is not a member of the school and not a system admin CANNOT append', async () => {
  const asOutsider = testEnv.authenticatedContext('outsider-1').firestore();
  await assertFails(
    setDoc(doc(asOutsider, `schools/${SCHOOL}/auditLog/forged`), {
      schoolId: SCHOOL,
      actorUid: 'outsider-1',
      actorRole: 'admin',
      action: 'bus_created',
      timestamp: new Date(),
    }),
  );
});

test('audit_trail: a system admin cannot forge actorUid as someone else', async () => {
  const asSystemAdmin = testEnv.authenticatedContext(SYSTEM_ADMIN).firestore();
  await assertFails(
    setDoc(doc(asSystemAdmin, `schools/${SCHOOL}/auditLog/forged-2`), {
      schoolId: SCHOOL,
      actorUid: 'someone-else',
      actorRole: 'systemAdmin',
      action: 'school_created',
      timestamp: new Date(),
    }),
  );
});

test('audit_trail: an admin can append their own action', async () => {
  const asAdmin = testEnv.authenticatedContext(ADMIN).firestore();
  await assertSucceeds(
    setDoc(doc(asAdmin, `schools/${SCHOOL}/auditLog/driver-approved-1`), {
      schoolId: SCHOOL,
      actorUid: ADMIN,
      actorRole: 'admin',
      action: 'driver_approved',
      timestamp: new Date(),
    }),
  );
});

test('audit_trail: entries are immutable — even the acting admin cannot update one', async () => {
  const asAdmin = testEnv.authenticatedContext(ADMIN).firestore();
  await assertFails(
    updateDoc(doc(asAdmin, `schools/${SCHOOL}/auditLog/driver-approved-1`), {
      action: 'tampered',
    }),
  );
});

test('audit_trail: entries are immutable — even a system admin cannot delete one', async () => {
  const asSystemAdmin = testEnv.authenticatedContext(SYSTEM_ADMIN).firestore();
  await assertFails(deleteDoc(doc(asSystemAdmin, `schools/${SCHOOL}/auditLog/driver-approved-1`)));
});

test('audit_trail: a driver/parent role cannot read the audit log of their own school', async () => {
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, `schools/${SCHOOL}/members/parent-1`), {
      uid: 'parent-1',
      schoolId: SCHOOL,
      role: 'parent',
      status: 'approved',
      isActive: true,
    });
  });
  const { getDoc } = require('firebase/firestore');
  const asParent = testEnv.authenticatedContext('parent-1').firestore();
  await assertFails(getDoc(doc(asParent, `schools/${SCHOOL}/auditLog/driver-approved-1`)));
});
