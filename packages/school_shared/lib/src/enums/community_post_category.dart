/// A community post's topic (Feature: Parent Community) — chosen by the
/// parent when composing, shown as a chip on the feed, and used by the
/// admin app's filter row.
enum CommunityPostCategory {
  busIssue,
  pickupPoint,
  delay,
  schoolIssue,
  suggestion,
  question,
  complaint,
  feedback,
  other,
}

extension CommunityPostCategoryX on CommunityPostCategory {
  // snake_case wire values, matching IncidentType's convention for
  // multi-word values; single-word values use `.name` as-is.
  String get value => switch (this) {
    CommunityPostCategory.busIssue => 'bus_issue',
    CommunityPostCategory.pickupPoint => 'pickup_point',
    CommunityPostCategory.schoolIssue => 'school_issue',
    _ => name,
  };

  static CommunityPostCategory? tryParse(Object? value) {
    if (value is! String) return null;
    for (final category in CommunityPostCategory.values) {
      if (category.value == value) return category;
    }
    return null;
  }
}
