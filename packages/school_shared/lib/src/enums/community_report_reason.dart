/// Why a parent reported a community post (Feature: Parent Community).
enum CommunityReportReason {
  inappropriate,
  abuse,
  misleading,
  spam,
  other,
}

extension CommunityReportReasonX on CommunityReportReason {
  String get value => name;

  static CommunityReportReason? tryParse(Object? value) {
    if (value is! String) return null;
    for (final reason in CommunityReportReason.values) {
      if (reason.value == value) return reason;
    }
    return null;
  }
}
