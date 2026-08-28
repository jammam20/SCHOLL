import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsRepository {
  ReportsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Every absence-log entry recorded since [since] — see
  /// StudentsRepository.setAbsent in the parent app for how these are
  /// written; there's no earlier history than whenever that shipped.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAbsences(
    String schoolId, {
    required DateTime since,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('absenceLog')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Every trip scheduled since [since] — used to compute completion rate,
  /// on-time rate, average duration and per-driver breakdowns. Deliberately
  /// not paginated like the Trips tab: a report needs the whole range to
  /// average correctly, not just the newest page.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTripsSince(
    String schoolId, {
    required DateTime since,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .snapshots();
  }
}
