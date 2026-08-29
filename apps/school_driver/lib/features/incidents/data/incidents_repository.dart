import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../../tracking/data/driver_tracking_repository.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../trips/domain/trip_operation_exception.dart';

/// Driver-filed operational incident reports, stored at
/// `schools/{schoolId}/incidents/{id}`.
///
/// Deliberately *not* routed through TripsBloc or EmergenciesRepository:
/// an incident must never flip the trip to [TripStatus.emergency]. That
/// escalation is what a raised SOS is for; a route-blocked or
/// student-behavior report is an operational note for the school, and
/// treating the two the same would either under-react to a real emergency
/// or blast every parent on the route over a traffic jam.
///
/// firestore.rules requires the created document to carry `schoolId`
/// matching the path, `driverId` equal to the caller, and
/// `status == 'reported'` — the three fields stamped unconditionally below.
class IncidentsRepository {
  IncidentsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DriverTrackingRepository? tracking,
    AuditLogRepository? auditLog,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _tracking = tracking ?? DriverTrackingRepository(),
       _auditLog = auditLog ?? AuditLogRepository(firestore: firestore, auth: auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DriverTrackingRepository _tracking;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _incidents(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('incidents');
  }

  /// Files a new incident report and its [AuditActions.incidentReported]
  /// audit entry in one batch, so neither can exist without the other.
  ///
  /// Location comes from the same RTDB node the trip's live tracking is
  /// already writing to (see [DriverTrackingRepository.getLastKnownLocation])
  /// rather than a second GPS fetch — and unlike an emergency, a missing
  /// location is *not* fatal here: an incident can legitimately be filed
  /// from a paused trip with no live fix, so the fields are simply omitted
  /// rather than stored as a fake or zeroed coordinate.
  Future<String> reportIncident({
    required String schoolId,
    required String tripId,
    required String busId,
    required String routeId,
    required IncidentType type,
    String? notes,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final location = await _tracking.getLastKnownLocation(
      schoolId: schoolId,
      tripId: tripId,
    );
    final trimmedNotes = notes?.trim();

    final incidentRef = _incidents(schoolId).doc();
    final batch = _firestore.batch();

    batch.set(incidentRef, {
      'schoolId': schoolId,
      'tripId': tripId,
      'driverId': driverId,
      if (busId.isNotEmpty) 'busId': busId,
      if (routeId.isNotEmpty) 'routeId': routeId,
      'type': type.value,
      'status': IncidentStatus.reported.value,
      'createdAt': FieldValue.serverTimestamp(),
      if (location != null) 'latitude': location.latitude,
      if (location != null) 'longitude': location.longitude,
      if (trimmedNotes != null && trimmedNotes.isNotEmpty) 'notes': trimmedNotes,
    });

    batch.set(
      _auditLog.newEntryRef(schoolId),
      _auditLog.buildEntry(
        schoolId: schoolId,
        action: AuditActions.incidentReported,
        entityType: 'incident',
        entityId: incidentRef.id,
        tripId: tripId,
        busId: busId,
        metadata: {
          'type': type.value,
          'hasLocation': location != null,
        },
      ),
    );

    await batch.commit();
    return incidentRef.id;
  }
}
