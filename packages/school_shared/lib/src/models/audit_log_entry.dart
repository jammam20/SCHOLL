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
  // Feature: Secure Student Pickup — who a parent has authorized to
  // collect their child (Production hardening: complete audit trail).
  static const authorizedPickupPersonsUpdated = 'authorized_pickup_persons_updated';
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

  // Driver-triggered trip lifecycle (Production hardening: complete audit
  // trail). Distinct from the trip's own write-only `events` subcollection
  // — that one is a per-trip technical log; these are the school-wide,
  // filterable audit-trail entries an admin actually reviews.
  static const tripPaused = 'trip_paused';
  static const tripResumed = 'trip_resumed';

  // Bus capacity enforcement (Production hardening).
  static const boardingRejectedCapacity = 'boarding_rejected_capacity';

  // Admin-driven membership lifecycle (Production hardening: complete audit
  // trail) — approve/suspend/reject already had a UI promise ("visible in
  // the audit log") that these repositories previously never fulfilled.
  static const driverApproved = 'driver_approved';
  static const driverSuspended = 'driver_suspended';
  static const driverRejected = 'driver_rejected';
  static const parentApproved = 'parent_approved';
  static const parentSuspended = 'parent_suspended';
  static const parentRejected = 'parent_rejected';

  // Admin-driven student lifecycle (Production hardening).
  static const studentApproved = 'student_approved';
  static const studentCreated = 'student_created';
  static const studentUpdated = 'student_updated';
  static const studentArchived = 'student_archived';
  static const studentRestored = 'student_restored';

  // Fleet/route configuration (Production hardening).
  static const busCreated = 'bus_created';
  static const busUpdated = 'bus_updated';
  static const busArchived = 'bus_archived';
  static const busRestored = 'bus_restored';
  static const routeCreated = 'route_created';
  static const routeUpdated = 'route_updated';
  static const routeArchived = 'route_archived';
  static const routeRestored = 'route_restored';

  // Admin-driven trip lifecycle (Production hardening) — `tripStarted`/
  // `tripCompleted`/`tripCancelled` above are the driver's own transitions;
  // these cover the two operations only an admin performs.
  static const tripCreated = 'trip_created';
  static const tripCancelledByAdmin = 'trip_cancelled_by_admin';

  // School operational configuration (Production hardening).
  static const schoolSettingsUpdated = 'school_settings_updated';
  static const schoolLocationUpdated = 'school_location_updated';

  // Super Admin platform-level actions (Production hardening) — written
  // into the *target* school's own auditLog (actorRole 'systemAdmin')
  // rather than a second audit system; see firestore.rules' auditLog
  // create rule, which grants isSystemAdmin() the same append access every
  // active member of that school already has for their own actions.
  static const schoolCreated = 'school_created';
  static const schoolActivated = 'school_activated';
  static const schoolDeactivated = 'school_deactivated';
  static const schoolAdminApproved = 'school_admin_approved';
  static const schoolAdminRejected = 'school_admin_rejected';
}
