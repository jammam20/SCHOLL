import '../enums/community_report_reason.dart';
import '../enums/community_report_status.dart';

/// A parent's report against a [CommunityPost] (Feature: Parent Community),
/// at `schools/{schoolId}/communityPosts/{postId}/reports/{id}`. Admin-only
/// read by firestore.rules — not even visible back to the reporter.
class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.postId,
    required this.reporterUid,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.details,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String postId;
  final String reporterUid;
  final CommunityReportReason reason;
  final CommunityReportStatus status;
  final DateTime createdAt;
  final String? details;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  factory CommunityReport.fromMap(
    String id,
    String postId,
    Map<String, dynamic> data,
  ) {
    return CommunityReport(
      id: id,
      postId: postId,
      reporterUid: data['reporterUid'] as String? ?? '',
      reason:
          CommunityReportReasonX.tryParse(data['reason']) ??
          CommunityReportReason.other,
      status:
          CommunityReportStatusX.tryParse(data['status']) ??
          CommunityReportStatus.open,
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      details: data['details'] as String?,
      resolvedAt: _asDateTime(data['resolvedAt']),
      resolvedBy: data['resolvedBy'] as String?,
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
