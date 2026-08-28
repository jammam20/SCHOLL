import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:school_shared/school_shared.dart';

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

  /// Computes a nearest-neighbor pickup order starting from the driver's
  /// current position through every present student on the route who has a
  /// pickup point set (students marked absent today — see
  /// Student.isAbsentToday — are skipped so the bus doesn't detour for
  /// them), then writes it directly to the trip (drivers can update just
  /// `stopOrder`/`boardedStudents` on their own trips — see
  /// firestore.rules). The school is always the fixed final stop. Silently
  /// no-ops if the driver's current position isn't available — the driver
  /// can still set an order by hand from the trip screen.
  Future<void> computeInitialOrder({
    required String schoolId,
    required String tripId,
    required String routeId,
  }) async {
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (_) {
      return;
    }

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

    final order = _nearestNeighborOrder(
      startLat: position.latitude,
      startLng: position.longitude,
      students: students,
    )..add(schoolStopId);

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

    await _firestore.runTransaction((transaction) async {
      final tripSnapshot = await transaction.get(tripRef);
      final tripData = tripSnapshot.data();
      if (!tripSnapshot.exists || tripData == null) {
        throw const TripOperationException(
          TripOperationError.tripNotFound,
          'This trip could not be found.',
        );
      }

      assertOwnership(
        tripDriverId: tripData['driverId'] as String? ?? '',
        currentUserId: driverId,
      );

      final trip = SchoolTrip.fromMap(tripSnapshot.id, tripData);
      final stopOrder =
          (tripData['stopOrder'] as List?)?.whereType<String>().toList() ?? const [];
      final boarded =
          (tripData['boardedStudents'] as List?)?.whereType<String>().toSet() ?? const {};

      final studentSnapshot = await transaction.get(studentRef);
      final studentData = studentSnapshot.data();
      final isAbsentToday = studentData != null &&
          Student.fromMap(studentSnapshot.id, studentData).isAbsentToday;

      final eligibility = checkBoardingEligibility(
        tripStatus: trip.status,
        stopOrder: stopOrder,
        boardedStudents: boarded,
        studentId: studentId,
        studentIsAbsentToday: isAbsentToday,
      );

      switch (eligibility) {
        case BoardingEligibility.alreadyBoarded:
          return; // Idempotent: nothing left to do.
        case BoardingEligibility.absent:
          throw const TripOperationException(
            TripOperationError.studentAbsent,
            'This student is marked absent today and cannot be boarded.',
          );
        case BoardingEligibility.tripNotActive:
          throw const TripOperationException(
            TripOperationError.tripNotActive,
            'Boarding can only be recorded while the trip is active.',
          );
        case BoardingEligibility.studentNotOnTrip:
          throw const TripOperationException(
            TripOperationError.studentNotOnTrip,
            "This student isn't on this trip's stop order.",
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
    });
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
