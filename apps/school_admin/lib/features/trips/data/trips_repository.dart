import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

/// Raised when a last-minute reassignment can't proceed — carries
/// user-facing copy rather than a raw Firestore error.
class TripReassignmentException implements Exception {
  const TripReassignmentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Raised when a new trip would put the same bus or driver on two active
/// trips at once — carries user-facing copy rather than a raw Firestore
/// error, same as [TripReassignmentException].
class DuplicateActiveTripException implements Exception {
  const DuplicateActiveTripException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Trip statuses that represent a trip still in progress — anything not in
/// this set (`completed`, `cancelled`) has finished being a real commitment
/// of a bus/driver's time, so it never conflicts with a new one.
const _activeTripStatuses = ['scheduled', 'starting', 'active', 'paused', 'emergency'];

class TripsRepository {
  TripsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuditLogRepository? auditLog,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _trips(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('trips');
  }

  // `limit` keeps this from reading every trip the school has ever
  // scheduled on every page load — the admin_home_page._TripsTab UI bumps
  // it by _pageSize each time "Load more" is tapped rather than fetching
  // everything up front.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTrips(
    String schoolId, {
    int limit = 30,
  }) {
    return _trips(schoolId)
        .orderBy('scheduledAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Checked against live Firestore state right before the write below, so
  /// this holds regardless of which screen or recurring-trip loop called
  /// createTrip — but it is a check-then-write, not a transaction (Firestore
  /// can't express "no other document in this collection matches X" as a
  /// security rule, since a rule has no way to enumerate sibling documents).
  /// Two admins creating a conflicting trip for the same bus within
  /// milliseconds of each other could still both succeed; closing that
  /// requires a dedicated lock-document architecture, which is a larger
  /// change than this guard.
  Future<void> _assertNoConflictingActiveTrip({
    required String schoolId,
    required String busId,
    required String driverId,
  }) async {
    final trips = _trips(schoolId);

    // Filtered by a single equality field each — Firestore's automatic
    // single-field indexing covers this with no project-specific composite
    // index to deploy. The (small, per-bus/per-driver) status filtering
    // happens client-side instead of as a second `where` clause, which
    // would otherwise require exactly that kind of index.
    final busTrips = await trips.where('busId', isEqualTo: busId).get();
    if (busTrips.docs.any(
      (doc) => _activeTripStatuses.contains(doc.data()['status']),
    )) {
      throw const DuplicateActiveTripException(
        'This bus is already on an active trip. Complete or cancel it '
        'before starting another one.',
      );
    }

    final driverTrips = await trips.where('driverId', isEqualTo: driverId).get();
    if (driverTrips.docs.any(
      (doc) => _activeTripStatuses.contains(doc.data()['status']),
    )) {
      throw const DuplicateActiveTripException(
        'This driver is already on an active trip. Complete or cancel it '
        'before starting another one.',
      );
    }
  }

  Future<String> createTrip({
    required String schoolId,
    required String routeId,
    required String routeName,
    required String busId,
    required String busName,
    required String busPlateNumber,
    required String driverId,
    required String driverName,
    required DateTime scheduledAt,
    TripDirection direction = TripDirection.outbound,
  }) async {
    await _assertNoConflictingActiveTrip(
      schoolId: schoolId,
      busId: busId,
      driverId: driverId,
    );

    final ref = _trips(schoolId).doc();

    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'routeId': routeId,
      'routeName': routeName,
      'busId': busId,
      'busName': busName,
      'busPlateNumber': busPlateNumber,
      'driverId': driverId,
      'driverName': driverName,
      'status': 'scheduled',
      'direction': direction.value,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  // A direct write — firestore.rules already grants a school admin full
  // write access to `trips/{tripId}`, so unlike the driver app's own
  // updateStatus (which needs isValidTripTransition to fence a driver's
  // narrower self-update), this doesn't need the same guard.
  Future<void> updateStatus({
    required String schoolId,
    required String tripId,
    required String status,
  }) {
    return _trips(schoolId).doc(tripId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// A last-minute bus and/or driver change on an existing trip (Feature:
  /// Dynamic Route/Last-Minute Changes).
  ///
  /// Writes three things as one logical operation:
  ///  1. the trip document's own `busId`/`busName`/`busPlateNumber` and/or
  ///     `driverId`/`driverName` — the fields that matter, because the
  ///     deployed `onTripAssignmentChanged` Cloud Function watches exactly
  ///     `busId`/`driverId` and notifies affected parents plus the newly
  ///     assigned driver off the back of that change;
  ///  2. a [ReassignmentRecord] per changed field under
  ///     `trips/{tripId}/reassignments` — the trip document only ever holds
  ///     *current* values, so this subcollection is the only place the
  ///     history of changes survives;
  ///  3. an [AuditLogEntry] per changed field.
  ///
  /// Steps 1 and 2 go in one batch so a reassignment can never be recorded
  /// without the change actually landing, or vice versa. The audit write
  /// follows separately and never fails the operation (see
  /// [AuditLogRepository.recordSafely]).
  ///
  /// A completed or cancelled trip is refused outright: it is finished
  /// history, and reassigning it would fire a parent notification about a
  /// trip that is no longer happening.
  Future<void> reassignTrip({
    required String schoolId,
    required String tripId,
    String? busId,
    String? busName,
    String? busPlateNumber,
    String? driverId,
    String? driverName,
    String? reason,
  }) async {
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) {
      throw const TripReassignmentException(
        'You need to be signed in to do that.',
      );
    }

    final tripRef = _trips(schoolId).doc(tripId);
    final snapshot = await tripRef.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const TripReassignmentException('This trip could not be found.');
    }

    final trip = SchoolTrip.fromMap(snapshot.id, data);
    if (trip.status == TripStatus.completed ||
        trip.status == TripStatus.cancelled) {
      throw const TripReassignmentException(
        'A completed or cancelled trip cannot be reassigned.',
      );
    }

    final busChanged = busId != null && busId != trip.busId;
    final driverChanged = driverId != null && driverId != trip.driverId;
    if (!busChanged && !driverChanged) {
      throw const TripReassignmentException(
        'Pick a different bus or driver first.',
      );
    }

    final batch = _firestore.batch();

    batch.update(tripRef, {
      if (busChanged) ...{
        'busId': busId,
        'busName': busName ?? '',
        'busPlateNumber': busPlateNumber ?? '',
      },
      if (driverChanged) ...{'driverId': driverId, 'driverName': driverName ?? ''},
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final reassignments = tripRef.collection('reassignments');

    if (busChanged) {
      final ref = reassignments.doc();
      batch.set(ref, {
        'id': ref.id,
        'schoolId': schoolId,
        'tripId': tripId,
        'type': ReassignmentType.busReassigned.value,
        'changedBy': adminId,
        'changedAt': FieldValue.serverTimestamp(),
        'fromValue': trip.busId,
        'toValue': busId,
        'reason': ?reason,
      });
    }

    if (driverChanged) {
      final ref = reassignments.doc();
      batch.set(ref, {
        'id': ref.id,
        'schoolId': schoolId,
        'tripId': tripId,
        'type': ReassignmentType.driverReassigned.value,
        'changedBy': adminId,
        'changedAt': FieldValue.serverTimestamp(),
        'fromValue': trip.driverId,
        'toValue': driverId,
        'reason': ?reason,
      });
    }

    await batch.commit();

    if (busChanged) {
      await _auditLog.recordSafely(
        schoolId: schoolId,
        action: AuditActions.busReassigned,
        entityType: 'trip',
        entityId: tripId,
        tripId: tripId,
        busId: busId,
        metadata: {
          'fromBusId': trip.busId,
          'toBusId': busId,
          'reason': ?reason,
        },
      );
    }

    if (driverChanged) {
      await _auditLog.recordSafely(
        schoolId: schoolId,
        action: AuditActions.driverReassigned,
        entityType: 'trip',
        entityId: tripId,
        tripId: tripId,
        driverId: driverId,
        metadata: {
          'fromDriverId': trip.driverId,
          'toDriverId': driverId,
          'reason': ?reason,
        },
      );
    }
  }

  /// The recorded history of last-minute changes for one trip.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReassignments({
    required String schoolId,
    required String tripId,
  }) {
    return _trips(schoolId)
        .doc(tripId)
        .collection('reassignments')
        .orderBy('changedAt', descending: true)
        .snapshots();
  }
}
