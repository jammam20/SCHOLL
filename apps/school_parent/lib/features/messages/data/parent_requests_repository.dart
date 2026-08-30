import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// A parent's side of the parent -> school -> driver channel (Feature:
/// Parent–Driver communication).
///
/// There is deliberately no direct parent-to-driver path anywhere in this
/// app: a parent writes to `schools/{schoolId}/parentRequests`, their
/// school's admin reads it and passes on whatever the driver needs.
/// firestore.rules enforces that shape — a parent may create only their own
/// `open` thread and read only their own back; no driver rule grants read
/// access to this collection at all.
///
/// A thread is a real, continuing conversation: the opening message is
/// written both onto the thread doc itself (for a cheap list preview) and
/// as the first entry in its `messages` subcollection, so the chat view can
/// render the whole conversation uniformly by reading only that
/// subcollection.
class ParentRequestsRepository {
  ParentRequestsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> submitRequest({
    required String schoolId,
    required String parentUid,
    required String subject,
    required String message,
    String? studentId,
    String? studentName,
    String? tripId,
  }) async {
    final trimmed = message.trim();
    final ref = _requests(schoolId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'schoolId': schoolId,
      'parentUid': parentUid,
      'subject': subject,
      'message': trimmed,
      'status': ParentRequestStatus.open.value,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': trimmed,
      'unreadByAdmin': true,
      'unreadByParent': false,
      'studentId': ?studentId,
      'studentName': ?studentName,
      'tripId': ?tripId,
    });
    batch.set(ref.collection('messages').doc(), {
      'senderUid': parentUid,
      'senderRole': 'parent',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return ref.id;
  }

  /// Appends a follow-up message to an existing thread — this is what makes
  /// it a real conversation instead of a one-shot request. The
  /// onParentMessageCreated Cloud Function updates the thread's own
  /// lastMessageAt/lastMessagePreview/unread flags; this only ever writes
  /// the message itself.
  Future<void> sendMessage({
    required String schoolId,
    required String requestId,
    required String parentUid,
    required String text,
  }) {
    final trimmed = text.trim();
    return _requests(schoolId).doc(requestId).collection('messages').doc().set({
      'senderUid': parentUid,
      'senderRole': 'parent',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// This parent's own threads, newest-activity first.
  ///
  /// The `parentUid` equality filter isn't optional — the read rule is
  /// `resource.data.parentUid == request.auth.uid`, and Firestore rejects
  /// any query it can't prove satisfies that up front (the same reason
  /// TripsRepository.watchMyStudents filters on `parentIds`).
  ///
  /// Sorting happens client-side rather than with `orderBy` — combining
  /// that with the equality filter would need a new composite index, and
  /// this is one parent's own handful of threads, not a feed.
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
          requests.sort(
            (a, b) => (b.lastMessageAt ?? b.createdAt)
                .compareTo(a.lastMessageAt ?? a.createdAt),
          );
          return requests;
        });
  }

  Stream<List<ParentThreadMessage>> watchMessages({
    required String schoolId,
    required String requestId,
  }) {
    return _requests(schoolId)
        .doc(requestId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ParentThreadMessage.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Clears this parent's own unread flag on opening the thread — the
  /// admin's unread flag is only ever cleared server-side/by the admin.
  Future<void> markReadByParent({
    required String schoolId,
    required String requestId,
  }) {
    return _requests(schoolId).doc(requestId).update({'unreadByParent': false});
  }

  CollectionReference<Map<String, dynamic>> _requests(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('parentRequests');
  }
}
