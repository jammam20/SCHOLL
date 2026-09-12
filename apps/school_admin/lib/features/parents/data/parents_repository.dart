import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

class ParentsRepository {
  ParentsRepository({FirebaseFirestore? firestore, AuditLogRepository? auditLog})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _members(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('members');
  }

  // `limit` keeps this from reading every parent in the school on every
  // page load — the admin_home_page._ParentsTab UI bumps it by _pageSize
  // each time "Load more" is tapped rather than fetching everything up
  // front.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchParents(
    String schoolId, {
    int limit = 30,
  }) {
    return _members(schoolId)
        // Same (role ASC, displayName ASC) composite index the driver list
        // uses.
        .where('role', isEqualTo: 'parent')
        .orderBy('displayName')
        .limit(limit)
        .snapshots();
  }

  // firestore.rules scopes a member `update` to a school admin touching
  // only status/isActive/updatedAt (see the `members/{uid}` rule) — a
  // direct write, not a callable, so approving a parent doesn't need the
  // project on Firebase's paid Blaze plan.
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
      if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
    });
    // Production hardening: the suspend/reject confirmation dialog's own
    // copy ("Reason — visible in the audit log") was previously false for
    // this repository, since nothing here ever wrote to auditLog.
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: auditAction,
      entityType: 'parent',
      entityId: uid,
      metadata: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> approveParent({required String schoolId, required String uid}) {
    return _setStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'approved',
      auditAction: AuditActions.parentApproved,
    );
  }

  Future<void> suspendParent({
    required String schoolId,
    required String uid,
    String? reason,
  }) {
    return _setStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'suspended',
      auditAction: AuditActions.parentSuspended,
      reason: reason,
    );
  }

  Future<void> rejectParent({
    required String schoolId,
    required String uid,
    String? reason,
  }) {
    return _setStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'rejected',
      auditAction: AuditActions.parentRejected,
      reason: reason,
    );
  }
}
