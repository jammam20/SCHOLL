import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// The fixed document id the deviation engine upserts its single *live*
/// record under — one per trip, not one per episode. Mirrors the
/// `schools/{schoolId}/trips/{tripId}/deviation/current` path written by
/// onDriverLocationWritten in functions/src/index.ts.
const currentDeviationDocId = 'current';

/// Read-only: a parent can see that their child's bus is currently off its
/// expected route, but never writes anything here — firestore.rules blocks
/// every client write on this subcollection (`allow write: if false`), so a
/// deviation is always the server's finding, never a self-report.
class DeviationRepository {
  DeviationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Emits `null` when no live record exists for the trip — the common
  /// case, since the document is only created once a deviation episode
  /// actually starts.
  Stream<DeviationRecord?> watchCurrentDeviation({
    required String schoolId,
    required String tripId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .doc(tripId)
        .collection('deviation')
        .doc(currentDeviationDocId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) return null;
          return DeviationRecord.fromMap(snapshot.id, data);
        });
  }
}
