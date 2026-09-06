import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

/// The admin's side of the school's anonymous-to-parents community feed
/// (Feature: Parent Community). Unlike [CommunityRepository] on the parent
/// side, an admin reads every status (not just `active`) and — the whole
/// point of this role — can resolve a post or comment's real author via
/// the admin-only `authors` subcollection that firestore.rules keeps
/// completely unreadable to any parent (see the rules file's own comment
/// on that collection).
class CommunityAdminRepository {
  CommunityAdminRepository({FirebaseFirestore? firestore, AuditLogRepository? auditLog})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _posts(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('communityPosts');
  }

  /// Every post in the school regardless of status, newest first.
  /// [statusFilter]/[categoryFilter] are both plain equality `where`
  /// clauses — combining the two never needs a new composite index (the
  /// same reasoning [CommunityRepository.watchFeed] documents), and sorting
  /// happens client-side.
  Stream<List<CommunityPost>> watchAllPosts({
    required String schoolId,
    CommunityPostStatus? statusFilter,
    CommunityPostCategory? categoryFilter,
    bool onlyReported = false,
  }) {
    Query<Map<String, dynamic>> query = _posts(schoolId);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }
    if (categoryFilter != null) {
      query = query.where('category', isEqualTo: categoryFilter.value);
    }
    if (onlyReported) {
      query = query.where('reportCount', isGreaterThan: 0);
    }
    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => CommunityPost.fromMap(doc.id, doc.data()))
          .toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  /// The real author behind a post (pass only [postId]) or one of its
  /// comments (also pass [commentId]) — `null` if the author doc somehow
  /// isn't there yet (never expected, but the read races the parent's own
  /// two-write create).
  Future<CommunityPostAuthor?> resolveAuthor({
    required String schoolId,
    required String postId,
    String? commentId,
  }) async {
    final doc = await _posts(schoolId)
        .doc(postId)
        .collection('authors')
        .doc(commentId ?? 'post')
        .get();
    final data = doc.data();
    if (data == null) return null;
    return CommunityPostAuthor.fromMap(data);
  }

  /// The member-directory display name for a resolved author uid — the
  /// same `members/{uid}.displayName` field [ParentDetailPage] itself reads,
  /// so this never duplicates or diverges from that page's own notion of a
  /// parent's name.
  Future<String?> resolveDisplayName({
    required String schoolId,
    required String uid,
  }) async {
    final doc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('members')
        .doc(uid)
        .get();
    return doc.data()?['displayName']?.toString();
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

  /// The admin's own reply on a post — the one voice this feature shows
  /// with a real identity (see [CommunityComment.isAdmin]), so unlike
  /// [CommunityRepository.addComment] this never touches the admin-only
  /// `authors` subcollection at all; there's no identity to resolve later.
  Future<void> addComment({
    required String schoolId,
    required String postId,
    required String content,
  }) async {
    final trimmed = content.trim();
    final postRef = _posts(schoolId).doc(postId);
    await postRef.collection('comments').doc().set({
      'content': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'isAdmin': true,
    });
    await postRef.update({
      'commentCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CommunityReport>> watchReports({
    required String schoolId,
    required String postId,
  }) {
    return _posts(schoolId)
        .doc(postId)
        .collection('reports')
        .snapshots()
        .map((snapshot) {
          final reports = snapshot.docs
              .map((doc) => CommunityReport.fromMap(doc.id, postId, doc.data()))
              .toList();
          reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reports;
        });
  }

  Future<void> changeStatus({
    required String schoolId,
    required String postId,
    required CommunityPostStatus status,
  }) async {
    await _posts(schoolId).doc(postId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final action = switch (status) {
      CommunityPostStatus.active => AuditActions.communityPostRestored,
      CommunityPostStatus.hidden => AuditActions.communityPostHidden,
      CommunityPostStatus.archived => AuditActions.communityPostArchived,
      CommunityPostStatus.deleted => AuditActions.communityPostDeleted,
    };
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: action,
      entityType: 'communityPost',
      entityId: postId,
    );
  }

  Future<void> resolveReport({
    required String schoolId,
    required String postId,
    required String reportId,
    required String adminUid,
  }) async {
    await _posts(schoolId).doc(postId).collection('reports').doc(reportId).update({
      'status': CommunityReportStatus.resolved.value,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': adminUid,
    });
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.communityReportResolved,
      entityType: 'communityReport',
      entityId: reportId,
      metadata: {'postId': postId},
    );
  }
}
