import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/analytics.dart';

class StudentsRepository {
  StudentsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _students(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students');
  }

  /// Adds a child directly from the parent app — always pending admin
  /// approval (firestore.rules enforces `approved: false` and that the
  /// caller is the sole listed parent; a route/pickup point can't be set
  /// here either, only once the school approves the student and assigns
  /// them — see the `students/{studentId}` create rule).
  Future<String> addChild({
    required String schoolId,
    required String parentUid,
    required String name,
  }) async {
    final ref = _students(schoolId).doc();
    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'name': name.trim(),
      'isActive': true,
      'approved': false,
      'parentIds': [parentUid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    AppAnalytics.logChildAdded();
    return ref.id;
  }

  /// Marks (or clears) a student absent for one day — see
  /// Student.absentOn/isAbsentToday. Restricted by firestore.rules to just
  /// this field, for a parent linked to the student. `absentOn` only ever
  /// holds *today's* value (it's overwritten on the next change), so
  /// marking someone absent also appends a standalone log entry — the
  /// only durable record of attendance history the admin's reports can
  /// read.
  Future<void> setAbsent({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String? absentOn,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = _firestore.batch();
    batch.update(_students(schoolId).doc(studentId), {
      'absentOn': absentOn,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (absentOn != null && uid != null) {
      batch.set(_absenceLog(schoolId).doc(), {
        'studentId': studentId,
        'studentName': studentName,
        'date': absentOn,
        'recordedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  /// Replaces the whole `authorizedPickupPersons` list on a student —
  /// the people a parent has authorized to collect their own child
  /// (Feature: Secure Student Pickup).
  ///
  /// What this actually does, and nothing more: it records the parent's
  /// authorization on the student's own record so a driver can see the
  /// name they're expecting. It grants the named person no account, no
  /// login, and no access to this system, and it performs no identity
  /// check of its own — the only check that happens is whatever the driver
  /// does at the door against this list.
  ///
  /// Written as a whole-list replacement rather than an
  /// arrayUnion/arrayRemove because firestore.rules allow-lists the
  /// *fields* an update may touch, not the operations — and a full
  /// replacement is what makes "remove this person" expressible at all.
  /// Restricted by that rule to a parent of an already-approved student,
  /// and to this field plus `updatedAt`.
  Future<void> setAuthorizedPickupPersons({
    required String schoolId,
    required String studentId,
    required List<AuthorizedPickupPerson> persons,
  }) {
    return _students(schoolId).doc(studentId).update({
      'authorizedPickupPersons': persons.map((p) => p.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Replaces the whole `scheduledAbsenceDates` list on a student — future
  /// dates a parent has scheduled ahead of time (Feature: Student
  /// Ridership). Same whole-list-replacement shape as
  /// [setAuthorizedPickupPersons], for the same reason: firestore.rules
  /// allow-lists the field, not the operation, so a full replacement is
  /// what makes removing a date expressible at all.
  ///
  /// Prunes any date strictly before today before writing — a scheduled
  /// absence that's already in the past is just clutter for the parent to
  /// scroll past, and Student.isAbsentOn only ever checks a specific date
  /// anyway, so keeping past dates around serves no purpose.
  Future<void> setScheduledAbsences({
    required String schoolId,
    required String studentId,
    required List<String> dates,
  }) {
    final today = todayIsoDate();
    final pruned = dates.where((date) => date.compareTo(today) >= 0).toSet().toList()
      ..sort();
    return _students(schoolId).doc(studentId).update({
      'scheduledAbsenceDates': pruned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// A collision-free id for a newly added [AuthorizedPickupPerson].
  /// Firestore's own client-side id generator, taken from a document
  /// reference that is never written — cheaper and safer than hashing a
  /// timestamp, and identical to how [addChild] gets its student id.
  String newPickupPersonId(String schoolId) => _students(schoolId).doc().id;

  CollectionReference<Map<String, dynamic>> _absenceLog(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('absenceLog');
  }
}
