import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

/// A stable identity for *why* a trip create/reassign was refused —
/// Production hardening: lets the presentation layer localize the handful
/// of conflict reasons that matter (Arabic) without retrofitting l10n onto
/// every exception message in this app; `null` means "no specific code,
/// fall back to [TripReassignmentException.message]/
/// [DuplicateActiveTripException.message] as plain English", matching this
/// app's pre-existing convention for everything else.
enum TripConflictReason { busAlreadyActive, driverAlreadyActive }

/// Raised when a last-minute reassignment can't proceed — carries
/// user-facing copy rather than a raw Firestore error.
class TripReassignmentException implements Exception {
  const TripReassignmentException(this.message, {this.reason});
  final String message;
  final TripConflictReason? reason;
  @override
  String toString() => message;
}

/// Raised when a new trip would put the same bus or driver on two active
/// trips at once — carries user-facing copy rather than a raw Firestore
/// error, same as [TripReassignmentException].
class DuplicateActiveTripException implements Exception {
  const DuplicateActiveTripException(this.message, {this.reason});
  final String message;
  final TripConflictReason? reason;
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

  CollectionReference<Map<String, dynamic>> _locks(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('activeTripLocks');
  }

  DocumentReference<Map<String, dynamic>> _busLock(String schoolId, String busId) =>
      _locks(schoolId).doc('bus_$busId');

  DocumentReference<Map<String, dynamic>> _driverLock(String schoolId, String driverId) =>
      _locks(schoolId).doc('driver_$driverId');

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

