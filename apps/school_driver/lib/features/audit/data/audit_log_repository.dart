import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../trips/domain/trip_operation_exception.dart';

/// Append-only operational audit trail at `schools/{schoolId}/auditLog`
/// (see [AuditLogEntry]). firestore.rules allows `create` only — never
/// update or delete — and requires `schoolId` to match the path and
/// `actorUid` to be the caller, which is why [buildEntry] stamps both from
/// the signed-in user rather than accepting them from a caller.
///
/// Exposes [newEntryRef] + [buildEntry] separately from [record] so a
/// caller writing the thing being audited can put both writes in one
/// `WriteBatch` — an inspection/incident/verification and its audit copy
/// then either both land or neither does, instead of leaving a recorded
/// action with no trail behind it.
class AuditLogRepository {
  AuditLogRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _auditLog(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('auditLog');
  }

  DocumentReference<Map<String, dynamic>> newEntryRef(String schoolId) =>
      _auditLog(schoolId).doc();

  /// Every entry written from this app is by definition a driver acting on
  /// their own trip, so `actorRole`/`driverId` are both fixed to the
  /// signed-in driver here rather than being parameters a call site could
  /// get wrong.
  Map<String, dynamic> buildEntry({
    required String schoolId,
    required String action,
    String? entityType,
    String? entityId,
    String? tripId,
    String? busId,
    String? studentId,
    Map<String, dynamic> metadata = const {},
  }) {
    final actorUid = _auth.currentUser?.uid;
    if (actorUid == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    return {
      'schoolId': schoolId,
      'actorUid': actorUid,
      'actorRole': UserRole.driver.name,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'driverId': actorUid,
      'entityType': ?entityType,
      'entityId': ?entityId,
      'tripId': ?tripId,
      if (busId != null && busId.isNotEmpty) 'busId': busId,
      'studentId': ?studentId,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// A standalone audit write, for the one call site that can't batch:
  /// raising an emergency already happens inside its own transaction (see
  /// EmergenciesRepository.createEmergency), which can't be joined to a
  /// batch after the fact.
  Future<void> record({
    required String schoolId,
    required String action,
    String? entityType,
    String? entityId,
    String? tripId,
    String? busId,
    String? studentId,
    Map<String, dynamic> metadata = const {},
  }) {
    return newEntryRef(schoolId).set(
      buildEntry(
        schoolId: schoolId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        tripId: tripId,
        busId: busId,
        studentId: studentId,
        metadata: metadata,
      ),
    );
  }

  /// [record], with any failure swallowed — mirrors the admin app's own
  /// `AuditLogRepository.recordSafely`. Use this at every call site that
  /// logs an action which has *already* succeeded, so a transient audit
  /// write failure can never roll back or fail-surface a real action (a
  /// completed trip, a recorded boarding) that already committed.
  Future<void> recordSafely({
    required String schoolId,
    required String action,
    String? entityType,
    String? entityId,
    String? tripId,
    String? busId,
    String? studentId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await record(
        schoolId: schoolId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        tripId: tripId,
        busId: busId,
        studentId: studentId,
        metadata: metadata,
      );
    } catch (_) {
      // Intentionally ignored — see the class doc comment.
    }
  }
}
