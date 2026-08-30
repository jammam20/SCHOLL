import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// The admin's side of the parent -> school -> driver channel (Feature:
/// Parent–Driver communication). This is the piece that was missing
/// entirely: a parent could already submit a request, but no admin surface
/// ever read it back — this repository backs the admin inbox that does.
class ParentMessagesRepository {
  ParentMessagesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Every thread in the school, newest-activity first. Sorted client-side
  /// (this is a school's own inbox, not a cross-school feed, so it stays
  /// small enough not to need a composite index for it).
  Stream<List<ParentRequest>> watchThreads(String schoolId) {
    return _requests(schoolId).snapshots().map((snapshot) {
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

  Stream<int> watchUnreadCount(String schoolId) {
    return _requests(schoolId)
        .where('unreadByAdmin', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
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

  Future<void> sendMessage({
    required String schoolId,
    required String requestId,
    required String adminUid,
    required String text,
  }) {
    return _requests(schoolId).doc(requestId).collection('messages').doc().set({
      'senderUid': adminUid,
      'senderRole': 'admin',
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clears the admin's own unread flag and marks the thread seen — the
  /// parent's own unread flag is only ever cleared client-side by the
  /// parent, or server-side when the admin replies (onParentMessageCreated).
  Future<void> markRead({
    required String schoolId,
    required String requestId,
    required String adminUid,
  }) {
    return _requests(schoolId).doc(requestId).update({
      'unreadByAdmin': false,
      'status': ParentRequestStatus.read.value,
      'readBy': adminUid,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> closeThread({
    required String schoolId,
    required String requestId,
  }) {
    return _requests(schoolId).doc(requestId).update({
      'status': ParentRequestStatus.closed.value,
    });
  }

  CollectionReference<Map<String, dynamic>> _requests(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('parentRequests');
  }
}
