import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../trips/domain/trip_operation_exception.dart';

/// The driver app reads students to build and display a trip's pickup
/// order, and has exactly one write: appending an absence report for a
/// student who wasn't at their stop (see [reportAbsence], which explains
/// carefully what it can and cannot write). It never edits a student
/// document itself.
class StudentsRepository {
  StudentsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<Student>> watchStudentsForRoute({
    required String schoolId,
    required String routeId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('routeId', isEqualTo: routeId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Student.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Reports "this student wasn't at their stop today" from the driver's
  /// side, for today's date (the same 'yyyy-MM-dd' shape
  /// `Student.absentOn` uses — see [todayIsoDate]).
  ///
  /// **This deliberately does not touch `students/{id}.absentOn`, and the
  /// UI must not claim it does.** firestore.rules' `students/{studentId}`
  /// rules grant that field to exactly two writers: a school admin (via the
  /// blanket `allow write: if isSchoolAdmin(schoolId)`) and a parent
  /// *linked to that student* (`request.auth.uid in resource.data.parentIds`,
  /// narrowed to `['absentOn', 'updatedAt']`). A driver is neither, so
  /// attempting that update would fail with permission-denied — and a
  /// silently-failing button is worse than an honest one.
  ///
  /// What a driver *can* write is the school's `absenceLog`
  /// (`allow create: if isActiveMember(schoolId) &&
  /// request.resource.data.recordedBy == request.auth.uid`), which is the
  /// same durable, admin-readable record the parent app's
  /// `StudentsRepository.setAbsent` appends alongside its own `absentOn`
  /// update — and the only history an admin's attendance report reads,
  /// since `absentOn` itself only ever holds *today's* value. So a
  /// driver-reported absence reaches the school through the identical
  /// channel a parent-reported one does; it just doesn't flip the flag on
  /// the student record. `source: 'driver'` distinguishes the two for
  /// whoever reads the log.
  ///
  /// Note that a driver cannot read `absenceLog` back either (it's
  /// admin-only for read), which is why the caller keeps its own
  /// session-local record of what it successfully reported rather than
  /// watching a stream.
  Future<void> reportAbsence({
    required String schoolId,
    required String studentId,
    required String studentName,
  }) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final date = todayIsoDate();
    final schoolRef = _firestore.collection('schools').doc(schoolId);
    final batch = _firestore.batch();
    batch.set(schoolRef.collection('absenceLog').doc(), {
      'studentId': studentId,
      'studentName': studentName,
      'date': date,
      'recordedBy': uid,
      'source': 'driver',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Feature: absence data integrity — see the parent app's
    // StudentsRepository.setAbsent for the full rationale. Upserted into
    // the SAME canonical doc a parent's own report for this student/day
    // would use, so a driver and a parent both reporting the same absence
    // (or a driver reporting one the same day a parent later un-marks)
    // settles on one final state instead of double-counting.
    batch.set(
      schoolRef.collection('attendanceRecords').doc(
        AttendanceRecord.idFor(studentId: studentId, date: date),
      ),
      AttendanceRecord(
        studentId: studentId,
        schoolId: schoolId,
        date: date,
        isAbsent: true,
        updatedBy: uid,
        studentName: studentName,
      ).toMap(),
      SetOptions(merge: true),
    );
    return batch.commit();
  }
}
