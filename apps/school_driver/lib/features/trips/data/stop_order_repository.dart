import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:school_shared/school_shared.dart';

import '../../schools/data/schools_repository.dart';
import '../domain/trip_operation_exception.dart';

/// Sentinel appended to the end of every computed stop order to represent
/// the school itself — the trip's fixed final destination.
const schoolStopId = '__school__';

class StopOrderRepository {
  StopOrderRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _trip(String schoolId, String tripId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .doc(tripId);
  }

  DocumentReference<Map<String, dynamic>> _student(String schoolId, String studentId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId);
  }

  DocumentReference<Map<String, dynamic>> _bus(String schoolId, String busId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('buses')
        .doc(busId);
  }

  Stream<List<String>> watchStopOrder({
    required String schoolId,
    required String tripId,
  }) {
    return _trip(schoolId, tripId).snapshots().map((snapshot) {
      final order = snapshot.data()?['stopOrder'];
      if (order is! List) return const <String>[];
      return order.whereType<String>().toList();
    });
  }

  Stream<Set<String>> watchBoardedStudents({
    required String schoolId,
    required String tripId,
  }) {
    return _trip(schoolId, tripId).snapshots().map((snapshot) {
      final boarded = snapshot.data()?['boardedStudents'];
      if (boarded is! List) return const <String>{};
      return boarded.whereType<String>().toSet();
    });
  }

  /// The other half of ridership: who has already been handed over at the
  /// end of their ride. Stored as a plain `List<String>` on the trip
  /// document exactly like `boardedStudents` (firestore.rules permits the
  /// assigned driver to write it while the trip is `active`), so the parent
  /// app can watch it live the same way.
  Stream<Set<String>> watchDroppedOffStudents({
    required String schoolId,
    required String tripId,
  }) {
    return _trip(schoolId, tripId).snapshots().map((snapshot) {
      final droppedOff = snapshot.data()?['droppedOffStudents'];
      if (droppedOff is! List) return const <String>{};
      return droppedOff.whereType<String>().toSet();
    });
  }

  /// Computes a nearest-neighbor stop order through every present student
  /// on the route who has a pickup point set (students marked absent today
  /// — see Student.isAbsentToday — are skipped so the bus doesn't detour
  /// for them), then writes it directly to the trip (drivers can update
  /// just `stopOrder`/`boardedStudents` on their own trips — see
  /// firestore.rules).
  ///
  /// Feature: two daily trips — [direction] decides both the school's
  /// position in the order and where the nearest-neighbor search starts
  /// from, matching how the trip actually runs:
  ///  - **outbound** (home -> school): the bus is already out among the
  ///    students, so the search starts from the driver's own live GPS
  ///    position, and the school — the fixed destination — is appended
  ///    last.
  ///  - **return** (school -> home): the bus starts at the school, so the
  ///    search starts from the school's own location instead of the
  ///    driver's (who may not even be there yet), and the school is placed
  ///    *first* rather than last.
  ///
  /// Always writes *some* order, even in the worst case — a driver stuck on
  /// "Computing today's pickup order…" forever with no way to proceed is
  /// worse than one that isn't perfectly distance-optimized. The
  /// nearest-neighbor sequence is the ideal path; a GPS fetch that fails or
  /// times out (previously a silent no-op that left `stopOrder` empty
  /// forever, even though the driver's continuous location broadcast in
  /// [DriverTrackingRepository] kept working fine — a one-shot fix and a
  /// continuous stream can fail independently) falls back to the route's
  /// own student order instead. The driver can still manually reorder from
  /// there once the fallback order exists.
  Future<void> computeInitialOrder({
    required String schoolId,
    required String tripId,
    required String routeId,
    TripDirection direction = TripDirection.outbound,
  }) async {
    final studentsSnap = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('routeId', isEqualTo: routeId)
        .where('isActive', isEqualTo: true)
        .get();

    final students = studentsSnap.docs
        .map((doc) {
          final student = Student.fromMap(doc.id, doc.data());
          if (!student.hasLocation || student.isAbsentToday) return null;
          return (id: student.id, latitude: student.latitude!, longitude: student.longitude!);
        })
        .nonNulls
        .toList();
    final fallbackOrder = students.map((s) => s.id).toList();

    final List<String> order;
    if (direction == TripDirection.returnTrip) {
      final school = await SchoolsRepository().watchSchool(schoolId: schoolId).first;
      order = [
        schoolStopId,
        if (school != null && school.hasLocation)
          ..._nearestNeighborOrder(
            startLat: school.latitude!,
            startLng: school.longitude!,
            students: students,
          )
        else
          ...fallbackOrder,
      ];
    } else {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = null;
      }
      order = [
        if (position != null)
          ..._nearestNeighborOrder(
            startLat: position.latitude,
            startLng: position.longitude,
            students: students,
          )
        else
          ...fallbackOrder,
        schoolStopId,
      ];
    }

    await setStopOrder(schoolId: schoolId, tripId: tripId, order: order);
  }

  /// A reorder must carry exactly the same set of stops as whatever's
  /// there now (see isValidStopReorder) — this only ever reshuffles who's
  /// picked up in what order on *this* trip; it never reads or writes the
  /// school's own `routes/{id}` document, so the master route can't be
  /// affected by a driver reordering their run.
  Future<void> setStopOrder({
    required String schoolId,
    required String tripId,
    required List<String> order,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final tripRef = _trip(schoolId, tripId);

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
      // An empty current order means this is the very first write (right
      // after computeInitialOrder) — nothing to validate a reorder against
      // yet.
      final currentOrder =
          (data['stopOrder'] as List?)?.whereType<String>().toList() ?? const [];
      if (currentOrder.isNotEmpty &&
          !isValidStopReorder(currentOrder: currentOrder, newOrder: order)) {
        throw const TripOperationException(
          TripOperationError.invalidStopOrder,
          "That order doesn't match who's actually on this trip.",
        );
      }
      if (trip.status != TripStatus.active && currentOrder.isNotEmpty) {
        throw const TripOperationException(
          TripOperationError.tripNotActive,
          'Stops can only be reordered while the trip is active.',
        );
      }

      transaction.update(tripRef, {
        'stopOrder': order,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Marks [studentId] boarded for this trip — the parent app watches this
  /// same field and shows the status live, no push notification needed.
  /// Guarded by [checkBoardingEligibility] inside a transaction so a
  /// student can't be boarded twice (a repeat tap/retry is a silent,
  /// idempotent no-op — not an error), while they're marked absent, or on
  /// a trip that isn't actually active.
  Future<void> markBoarded({
    required String schoolId,
    required String tripId,
    required String studentId,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final tripRef = _trip(schoolId, tripId);
    final studentRef = _student(schoolId, studentId);

    // Firestore Web's transaction callback does not propagate a thrown Dart
    // exception cleanly across the JS-interop boundary — it surfaces to the
    // caller as a generic boxed "Dart exception thrown from converted
    // Future" error instead of this TripOperationException. So every
    // expected rejection is returned here as data instead of thrown, and
    // only actually thrown once execution is back in plain Dart, after the
    // transaction has settled.
    final failure = await _firestore.runTransaction<TripOperationException?>((
      transaction,
    ) async {
      final tripSnapshot = await transaction.get(tripRef);
      final tripData = tripSnapshot.data();
      if (!tripSnapshot.exists || tripData == null) {
        return const TripOperationException(
          TripOperationError.tripNotFound,
          'This trip could not be found.',
        );
      }

      try {
        assertOwnership(
          tripDriverId: tripData['driverId'] as String? ?? '',
          currentUserId: driverId,
        );
      } on TripOperationException catch (e) {
        return e;
      }

      final trip = SchoolTrip.fromMap(tripSnapshot.id, tripData);
      final stopOrder =
          (tripData['stopOrder'] as List?)?.whereType<String>().toList() ?? const [];
      final boarded =
          (tripData['boardedStudents'] as List?)?.whereType<String>().toSet() ?? const {};
      final droppedOff =
          (tripData['droppedOffStudents'] as List?)?.whereType<String>().toSet() ?? const {};

      final studentSnapshot = await transaction.get(studentRef);
      final studentData = studentSnapshot.data();
      final isAbsentToday = studentData != null &&
          Student.fromMap(studentSnapshot.id, studentData).isAbsentToday;

      // Bus capacity is re-read from the server on every single boarding
      // attempt (never trusted from a cached client value) — this
      // `transaction.get` is what makes two simultaneous boarding requests
      // for the last open seat resolve safely: Firestore aborts and
      // retries a transaction whose reads were invalidated by another
      // transaction's commit, so the second call to reach the server sees
      // the *other* driver tap's already-boarded student and re-evaluates
      // eligibility against the fresh count rather than racing past it.
      final busId = trip.busId;
      int? busCapacity;
      if (busId.isNotEmpty) {
        final busSnapshot = await transaction.get(_bus(schoolId, busId));
        busCapacity = (busSnapshot.data()?['capacity'] as num?)?.toInt();
      }

      final eligibility = checkBoardingEligibility(
        tripStatus: trip.status,
        stopOrder: stopOrder,
        boardedStudents: boarded,
        droppedOffStudents: droppedOff,
        studentId: studentId,
        studentIsAbsentToday: isAbsentToday,
        busCapacity: busCapacity,
      );

      switch (eligibility) {
        case BoardingEligibility.alreadyBoarded:
          return null; // Idempotent: nothing left to do.
        case BoardingEligibility.absent:
          return const TripOperationException(
            TripOperationError.studentAbsent,
            'This student is marked absent today and cannot be boarded.',
          );
        case BoardingEligibility.tripNotActive:
          return const TripOperationException(
            TripOperationError.tripNotActive,
            'Boarding can only be recorded while the trip is active.',
          );
        case BoardingEligibility.studentNotOnTrip:
          return const TripOperationException(
            TripOperationError.studentNotOnTrip,
            "This student isn't on this trip's stop order.",
          );
        case BoardingEligibility.busAtCapacity:
          return const TripOperationException(
            TripOperationError.busCapacityExceeded,
            'Bus capacity reached.',
          );
        case BoardingEligibility.eligible:
          break;
      }

      transaction.update(tripRef, {
        'boardedStudents': FieldValue.arrayUnion([studentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(tripRef.collection('events').doc(), {
        'type': 'studentBoarded',
        'studentId': studentId,
        'driverId': driverId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    });

    if (failure != null) throw failure;
  }

  /// Marks [studentId] dropped off for this trip — the mirror image of
  /// [markBoarded], down to the transaction shape: re-read the live trip
  /// document, prove ownership against it, run the pure eligibility check
  /// ([checkDropOffEligibility]) against *that* data rather than anything
  /// the client had cached, then write. A repeat tap/retry is a silent,
  /// idempotent no-op rather than an error, and a student can never be
  /// dropped off without first having been boarded (the resulting
  /// `boardedStudents`/`droppedOffStudents` pair is what an admin's
  /// attendance report reads, so "delivered but never picked up" must not
  /// be representable).
  ///
  /// Unlike [markBoarded] this does not read the student document at all —
  /// today's absence flag is only relevant to *getting on* the bus; a
  /// student already aboard has to be handed over regardless of what their
  /// record says.
  Future<void> markDroppedOff({
    required String schoolId,
    required String tripId,
    required String studentId,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final tripRef = _trip(schoolId, tripId);

    // See the matching comment in markBoarded: expected rejections are
    // returned as data from the transaction, not thrown inside it, because
    // Firestore Web's transaction callback does not propagate a thrown Dart
    // exception cleanly across the JS-interop boundary.
    final failure = await _firestore.runTransaction<TripOperationException?>((
      transaction,
    ) async {
      final tripSnapshot = await transaction.get(tripRef);
      final tripData = tripSnapshot.data();
      if (!tripSnapshot.exists || tripData == null) {
        return const TripOperationException(
          TripOperationError.tripNotFound,
          'This trip could not be found.',
        );
      }

      try {
        assertOwnership(
          tripDriverId: tripData['driverId'] as String? ?? '',
          currentUserId: driverId,
        );
      } on TripOperationException catch (e) {
        return e;
      }

      final trip = SchoolTrip.fromMap(tripSnapshot.id, tripData);
      final stopOrder =
          (tripData['stopOrder'] as List?)?.whereType<String>().toList() ?? const [];
      final boarded =
          (tripData['boardedStudents'] as List?)?.whereType<String>().toSet() ?? const {};
      final droppedOff =
          (tripData['droppedOffStudents'] as List?)?.whereType<String>().toSet() ??
              const {};

      final eligibility = checkDropOffEligibility(
        tripStatus: trip.status,
        stopOrder: stopOrder,
        boardedStudents: boarded,
        droppedOffStudents: droppedOff,
        studentId: studentId,
      );

      switch (eligibility) {
        case DropOffEligibility.alreadyDroppedOff:
          return null; // Idempotent: nothing left to do.
        case DropOffEligibility.notBoarded:
          return const TripOperationException(
            TripOperationError.studentNotBoarded,
            "This student hasn't been picked up on this trip yet.",
          );
        case DropOffEligibility.tripNotActive:
          return const TripOperationException(
            TripOperationError.tripNotActive,
            'Drop-off can only be recorded while the trip is active.',
          );
        case DropOffEligibility.studentNotOnTrip:
          return const TripOperationException(
            TripOperationError.studentNotOnTrip,
            "This student isn't on this trip's stop order.",
          );
        case DropOffEligibility.eligible:
          break;
      }

      transaction.update(tripRef, {
        'droppedOffStudents': FieldValue.arrayUnion([studentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(tripRef.collection('events').doc(), {
        'type': 'studentDroppedOff',
        'studentId': studentId,
        'driverId': driverId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    });

    if (failure != null) throw failure;
  }

  List<String> _nearestNeighborOrder({
    required double startLat,
    required double startLng,
    required List<({String id, double latitude, double longitude})> students,
  }) {
    final remaining = [...students];
    final ordered = <String>[];
    var currentLat = startLat;
    var currentLng = startLng;

    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) => haversineMeters(
          currentLat,
          currentLng,
          a.latitude,
          a.longitude,
        ).compareTo(
          haversineMeters(currentLat, currentLng, b.latitude, b.longitude),
        ),
      );
      final nearest = remaining.removeAt(0);
      ordered.add(nearest.id);
      currentLat = nearest.latitude;
      currentLng = nearest.longitude;
    }

    return ordered;
  }
}
