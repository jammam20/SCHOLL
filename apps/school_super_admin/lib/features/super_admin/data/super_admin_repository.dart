import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

/// Everything the Super Admin panel needs: creating schools (without ever
/// touching the Firebase Console) and approving the very first admin of
/// each one. Every write here is only reachable by an active
/// `systemAdmins/{uid}` document — see firestore.rules.
class SuperAdminRepository {
  SuperAdminRepository({FirebaseFirestore? firestore, AuditLogRepository? auditLog})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSchools() {
    return _firestore.collection('schools').orderBy('name').snapshots();
  }

  /// Creates a school and its join code together — the code is what a
  /// school's owner then types into the admin app's "Create admin account"
  /// screen to self-register as that school's first (pending) admin.
  ///
  /// Runs as a transaction that reads `schoolJoinCodes/{code}` before
  /// writing it: a plain batch `set()` here previously overwrote whatever
  /// school already held that code with no check at all, silently
  /// re-pointing an existing, already-distributed join code at the new
  /// school — anyone still registering with the old code would land in the
  /// wrong school entirely. [SchoolCodeTakenException] surfaces that as a
  /// real, catchable error instead.
  Future<void> createSchool({
    required String name,
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final schoolRef = _firestore.collection('schools').doc();
    final codeRef = _firestore.collection('schoolJoinCodes').doc(normalizedCode);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(codeRef);
      if (existing.exists) {
        throw SchoolCodeTakenException(normalizedCode);
      }
      transaction.set(schoolRef, {
        'id': schoolRef.id,
        'name': name.trim(),
        'code': normalizedCode,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(codeRef, {'schoolId': schoolRef.id, 'active': true});
    });

    // The school document now exists (this transaction just created it),
    // so it's a valid target for its own auditLog subcollection even
    // though this is the very first thing ever recorded against it.
    await _auditLog.recordSafely(
      schoolId: schoolRef.id,
      action: AuditActions.schoolCreated,
      entityType: 'school',
      entityId: schoolRef.id,
      metadata: {'name': name.trim(), 'code': normalizedCode},
    );
  }

  Future<void> setSchoolActive({
    required String schoolId,
    required bool active,
  }) async {
    await _firestore.collection('schools').doc(schoolId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: active ? AuditActions.schoolActivated : AuditActions.schoolDeactivated,
      entityType: 'school',
      entityId: schoolId,
    );
  }

  /// Every pending 'admin' membership across every school — a collection
  /// group query, matched against the same per-document `members/{uid}`
  /// read rule as everywhere else (a system admin is granted read there
  /// regardless of which school the document belongs to).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingAdmins() {
    return _firestore
        .collectionGroup('members')
        .where('role', isEqualTo: 'admin')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> _setAdminStatus({
    required String schoolId,
    required String uid,
    required String status,
    required String auditAction,
    String? reason,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('members')
        .doc(uid)
        .update({
          'status': status,
          'isActive': status == 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
          if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
        });
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: auditAction,
      entityType: 'schoolAdmin',
      entityId: uid,
      metadata: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> approveAdmin({required String schoolId, required String uid}) {
    return _setAdminStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'approved',
      auditAction: AuditActions.schoolAdminApproved,
    );
  }

  Future<void> rejectAdmin({
    required String schoolId,
    required String uid,
    String? reason,
  }) {
    return _setAdminStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'rejected',
      auditAction: AuditActions.schoolAdminRejected,
      reason: reason,
    );
  }
}

/// Thrown by [SuperAdminRepository.createSchool] when the requested join
/// code already belongs to another school.
class SchoolCodeTakenException implements Exception {
  const SchoolCodeTakenException(this.code);
  final String code;
}
