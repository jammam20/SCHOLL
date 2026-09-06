import '../enums/community_post_category.dart';
import '../enums/community_post_status.dart';

/// One post in a school's anonymous parent community feed (Feature: Parent
/// Community), at `schools/{schoolId}/communityPosts/{id}`.
///
/// Deliberately carries no author identity of any kind — not even a UID.
/// The one place that mapping exists is the admin-only `authors/post`
/// subcollection document (see firestore.rules), which this model doesn't
/// even attempt to represent: nothing parent-facing should ever need it,
/// and the admin surfaces that do resolve it via a separate, explicit read
/// (`CommunityPostAuthor`) rather than smuggling it in here where every
/// other parent's feed query would otherwise receive it too.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.schoolId,
    required this.category,
    required this.content,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.reportCount = 0,
  });

  final String id;
  final String schoolId;
  final CommunityPostCategory category;
  final String content;
  final CommunityPostStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int reactionCount;
  final int commentCount;
  final int reportCount;

  factory CommunityPost.fromMap(String id, Map<String, dynamic> data) {
    return CommunityPost(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      category:
          CommunityPostCategoryX.tryParse(data['category']) ??
          CommunityPostCategory.other,
      content: data['content'] as String? ?? '',
      status:
          CommunityPostStatusX.tryParse(data['status']) ??
          CommunityPostStatus.active,
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(data['updatedAt']),
      reactionCount: (data['reactionCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue.toDate();
      return result is DateTime ? result : null;
    } catch (_) {
      return null;
    }
  }
}

/// One comment on a [CommunityPost], at
/// `schools/{schoolId}/communityPosts/{postId}/comments/{id}`. Carries no
/// *parent* author identity for exactly the same reason [CommunityPost]
/// doesn't — but [isAdmin] is a deliberate exception: an admin's own reply
/// is the one voice this feature never anonymizes (it's the school
/// answering, not a parent), so it's a plain flag right on the comment
/// rather than routed through the `authors` subcollection parents use.
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.content,
    required this.createdAt,
    this.isAdmin = false,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final bool isAdmin;

  factory CommunityComment.fromMap(String id, Map<String, dynamic> data) {
    return CommunityComment(
      id: id,
      content: data['content'] as String? ?? '',
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      isAdmin: data['isAdmin'] == true,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue.toDate();
      return result is DateTime ? result : null;
    } catch (_) {
      return null;
    }
  }
}

/// The admin-only identity behind a post or comment, at
/// `schools/{schoolId}/communityPosts/{postId}/authors/{'post'|commentId}`
/// — see firestore.rules for why this lives in its own document instead of
/// a field on the post/comment itself. Never constructed from a
/// parent-readable snapshot; only the admin app's own resolver reads this.
class CommunityPostAuthor {
  const CommunityPostAuthor({required this.authorUid, required this.createdAt});

  final String authorUid;
  final DateTime createdAt;

  factory CommunityPostAuthor.fromMap(Map<String, dynamic> data) {
    return CommunityPostAuthor(
      authorUid: data['authorUid'] as String? ?? '',
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue.toDate();
      return result is DateTime ? result : null;
    } catch (_) {
      return null;
    }
  }
}
