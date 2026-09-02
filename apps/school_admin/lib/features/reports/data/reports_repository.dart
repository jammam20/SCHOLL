import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

class ReportsRepository {
  ReportsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Every absence-log entry recorded since [since] — a raw, unconstrained
  /// event trail (a student toggled absent/present twice in one day writes
  /// two entries here); see StudentsRepository.setAbsent in the parent app.
  /// Kept for history, but no longer what the "absences" count/breakdown is
  /// computed from — see [watchAttendanceRecordsSince] for that.
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

  /// The canonical, one-per-(student, day) attendance state since [since]
  /// (Feature: absence data integrity) — this, not [watchAbsences], is what
  /// "how many absences in this range" must be computed from: a student
  /// toggled absent -> present -> absent on the same day is exactly one
  /// document here (upserted, not appended), so it counts once no matter
  /// how many times it was toggled. `date` is compared as a plain
  /// `'yyyy-MM-dd'` string, which sorts identically to chronological order.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAttendanceRecordsSince(
    String schoolId, {
    required DateTime since,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendanceRecords')
        .where('date', isGreaterThanOrEqualTo: isoDateOnly(since))
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
