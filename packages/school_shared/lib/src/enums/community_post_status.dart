/// A community post's moderation state (Feature: Parent Community).
///
/// [deleted] is deliberately still just a status value, never an actual
/// Firestore document delete — firestore.rules disallows `delete` on
/// `communityPosts` entirely, matching this project's existing preference
/// for an audit/history-preserving soft state over destructive removal
/// (see e.g. `students/{studentId}.isActive` or `TripStatus.cancelled`).
/// There is deliberately no state machine here (unlike [TripStatus]):
/// moderation is a single admin freely moving a post between any of these
/// four states, not a multi-party operational sequence with invalid
/// transitions to guard against.
enum CommunityPostStatus { active, hidden, archived, deleted }

extension CommunityPostStatusX on CommunityPostStatus {
  String get value => name;

  static CommunityPostStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in CommunityPostStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}
