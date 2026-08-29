import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads pickup-verification records across every trip in the school.
///
/// These live at `schools/{schoolId}/trips/{tripId}/pickupVerifications/{id}`
/// and are written only by the assigned driver (see firestore.rules), so
/// this repository is read-only. A cross-trip read requires a
/// `collectionGroup` query — the same technique
/// [EmergenciesRepository] already uses for the equivalent nested
/// `emergencies` collection.
///
/// Note this collection may legitimately be **empty or absent**: the
/// secure-pickup flow that writes it belongs to the driver/parent
/// workstream. Callers must treat "no records" as "this feature has no
/// data yet" and render nothing, never a zeroed-out chart — see
/// SafetyAnalyticsSection, which hides its whole pickup section in that
/// case.
class PickupVerificationsRepository {
  PickupVerificationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Deliberately a plain `where` with no `orderBy`: firestore.indexes.json
  /// declares no composite index for this collection group, and this app
  /// must not require one to be added. Ordering isn't needed — every
  /// caller aggregates rather than lists these in sequence.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchVerifications(
    String schoolId, {
    int limit = 300,
  }) {
    return _firestore
        .collectionGroup('pickupVerifications')
        .where('schoolId', isEqualTo: schoolId)
        .limit(limit)
        .snapshots();
  }
}