  /// A fast, pre-transaction rejection for legacy trips that predate the
  /// `activeTripLocks` mechanism below (see [createTrip]'s own doc comment)
  /// — a non-atomic, best-effort check-then-write query, kept purely so a
  /// bus/driver already committed via an old trip (one with no lock
  /// document at all) is still caught, just not with the same
  /// concurrency-safety guarantee the lock gives every *new* trip. Two
  /// admins racing this specific check within milliseconds of each other
  /// could still both pass it, which is exactly the gap the transactional
  /// lock in [createTrip] closes for anything created going forward.
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
        reason: TripConflictReason.busAlreadyActive,
      );
    }

    final driverTrips = await trips.where('driverId', isEqualTo: driverId).get();
    if (driverTrips.docs.any(
      (doc) => _activeTripStatuses.contains(doc.data()['status']),
    )) {
      throw const DuplicateActiveTripException(
        'This driver is already on an active trip. Complete or cancel it '
        'before starting another one.',
        reason: TripConflictReason.driverAlreadyActive,
      );
    }
  }

  /// Production hardening: concurrency — creates the trip and claims its
  /// bus/driver lock documents in one Firestore transaction. Firestore
  /// aborts and silently retries a transaction whose reads were
  /// invalidated by another transaction's commit in between, so two admins
  /// racing to book the same bus resolve deterministically: whichever
  /// commits first wins, and the loser's retry re-reads the lock the winner
  /// just created and throws [DuplicateActiveTripException] instead of
  /// creating a second, conflicting trip. See [_assertNoConflictingActiveTrip]
  /// for why the older, non-atomic query check runs first anyway (it still
  /// catches a conflict against a trip old enough to have no lock at all).
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
    final busLockRef = _busLock(schoolId, busId);
    final driverLockRef = _driverLock(schoolId, driverId);

    await _firestore.runTransaction((transaction) async {
      final busLock = await transaction.get(busLockRef);
      if (busLock.exists) {
        throw const DuplicateActiveTripException(
          'This bus is already on an active trip. Complete or cancel it '
          'before starting another one.',
          reason: TripConflictReason.busAlreadyActive,
        );
      }
      final driverLock = await transaction.get(driverLockRef);
      if (driverLock.exists) {
        throw const DuplicateActiveTripException(
          'This driver is already on an active trip. Complete or cancel it '
          'before starting another one.',
          reason: TripConflictReason.driverAlreadyActive,
        );
      }

      transaction.set(ref, {
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
      transaction.set(busLockRef, {
        'schoolId': schoolId,
        'tripId': ref.id,
        'busId': busId,
        'driverId': driverId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(driverLockRef, {
        'schoolId': schoolId,
        'tripId': ref.id,
        'busId': busId,
        'driverId': driverId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.tripCreated,
      actorRole: 'admin',
      entityType: 'trip',
      entityId: ref.id,
      tripId: ref.id,
      busId: busId,
      driverId: driverId,
      metadata: {'routeId': routeId, 'scheduledAt': scheduledAt.toIso8601String()},
    );

    return ref.id;
  }

  /// A direct write — firestore.rules already grants a school admin full
  /// write access to `trips/{tripId}`, so unlike the driver app's own
  /// updateStatus (which needs isValidTripTransition to fence a driver's
  /// narrower self-update), this doesn't need the same guard.
  ///
  /// Production hardening: releases this trip's bus/driver locks whenever
  /// an admin moves it to a terminal status (`completed`/`cancelled`) —
  /// the mirror image of what the driver app's own updateStatus does for
  /// its own transitions — so the bus/driver is immediately free for a new
  /// trip rather than staying locked until some other write happens to
  /// touch it. Reads the trip first so the correct bus/driver ids are known
  /// even if they were changed by a since-forgotten reassignment.
  Future<void> updateStatus({
    required String schoolId,
    required String tripId,
    required String status,
  }) async {
    final tripRef = _trips(schoolId).doc(tripId);
    final isTerminal = status == 'completed' || status == 'cancelled';

    if (!isTerminal) {
      await tripRef.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(tripRef);
      final data = snapshot.data();
      transaction.update(tripRef, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (data == null) return;
      final busId = data['busId'] as String?;
      final driverId = data['driverId'] as String?;
      if (busId != null && busId.isNotEmpty) {
        transaction.delete(_busLock(schoolId, busId));
      }
      if (driverId != null && driverId.isNotEmpty) {
        transaction.delete(_driverLock(schoolId, driverId));
      }
    });

    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: status == 'cancelled'
          ? AuditActions.tripCancelledByAdmin
          : AuditActions.tripCompleted,
      actorRole: 'admin',
      entityType: 'trip',
      entityId: tripId,
      tripId: tripId,
    );
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

    // Production hardening: concurrency — a reassignment moves this trip's
    // lock(s) to the new bus/driver inside one transaction, first checking
    // the *new* bus/driver isn't itself already locked by a different,
    // still-open trip. Without this, reassigning trip A onto a bus already
    // committed to trip B would silently leave both trips claiming the
    // same bus with no lock ever objecting.
    await _firestore.runTransaction((transaction) async {
      final freshSnapshot = await transaction.get(tripRef);
      final freshData = freshSnapshot.data();
      if (!freshSnapshot.exists || freshData == null) {
        throw const TripReassignmentException('This trip could not be found.');
      }
      final freshTrip = SchoolTrip.fromMap(freshSnapshot.id, freshData);

      if (busChanged) {
        final newBusLock = await transaction.get(_busLock(schoolId, busId));
        if (newBusLock.exists && newBusLock.data()?['tripId'] != tripId) {
          throw const TripReassignmentException(
            'That bus is already on another active trip.',
            reason: TripConflictReason.busAlreadyActive,
          );
        }
      }
      if (driverChanged) {
        final newDriverLock = await transaction.get(_driverLock(schoolId, driverId));
        if (newDriverLock.exists && newDriverLock.data()?['tripId'] != tripId) {
          throw const TripReassignmentException(
            'That driver is already on another active trip.',
            reason: TripConflictReason.driverAlreadyActive,
          );
        }
      }

      transaction.update(tripRef, {
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
        transaction.set(ref, {
          'id': ref.id,
          'schoolId': schoolId,
          'tripId': tripId,
          'type': ReassignmentType.busReassigned.value,
          'changedBy': adminId,
          'changedAt': FieldValue.serverTimestamp(),
          'fromValue': freshTrip.busId,
          'toValue': busId,
          'reason': ?reason,
        });
        if (freshTrip.busId.isNotEmpty) {
          transaction.delete(_busLock(schoolId, freshTrip.busId));
        }
        transaction.set(_busLock(schoolId, busId), {
          'schoolId': schoolId,
          'tripId': tripId,
          'busId': busId,
          'driverId': driverChanged ? driverId : freshTrip.driverId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (driverChanged) {
        final ref = reassignments.doc();
        transaction.set(ref, {
          'id': ref.id,
          'schoolId': schoolId,
          'tripId': tripId,
          'type': ReassignmentType.driverReassigned.value,
          'changedBy': adminId,
          'changedAt': FieldValue.serverTimestamp(),
          'fromValue': freshTrip.driverId,
          'toValue': driverId,
          'reason': ?reason,
        });
        if (freshTrip.driverId.isNotEmpty) {
          transaction.delete(_driverLock(schoolId, freshTrip.driverId));
        }
        transaction.set(_driverLock(schoolId, driverId), {
          'schoolId': schoolId,
          'tripId': tripId,
          'busId': busChanged ? busId : freshTrip.busId,
          'driverId': driverId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });

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
