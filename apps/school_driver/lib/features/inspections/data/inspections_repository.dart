import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';
import '../../trips/domain/trip_operation_exception.dart';
import '../domain/inspection_checklist.dart';

/// Pre/post-trip vehicle inspections, stored at
/// `schools/{schoolId}/trips/{tripId}/inspections/{id}`. firestore.rules
/// allows `create` only for the trip's assigned driver (and never update or
/// delete) — a failed inspection is a fact, not something to quietly
/// correct afterwards — so this repository only ever appends.
class InspectionsRepository {
  InspectionsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuditLogRepository? auditLog,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _auditLog = auditLog ?? AuditLogRepository(firestore: firestore, auth: auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _inspections(
    String schoolId,
    String tripId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .doc(tripId)
        .collection('inspections');
  }

  /// Whether this trip already has a passed inspection of [type] on record
  /// — the gate the driver app's "Start trip" action consults before it
  /// will actually start anything.
  ///
  /// The query filters on `driverId` and nothing else on purpose. That
  /// filter isn't an optimization: firestore.rules grants a driver read
  /// access to an inspection only when `resource.data.driverId ==
  /// request.auth.uid`, and Firestore rejects a query outright unless the
  /// query itself guarantees every result satisfies the read rule. `type`
  /// and `passed` are then matched client-side rather than added as further
  /// `where` clauses, so this can never start failing on a missing
  /// composite index — a trip has a handful of inspections at most.
  Future<bool> hasPassedInspection({
    required String schoolId,
    required String tripId,
    required InspectionType type,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final snapshot = await _inspections(schoolId, tripId)
        .where('driverId', isEqualTo: driverId)
        .get();

    return snapshot.docs.any((doc) {
      final data = doc.data();
      return data['type'] == type.value && data['passed'] == true;
    });
  }

  /// Records one submitted checklist and returns whether it passed.
  ///
  /// The inspection document and its [AuditActions.inspectionCompleted] /
  /// [AuditActions.inspectionFailed] audit entry are written in a single
  /// batch: a recorded inspection with no audit trail behind it (or an
  /// audit entry for an inspection that didn't store) would defeat the
  /// point of having either.
  ///
  /// `passed` is computed here from [isInspectionPassed] rather than being
  /// passed in, so a caller can't record a checklist as passing while an
  /// item on it says otherwise.
  Future<bool> submitInspection({
    required String schoolId,
    required String tripId,
    required String busId,
    required InspectionType type,
    required Map<String, bool> items,
    String? notes,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final passed = isInspectionPassed(items);
    final failed = failedInspectionItems(items).map((i) => i.value).toList();
    final trimmedNotes = notes?.trim();

    final inspectionRef = _inspections(schoolId, tripId).doc();
    final batch = _firestore.batch();

    batch.set(inspectionRef, {
      'schoolId': schoolId,
      'tripId': tripId,
      'driverId': driverId,
      if (busId.isNotEmpty) 'busId': busId,
      'type': type.value,
      'createdAt': FieldValue.serverTimestamp(),
      'items': items,
      'notes': trimmedNotes == null || trimmedNotes.isEmpty ? '' : trimmedNotes,
      'passed': passed,
    });

    batch.set(
      _auditLog.newEntryRef(schoolId),
      _auditLog.buildEntry(
        schoolId: schoolId,
        action: passed
            ? AuditActions.inspectionCompleted
            : AuditActions.inspectionFailed,
        entityType: 'inspection',
        entityId: inspectionRef.id,
        tripId: tripId,
        busId: busId,
        metadata: {
          'type': type.value,
          'passed': passed,
          if (failed.isNotEmpty) 'failedItems': failed,
        },
      ),
    );

    await batch.commit();
    return passed;
  }
}
