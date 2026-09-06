/// A community post report's triage state (Feature: Parent Community).
/// Deliberately the same 2-step shape as [EmergencyStatus] rather than
/// [IncidentStatus]'s 3-step one — a report doesn't need a separate
/// "someone has seen this" signal before resolution.
enum CommunityReportStatus { open, resolved }

extension CommunityReportStatusX on CommunityReportStatus {
  String get value => name;

  static CommunityReportStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in CommunityReportStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}
