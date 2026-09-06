/// One immutable operational audit record. `action` is a free-form,
/// well-known string constant (see [AuditActions]) rather than a closed
/// enum — this deliberately mirrors the existing `trips/{tripId}/events`
/// subcollection's own `type` string-field convention, so audit logging
/// slots in next to a pattern this codebase already uses instead of
/// inventing a second one. Stored at `schools/{schoolId}/auditLog/{id}`;
/// firestore.rules allows `create` only (never update/delete) so a written
/// entry can never be altered after the fact.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.schoolId,
    required this.actorUid,
    required this.actorRole,
    required this.action,
    required this.timestamp,
    this.entityType,
    this.entityId,
    this.tripId,
    this.busId,
    this.driverId,
    this.studentId,
    this.metadata = const {},
  });

  final String id;
  final String schoolId;
  final String actorUid;
  final String actorRole;
  final String action;
  final DateTime timestamp;
  final String? entityType;
  final String? entityId;
  final String? tripId;
  final String? busId;
  final String? driverId;
  final String? studentId;
  final Map<String, dynamic> metadata;

  factory AuditLogEntry.fromMap(String id, Map<String, dynamic> data) {
    return AuditLogEntry(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? '',
      action: data['action'] as String? ?? '',
      timestamp: _asDateTime(data['timestamp']) ?? DateTime.now(),
      entityType: data['entityType'] as String?,
      entityId: data['entityId'] as String?,
      tripId: data['tripId'] as String?,
      busId: data['busId'] as String?,
      driverId: data['driverId'] as String?,
      studentId: data['studentId'] as String?,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? const {}),
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

/// Well-known audit action strings — a growing, non-exhaustive list rather
/// than a closed enum (see class doc). Add more as new call sites need
/// them; nothing structurally requires an action to be one of these.
abstract final class AuditActions {
  static const tripStarted = 'trip_started';
  static const tripCompleted = 'trip_completed';
  static const tripCancelled = 'trip_cancelled';
  static const stopReached = 'stop_reached';
  static const studentBoarded = 'student_boarded';
  static const studentDroppedOff = 'student_dropped_off';
  static const deviationStarted = 'deviation_started';
  static const deviationEnded = 'deviation_ended';
  static const incidentReported = 'incident_reported';
  static const incidentAcknowledged = 'incident_acknowledged';
  static const incidentResolved = 'incident_resolved';
  static const emergencyRaised = 'emergency_raised';
  static const emergencyResolved = 'emergency_resolved';
  static const busReassigned = 'bus_reassigned';
  static const driverReassigned = 'driver_reassigned';
  static const pickupVerified = 'pickup_verified';
  static const pickupVerificationFailed = 'pickup_verification_failed';
  // A verification attempt that is neither a pass nor a fail: the record
  // exists (PickupVerificationStatus.pending) but nothing has actually
  // checked the presented code yet. Needed so the driver app's qrCode/otp
  // methods can be audited honestly instead of borrowing `pickupVerified`,
  // which would claim a check that didn't happen.
  static const pickupVerificationPending = 'pickup_verification_pending';
  static const inspectionCompleted = 'inspection_completed';
  static const inspectionFailed = 'inspection_failed';
  // Feature: Parent can add child location.
  static const studentLocationRequestSubmitted = 'student_location_request_submitted';
  static const studentLocationRequestAccepted = 'student_location_request_accepted';
  static const studentLocationRequestRejected = 'student_location_request_rejected';
  // Feature: unified accept/reject UI.
  static const studentRequestRejected = 'student_request_rejected';
  // Feature: Parent Community.
  static const communityPostHidden = 'community_post_hidden';
  static const communityPostRestored = 'community_post_restored';
  static const communityPostArchived = 'community_post_archived';
  static const communityPostDeleted = 'community_post_deleted';
  static const communityReportResolved = 'community_report_resolved';
}
