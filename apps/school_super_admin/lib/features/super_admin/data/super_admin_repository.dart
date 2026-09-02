import 'package:cloud_firestore/cloud_firestore.dart';

/// Everything the Super Admin panel needs: creating schools (without ever
/// touching the Firebase Console) and approving the very first admin of
/// each one. Every write here is only reachable by an active
/// `systemAdmins/{uid}` document — see firestore.rules.
class SuperAdminRepository {
  SuperAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSchools() {
    return _firestore.collection('schools').orderBy('name').snapshots();
  }

  /// Creates a school and its join code together — the code is what a
  /// school's owner then types into the admin app's "Create admin account"
  /// screen to self-register as that school's first (pending) admin.
  Future<void> createSchool({
    required String name,
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final ref = _firestore.collection('schools').doc();

    final batch = _firestore.batch();
    batch.set(ref, {
      'id': ref.id,
      'name': name.trim(),
      'code': normalizedCode,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('schoolJoinCodes').doc(normalizedCode), {
      'schoolId': ref.id,
      'active': true,
    });
    await batch.commit();
  }

  Future<void> setSchoolActive({
    required String schoolId,
    required bool active,
  }) {
    return _firestore.collection('schools').doc(schoolId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Every pending 'admin' membership across every school — a collection
  /// group query, matched against the same per-document `members/{uid}`
  /// read rule as everywhere else (a system admin is granted read there
  /// regardless of which school the document belongs to).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingAdmins() {
    return _firestore
        .collectionGroup('members')
        .where('role', isEqualTo: 'admin')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> _setAdminStatus({
    required String schoolId,
    required String uid,
    required String status,
    String? reason,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('members')
        .doc(uid)
        .update({
          'status': status,
          'isActive': status == 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
          if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
        });
  }

  Future<void> approveAdmin({required String schoolId, required String uid}) {
    return _setAdminStatus(schoolId: schoolId, uid: uid, status: 'approved');
  }

  Future<void> rejectAdmin({
    required String schoolId,
    required String uid,
    String? reason,
  }) {
    return _setAdminStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'rejected',
      reason: reason,
    );
  }
}
