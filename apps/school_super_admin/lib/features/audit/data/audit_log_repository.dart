import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Production hardening: complete audit trail. Writes into the *target*
/// school's own `schools/{schoolId}/auditLog` collection — the same one
/// `school_admin` reads via its Audit Trail page — rather than a second,
/// platform-level audit system. A system admin isn't a member of the
/// school they're acting on (their privilege comes from the top-level
/// `systemAdmins/{uid}` doc, not a `members` entry), so firestore.rules'
/// `auditLog` create rule explicitly grants `isSystemAdmin()` the same
/// append access every active member of that school already has for their
/// own actions.
///
/// Before this, `school_super_admin` — the single most privileged app in
/// the system — left no durable record of school creation/(de)activation
/// or school-admin approval/rejection at all.
class AuditLogRepository {
  AuditLogRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> record({
    required String schoolId,
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
  }) {
    final actorUid = _auth.currentUser?.uid;
    if (actorUid == null) return Future.value();

    final ref = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('auditLog')
        .doc();
    return ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'actorUid': actorUid,
      'actorRole': 'systemAdmin',
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'entityType': ?entityType,
      'entityId': ?entityId,
      if (metadata.isNotEmpty) 'metadata': metadata,
    });
  }

  /// [record], with any failure swallowed — a transient audit-log failure
  /// must never roll back or fail-surface a platform action that already
  /// succeeded (a school really was created/activated/deactivated).
  Future<void> recordSafely({
    required String schoolId,
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await record(
        schoolId: schoolId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
      );
    } catch (_) {
      // Intentionally ignored — see the class doc comment.
    }
  }
}
