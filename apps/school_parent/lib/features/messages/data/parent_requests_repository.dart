import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// A parent's side of the parent -> school -> driver channel (Feature:
/// Parent–Driver communication).
///
/// There is deliberately no direct parent-to-driver path anywhere in this
/// app: a parent writes a request to `schools/{schoolId}/parentRequests`,
/// their school's admin reads it and passes on whatever the driver needs.
/// firestore.rules enforces that shape — a parent may create only their own
/// `open` request and read only their own back; no driver rule grants read
/// access to this collection at all.
class ParentRequestsRepository {
  ParentRequestsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Submits one request. `parentUid` is self-attested exactly like
  /// `absenceLog.recordedBy` — the create rule rejects any other uid — and
  /// `status` starts at `open` because that's the only value the rule
  /// accepts on create; moving it on is an admin action.
  Future<String> submitRequest({
    required String schoolId,
    required String parentUid,
    required String message,
    String? studentId,
    String? studentName,
    String? tripId,
  }) async {
    final ref = _requests(schoolId).doc();
    await ref.set({
      'schoolId': schoolId,
      'parentUid': parentUid,
      'message': message.trim(),
      'status': ParentRequestStatus.open.value,
      'createdAt': FieldValue.serverTimestamp(),
      'studentId': ?studentId,
      'studentName': ?studentName,
      'tripId': ?tripId,
    });
    return ref.id;
  }

  /// This parent's own requests, newest first.
  ///
  /// The `parentUid` equality filter isn't optional — the read rule is
  /// `resource.data.parentUid == request.auth.uid`, and Firestore rejects
  /// any query it can't prove satisfies that up front (the same reason
  /// TripsRepository.watchMyStudents filters on `parentIds`).
  ///
  /// Sorting happens client-side rather than with `orderBy('createdAt')`:
  /// combining that with the equality filter would require a new composite
  /// index in `firebase/firestore.indexes.json`, and the result set here is
  /// one parent's own handful of messages, not a feed.
  Stream<List<ParentRequest>> watchMyRequests({
    required String schoolId,
    required String parentUid,
  }) {
    return _requests(schoolId)
        .where('parentUid', isEqualTo: parentUid)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => ParentRequest.fromMap(doc.id, doc.data()))
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  CollectionReference<Map<String, dynamic>> _requests(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('parentRequests');
  }
}
