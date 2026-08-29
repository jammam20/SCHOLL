import '../enums/reassignment_type.dart';

/// An audit-preserving record of a last-minute change to a trip (bus swap,
/// driver swap, route change, stop skipped) — written *in addition to* the
/// trip's own field update, never in place of it, so a trip's history of
/// changes survives even though the trip document itself only holds the
/// current values. Stored at `schools/{schoolId}/trips/{tripId}/reassignments/{id}`.
class ReassignmentRecord {
  const ReassignmentRecord({
    required this.id,
    required this.schoolId,
    required this.tripId,
    required this.type,
    required this.changedBy,
    required this.changedAt,
    this.fromValue,
    this.toValue,
    this.reason,
  });

  final String id;
  final String schoolId;
  final String tripId;
  final ReassignmentType type;
  final String changedBy;
  final DateTime changedAt;
  final String? fromValue;
  final String? toValue;
  final String? reason;

  factory ReassignmentRecord.fromMap(String id, Map<String, dynamic> data) {
    return ReassignmentRecord(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      type: ReassignmentTypeX.tryParse(data['type']) ?? ReassignmentType.busReassigned,
      changedBy: data['changedBy'] as String? ?? '',
      changedAt: _asDateTime(data['changedAt']) ?? DateTime.now(),
      fromValue: data['fromValue'] as String?,
      toValue: data['toValue'] as String?,
      reason: data['reason'] as String?,
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
