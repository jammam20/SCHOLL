import 'package:cloud_firestore/cloud_firestore.dart';

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

  CollectionReference<Map<String, dynamic>> _members(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection(
      'members',
    );
  }

  // `limit` keeps this from reading every student in the school on every
  // page load — the admin_home_page._StudentsTab UI bumps it by
  // _pageSize each time "Load more" is tapped rather than fetching
  // everything up front.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchStudents(
    String schoolId, {
    int limit = 30,
  }) {
    return _students(schoolId).orderBy('name').limit(limit).snapshots();
  }

  // Uses the same (role ASC, displayName ASC) composite index as the
  // driver list — 'approved' filtering happens client-side so this doesn't
  // need its own index.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchParentMembers(
    String schoolId,
  ) {
    return _members(
      schoolId,
    ).where('role', isEqualTo: 'parent').orderBy('displayName').snapshots();
  }

  Future<void> assignRoute({
    required String schoolId,
    required String studentId,
    required String? routeId,
  }) {
    return _students(schoolId).doc(studentId).update({
      'routeId': routeId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> linkParent({
    required String schoolId,
    required String studentId,
    required String parentUid,
  }) {
    return _students(schoolId).doc(studentId).update({
      'parentIds': FieldValue.arrayUnion([parentUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlinkParent({
    required String schoolId,
    required String studentId,
    required String parentUid,
  }) {
    return _students(schoolId).doc(studentId).update({
      'parentIds': FieldValue.arrayRemove([parentUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createStudent({
    required String schoolId,
    required String name,
    required String grade,
    String? parentId,
    String? phone,
  }) async {
    final ref = _students(schoolId).doc();

    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'name': name.trim(),
      'grade': grade.trim(),
      'parentId': parentId,
      'phone': phone?.trim(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> updateStudent({
    required String schoolId,
    required String studentId,
    required Map<String, dynamic> data,
  }) {
    return _students(schoolId)
        .doc(studentId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> setStudentActive({
    required String schoolId,
    required String studentId,
    required bool active,
  }) {
    return _students(schoolId).doc(studentId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveStudent({
    required String schoolId,
    required String studentId,
  }) {
    return _students(schoolId).doc(studentId).update({
      'approved': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Rejecting a parent-added child just removes the (unapproved, so not yet
  // visible to anyone but its parent) request outright rather than leaving
  // a permanently-rejected record around.
  Future<void> deleteStudent({
    required String schoolId,
    required String studentId,
  }) {
    return _students(schoolId).doc(studentId).delete();
  }
}
