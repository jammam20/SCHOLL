import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// The parent's side of the anonymous school community feed (Feature:
/// Parent Community).
///
/// Every write here is deliberately a sequence of two awaited writes, never
/// a single batch — mirroring [ParentRequestsRepository]'s own documented
/// reason: several of these rules read a sibling document back via `get()`/
/// `exists()` (the reaction toggle's counter update, in particular), and a
/// batched write gives security rules no guarantee of seeing another write
/// from the *same* batch. Writing the first document and waiting for it to
/// actually commit means the second write's rule reads reality, not a
/// still-pending intent.
///
/// Nothing here ever reads or exposes an author's identity — that mapping
/// lives only in the admin-only `authors` subcollection (see
/// firestore.rules), which this repository writes to but never reads back.
class CommunityRepository {
  CommunityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _posts(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('communityPosts');
  }

  /// The school's active feed, newest first. `category` narrows to one
  /// topic; both `where` clauses are plain equality (no `orderBy` on a
  /// different field), so this never needs a new composite index — sorting
  /// happens client-side instead, exactly like [ParentRequestsRepository]'s
  /// own small-collection reads.
  Stream<List<CommunityPost>> watchFeed({
    required String schoolId,
    CommunityPostCategory? category,
  }) {
    Query<Map<String, dynamic>> query = _posts(
      schoolId,
    ).where('status', isEqualTo: CommunityPostStatus.active.value);
    if (category != null) {
      query = query.where('category', isEqualTo: category.value);
    }
    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => CommunityPost.fromMap(doc.id, doc.data()))
          .toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Future<void> createPost({
    required String schoolId,
    required String parentUid,
    required CommunityPostCategory category,
    required String content,
  }) async {
    final trimmed = content.trim();
    final ref = _posts(schoolId).doc();
    await ref.set({
      'schoolId': schoolId,
      'category': category.value,
      'content': trimmed,
      'status': CommunityPostStatus.active.value,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reactionCount': 0,
      'commentCount': 0,
      'reportCount': 0,
    });
    await ref.collection('authors').doc('post').set({
      'authorUid': parentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CommunityComment>> watchComments({
    required String schoolId,
    required String postId,
  }) {
    return _posts(schoolId)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommunityComment.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addComment({
    required String schoolId,
    required String postId,
    required String parentUid,
    required String content,
  }) async {
    final trimmed = content.trim();
    final postRef = _posts(schoolId).doc(postId);
    final commentRef = postRef.collection('comments').doc();
    await commentRef.set({
      'content': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await postRef.collection('authors').doc(commentRef.id).set({
      'authorUid': parentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await postRef.update({
      'commentCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Whether the signed-in parent has already reacted to this post — read
  /// straight from the fixed-id `reactions/{uid}` doc rather than a count,
  /// so the reaction button's own state never disagrees with what a second
  /// tap would actually do.
  Stream<bool> watchMyReaction({
    required String schoolId,
    required String postId,
    required String uid,
  }) {
    return _posts(schoolId)
        .doc(postId)
        .collection('reactions')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> toggleReaction({
    required String schoolId,
    required String postId,
    required String uid,
    required bool currentlyReacted,
  }) async {
    final postRef = _posts(schoolId).doc(postId);
    final reactionRef = postRef.collection('reactions').doc(uid);
    if (currentlyReacted) {
      await reactionRef.delete();
      await postRef.update({
        'reactionCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reactionRef.set({'createdAt': FieldValue.serverTimestamp()});
      await postRef.update({
        'reactionCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> reportPost({
    required String schoolId,
    required String postId,
    required String reporterUid,
    required CommunityReportReason reason,
    String? details,
  }) async {
    final postRef = _posts(schoolId).doc(postId);
    final reportRef = postRef.collection('reports').doc();
    await reportRef.set({
      'reporterUid': reporterUid,
      'reason': reason.value,
      'status': CommunityReportStatus.open.value,
      'createdAt': FieldValue.serverTimestamp(),
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    });
    await postRef.update({
      'reportCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
