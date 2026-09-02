import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A parent's own write path into the school's shared, immutable audit
/// trail (`schools/{schoolId}/auditLog/{id}`) — the exact same collection
/// the admin app's AuditLogRepository writes to and reads back for its
/// Audit trail page and the new per-entity activity timelines. A parent
/// can create an entry for their own action (firestore.rules requires
/// `actorUid == request.auth.uid`, same as every other role) but cannot
/// read this collection back — the admin/staff-only read rule is
/// unaffected by this app also being able to write to it.
///
/// Kept intentionally minimal (just what a parent action needs to record)
/// rather than mirroring the admin app's fuller repository — see
/// StudentsRepository.proposeLocationChange, the one call site.
class AuditLogRepository {
  AuditLogRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> recordSafely({
    required String schoolId,
    required String action,
    String? entityType,
    String? entityId,
    String? studentId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final actorUid = _auth.currentUser?.uid;
    if (actorUid == null) return;
    try {
      final ref = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .doc();
      await ref.set({
        'id': ref.id,
        'schoolId': schoolId,
        'actorUid': actorUid,
        'actorRole': 'parent',
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'entityType': entityType,
        'entityId': entityId,
        'studentId': studentId,
        if (metadata.isNotEmpty) 'metadata': metadata,
      });
    } catch (_) {
      // Best-effort, matching the admin app's own recordSafely — a logging
      // failure must never roll back the action it describes.
    }
  }
}
