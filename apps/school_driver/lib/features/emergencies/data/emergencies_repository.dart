import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../../tracking/data/driver_tracking_repository.dart';
import '../../trips/domain/trip_operation_exception.dart';

/// Raising and resolving emergencies from the driver side. Reuses the same
/// transaction + typed-exception shape TripsRepository/StopOrderRepository
/// already established: re-read the live trip/emergency doc, validate
/// against it, then write — never trust a possibly-stale cached snapshot.
class EmergenciesRepository {
  EmergenciesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DriverTrackingRepository? tracking,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _tracking = tracking ?? DriverTrackingRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DriverTrackingRepository _tracking;

  DocumentReference<Map<String, dynamic>> _trip(String schoolId, String tripId) {
    return _firestore.collection('schools').doc(schoolId).collection('trips').doc(tripId);
  }

  DocumentReference<Map<String, dynamic>> _emergency(
    String schoolId,
    String tripId,
    String emergencyId,
  ) {
    return _trip(schoolId, tripId).collection('emergencies').doc(emergencyId);
  }

  /// The trip's currently active emergency, if any — a plain (non-nested)
  /// equality-filtered query on a subcollection scoped to one known trip,
  /// so it needs no composite index, unlike the admin app's cross-trip
  /// history view.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveEmergency({
    required String schoolId,
    required String tripId,
  }) {
    return _trip(schoolId, tripId)
        .collection('emergencies')
        .where('status', isEqualTo: EmergencyStatus.active.value)
        .limit(1)
        .snapshots();
  }

  /// Raises a new emergency for [tripId] and flips the trip's own status to
  /// `TripStatus.emergency` in the same transaction — these two things must
  /// never happen independently, or a network drop between them could leave
  /// a trip stuck "in emergency" with no emergency record behind it (or vice
  /// versa). The driver's current location is read from the same RTDB node
  /// their live tracking already writes to (see
  /// DriverTrackingRepository.getLastKnownLocation) — no second GPS fetch,
  /// and no fake location is ever stored if it's unavailable.
  Future<String> createEmergency({
    required String schoolId,
    required String tripId,
    required EmergencyType type,
    String? driverNote,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final location = await _tracking.getLastKnownLocation(schoolId: schoolId, tripId: tripId);

    final tripRef = _trip(schoolId, tripId);
    final emergencyRef = tripRef.collection('emergencies').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(tripRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const TripOperationException(
          TripOperationError.tripNotFound,
          'This trip could not be found.',
        );
      }

      assertOwnership(
        tripDriverId: data['driverId'] as String? ?? '',
        currentUserId: driverId,
      );

      final trip = SchoolTrip.fromMap(snapshot.id, data);

      if (trip.status == TripStatus.emergency) {
        throw const TripOperationException(
          TripOperationError.emergencyAlreadyActive,
          'An active emergency already exists for this trip.',
        );
      }

      final eligibility = checkEmergencyCreationEligibility(
        tripStatus: trip.status,
        hasLocation: location != null,
      );
      switch (eligibility) {
        case EmergencyCreationEligibility.locationUnavailable:
          throw const TripOperationException(
            TripOperationError.locationUnavailable,
            'Your current location is unavailable.',
          );
        case EmergencyCreationEligibility.tripNotActive:
          // Always throws for any status that isn't active/paused — see
          // TripStatus.canTransitionTo.
          assertCanTransition(trip.status, TripStatus.emergency);
        case EmergencyCreationEligibility.eligible:
          break;
      }

      transaction.set(emergencyRef, {
        'schoolId': schoolId,
        'tripId': tripId,
        'driverId': driverId,
        'busId': trip.busId,
        if (trip.routeId.isNotEmpty) 'routeId': trip.routeId,
        'type': type.value,
        'status': EmergencyStatus.active.value,
        'latitude': location!.latitude,
        'longitude': location.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        if (driverNote != null && driverNote.trim().isNotEmpty)
          'driverNote': driverNote.trim(),
      });

      transaction.update(tripRef, {
        'status': TripStatus.emergency.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(tripRef.collection('events').doc(), {
        'type': 'emergency_created',
        'driverId': driverId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return emergencyRef.id;
  }

  /// Marks the driver's own emergency resolved. Admin resolution is a
  /// separate method in the admin app's own EmergenciesRepository (mirroring
  /// how trip status updates are already split per app) since the two roles
  /// are authorized differently — but both ultimately hit the exact same
  /// firestore.rules `emergencies/{emergencyId}` update rule and the same
  /// shared `checkEmergencyResolutionEligibility`.
  Future<void> resolveEmergency({
    required String schoolId,
    required String tripId,
    required String emergencyId,
    String? resolutionNote,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final ref = _emergency(schoolId, tripId, emergencyId);
    final tripRef = _trip(schoolId, tripId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const TripOperationException(
          TripOperationError.emergencyNotFound,
          'This emergency could not be found.',
        );
      }

      final status = EmergencyStatusX.tryParse(data['status']) ?? EmergencyStatus.active;
      final eligibility = checkEmergencyResolutionEligibility(
        status: status,
        isAuthorized: (data['driverId'] as String?) == driverId,
      );

      switch (eligibility) {
        case EmergencyResolutionEligibility.alreadyResolved:
          throw const TripOperationException(
            TripOperationError.emergencyAlreadyResolved,
            'This emergency has already been resolved.',
          );
        case EmergencyResolutionEligibility.unauthorized:
          throw const TripOperationException(
            TripOperationError.unauthorized,
            'You are not authorized to resolve this emergency.',
          );
        case EmergencyResolutionEligibility.eligible:
          break;
      }

      transaction.update(ref, {
        'status': EmergencyStatus.resolved.value,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': driverId,
        if (resolutionNote != null && resolutionNote.trim().isNotEmpty)
          'resolutionNote': resolutionNote.trim(),
      });

      transaction.set(tripRef.collection('events').doc(), {
        'type': 'emergency_resolved',
        'driverId': driverId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
