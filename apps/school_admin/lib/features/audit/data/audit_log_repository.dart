import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Reads and appends the school's immutable operational audit trail
/// (`schools/{schoolId}/auditLog/{id}`). firestore.rules allows `create`
/// only — never update/delete — and requires `schoolId` to match the path
/// and `actorUid` to be the caller, so [record] always stamps the signed-in
/// uid itself rather than accepting one from a call site.
///
/// An audit write is deliberately *never* allowed to fail the action it
/// describes: [record] swallows its own errors (see [recordSafely]) so a
/// transient logging failure can't roll back an incident resolution or a
/// trip reassignment that already succeeded.
class AuditLogRepository {
  AuditLogRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _auditLog(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('auditLog');
  }

  /// Newest-first, matching the (schoolId ASC, timestamp DESC) composite
  /// index already declared in firebase/firestore.indexes.json. Action /
  /// entity / date-range filtering happens client-side in
  /// [AuditTrailPage] rather than as extra `where` clauses, so no
  /// additional composite index is required.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAuditLog(
    String schoolId, {
    int limit = 100,
  }) {
    return _auditLog(schoolId)
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Appends one entry. Throws if not signed in or if the write is
  /// rejected — call [recordSafely] from an action's success path instead,
  /// so logging can never undo work that already committed.
  Future<void> record({
    required String schoolId,
    required String action,
    String actorRole = 'admin',
    String? entityType,
    String? entityId,
    String? tripId,
    String? busId,
    String? driverId,
    String? studentId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final actorUid = _auth.currentUser?.uid;
    if (actorUid == null) return;

    final ref = _auditLog(schoolId).doc();
    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'actorUid': actorUid,
      'actorRole': actorRole,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'entityType': ?entityType,
      'entityId': ?entityId,
      'tripId': ?tripId,
      'busId': ?busId,
      'driverId': ?driverId,
      'studentId': ?studentId,
      if (metadata.isNotEmpty) 'metadata': metadata,
    });
  }

  /// [record], with any failure swallowed. Use this at every call site
  /// that logs an action which has *already* succeeded.
  Future<void> recordSafely({
    required String schoolId,
    required String action,
    String actorRole = 'admin',
    String? entityType,
    String? entityId,
    String? tripId,
    String? busId,
    String? driverId,
    String? studentId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await record(
        schoolId: schoolId,
        action: action,
        actorRole: actorRole,
        entityType: entityType,
        entityId: entityId,
        tripId: tripId,
        busId: busId,
        driverId: driverId,
        studentId: studentId,
        metadata: metadata,
      );
    } catch (_) {
      // Intentionally ignored — see the class doc comment.
    }
  }
}
