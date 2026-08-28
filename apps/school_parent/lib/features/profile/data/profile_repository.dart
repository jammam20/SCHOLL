import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Keeps a signed-in member's display name in sync across the two places
/// it's stored: `users/{uid}.name` (read by AppUser) and the denormalized
/// `schools/{id}/members/{uid}.displayName` (read by the admin app's
/// directory lists) — both self-writes are narrowly scoped in
/// firestore.rules to just that one field, same pattern as every other
/// self-service write in this project.
class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> updateName({required String schoolId, required String name}) {
    final uid = _auth.currentUser?.uid;
    final trimmed = name.trim();
    if (uid == null || trimmed.isEmpty) return Future.value();

    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'name': trimmed,
      'updatedAt': now,
    });
    batch.update(
      _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('members')
          .doc(uid),
      {'displayName': trimmed, 'updatedAt': now},
    );
    return batch.commit();
  }
}
