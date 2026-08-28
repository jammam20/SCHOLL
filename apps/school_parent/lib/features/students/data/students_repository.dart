import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  CollectionReference<Map<String, dynamic>> _absenceLog(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('absenceLog');
  }
}
