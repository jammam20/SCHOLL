import 'package:cloud_firestore/cloud_firestore.dart';

class DriversRepository {
  DriversRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _members(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('members');
  }

  // `limit` keeps this from reading every driver in the school on every
  // page load — the admin_home_page._DriversTab UI bumps it by _pageSize
  // each time "Load more" is tapped rather than fetching everything up
  // front.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchDrivers(
    String schoolId, {
    int limit = 30,
  }) {
    return _members(schoolId)
        .where('role', isEqualTo: 'driver')
        // Member documents only ever carry `displayName` (set at
        // self-registration — see FirebaseAuthRepository.registerDriver in
        // the driver app), not `name`. Must match the composite index in
        // firestore.indexes.json (role ASC, displayName ASC).
        .orderBy('displayName')
        .limit(limit)
        .snapshots();
  }

  // firestore.rules scopes a member `update` to a school admin touching
  // only status/isActive/updatedAt (see the `members/{uid}` rule) — a
  // direct write, not a callable, now that a Cloud Function isn't required
  // just to approve a driver.
  Future<void> _setStatus({
    required String schoolId,
    required String uid,
    required String status,
    String? reason,
  }) {
    return _members(schoolId).doc(uid).update({
      'status': status,
      'isActive': status == 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
      // Feature: unified accept/reject UI — recorded alongside status so a
      // suspend/reject carries its own "why" (see PendingApprovalCard),
      // rather than only living in the moment's audit-log entry.
      if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
    });
  }

  Future<void> approveDriver({required String schoolId, required String uid}) {
    return _setStatus(schoolId: schoolId, uid: uid, status: 'approved');
  }

  Future<void> suspendDriver({
    required String schoolId,
    required String uid,
    String? reason,
  }) {
    return _setStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'suspended',
      reason: reason,
    );
  }

  Future<void> rejectDriver({
    required String schoolId,
    required String uid,
    String? reason,
  }) {
    return _setStatus(
      schoolId: schoolId,
      uid: uid,
      status: 'rejected',
      reason: reason,
    );
  }
}
