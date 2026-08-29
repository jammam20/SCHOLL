import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// Read-only access to route-deviation records.
///
/// Both collections this reads are written **exclusively** server-side by
/// the `onDriverLocationWritten` Cloud Function (see functions/src/index.ts
/// and firestore.rules, which sets `allow write: if false` on both) — a
/// client cannot self-report being on or off route. This repository
/// therefore has no write methods at all, by design.
class DeviationsRepository {
  DeviationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// The single *live* deviation record for one trip. A fixed document id
  /// (`current`) is used by convention — see DeviationRecord's own doc
  /// comment — so this is a document watch, not a query.
  Stream<DeviationRecord?> watchLiveDeviation({
    required String schoolId,
    required String tripId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .doc(tripId)
        .collection('deviation')
        .doc('current')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) return null;
          return DeviationRecord.fromMap(snapshot.id, data);
        });
  }

  /// Closed deviation episodes, newest first — matches the existing
  /// (schoolId ASC, startedAt DESC) composite index in
  /// firebase/firestore.indexes.json. Route/bus/date filtering is applied
  /// client-side by [RouteDeviationsPage] so no extra index is needed.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchDeviationHistory(
    String schoolId, {
    int limit = 200,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('routeDeviations')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
