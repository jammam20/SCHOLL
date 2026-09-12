import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

class DriversRepository {
  DriversRepository({FirebaseFirestore? firestore, AuditLogRepository? auditLog})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _members(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('members');
  }

  // `limit` keeps this from reading every driver in the school on every
  // page load — the admin_home_page._DriversTab UI bumps it by _pageSize
  // each time "Load more" is tapped rather than fetching everything up
  // front.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchDrivers(
    String schoolId, {
    int limit = 30,
  }) {
    return _members(schoolId)
        .where('role', isEqualTo: 'driver')
        // Member documents only ever carry `displayName` (set at
        // self-registration — see FirebaseAuthRepository.registerDriver in
        // the driver app), not `name`. Must match the composite index in
        // firestore.indexes.json (role ASC, displayName ASC).
        .orderBy('displayName')
        .limit(limit)
        .snapshots();
  }

  // firestore.rules scopes a member `update` to a school admin touching
  // only status/isActive/updatedAt (see the `members/{uid}` rule) — a
  // direct write, not a callable, now that a Cloud Function isn't required
  // just to approve a driver.
  Future<void> _setStatus({
    required String schoolId,
    required String uid,
    required String status,
    required String auditAction,
    String? reason,
  }) async {
    await _members(schoolId).doc(uid).update({
      'status': status,
      'isActive': status == 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
      // Feature: unified accept/reject UI — recorded alongside status so a
      // suspend/reject carries its own "why" (see PendingApprovalCard),
      // rather than only living in the moment's audit-log entry.
      if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
    });
    // Production hardening: the suspend/reject confirmation dialog's own
    // copy ("Reason — visible in the audit log") was previously false for
    // this repository, since nothing here ever wrote to auditLog.
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: auditAction,
      entityType: 'driver',
      entityId: uid,
      driverId: uid,
      metadata: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> approveDriver({required String schoolId, required String uid}) {
    return _setStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'approved',
      auditAction: AuditActions.driverApproved,
    );
  }

  Future<void> suspendDriver({
    required String schoolId,
    required String uid,
    String? reason,
  }) {
    return _setStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'suspended',
      auditAction: AuditActions.driverSuspended,
      reason: reason,
    );
  }

  Future<void> rejectDriver({
    required String schoolId,
    required String uid,
    String? reason,
  }) {
    return _setStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'rejected',
      auditAction: AuditActions.driverRejected,
      reason: reason,
    );
  }
}
