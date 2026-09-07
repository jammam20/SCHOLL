import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

class StudentsRepository {
  StudentsRepository({
    FirebaseFirestore? firestore,
    AuditLogRepository? auditLog,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

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

  // A server-side count (not a full document fetch) of how many active
  // students are currently assigned to [routeId] — Feature: bus capacity
  // check, used by the admin's "Add trip" dialog to warn when the chosen
  // bus seats fewer students than the route actually carries. `isActive`
  // only, matching every other "who's really riding this route today"
  // count elsewhere (an archived student was never going to board). A
  // one-shot count rather than a live stream — this only ever backs a
  // save-time guard in a dialog, not something that needs to react to a
  // student being reassigned by someone else while it happens to be open.
  Future<int> countRouteStudents(String schoolId, String routeId) async {
    final snapshot = await _students(schoolId)
        .where('routeId', isEqualTo: routeId)
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
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
      // A student an admin creates directly needs no pending-review step —
      // unlike StudentsRepository.addChild in the parent app, which writes
      // `approved: false` for a parent's own self-added child awaiting
      // admin review. Omitting this field entirely (the previous bug here)
      // reads back as "approved" everywhere in the app, since
      // Student.fromMap treats anything other than the literal `false` as
      // approved (`data['approved'] != false`) — but firestore.rules'
      // field-restricted parent-write rules (absence, scheduled absences,
      // authorized pickup persons, location proposals) all require
      // `resource.data.approved == true` *exactly*, and a genuinely missing
      // field is not `true`. That mismatch silently rejected every one of
      // those writes with a permission-denied for every student created
      // through this normal, everyday path — while the UI showed no
      // warning and, for authorized-pickup-persons specifically, actively
      // reported success (a second bug — see child_settings_page.dart's
      // _addPickupPerson).
      'approved': true,
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

  /// Accepts a parent's proposed pickup/drop-off location (Feature: Parent
  /// can add child location) — copies `pendingLatitude`/`pendingLongitude`
  /// onto the official `latitude`/`longitude` and clears the pending
  /// fields, in one write, so the two can never disagree mid-operation.
  Future<void> acceptLocationRequest({
    required String schoolId,
    required String studentId,
    required double latitude,
    required double longitude,
  }) async {
    await _students(schoolId).doc(studentId).update({
      'latitude': latitude,
      'longitude': longitude,
      'pendingLatitude': null,
      'pendingLongitude': null,
      'pendingLocationRequestedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.studentLocationRequestAccepted,
      entityType: 'student',
      entityId: studentId,
      studentId: studentId,
      metadata: {'latitude': latitude, 'longitude': longitude},
    );
  }

  /// Rejects a parent's proposed location — clears the pending fields only,
  /// leaving the official location (if any) exactly as it was.
  Future<void> rejectLocationRequest({
    required String schoolId,
    required String studentId,
  }) async {
    await _students(schoolId).doc(studentId).update({
      'pendingLatitude': null,
      'pendingLongitude': null,
      'pendingLocationRequestedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.studentLocationRequestRejected,
      entityType: 'student',
      entityId: studentId,
      studentId: studentId,
    );
  }
}
