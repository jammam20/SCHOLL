import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// Performance figures for one driver, every one of them counted from
/// records this system genuinely writes.
///
/// Deliberately narrow. Metrics that would need infrastructure this
/// project doesn't have are **not** included rather than estimated:
/// there is no harsh-braking/speeding telemetry (the driver app writes
/// position and speed to RTDB but nothing retains a per-trip speed
/// history), and no parent-facing driver rating exists anywhere in the
/// data model — so no "safety score" or "rating" is shown. What's here is
/// only what can be honestly counted.
class DriverPerformance {
  const DriverPerformance({
    required this.totalTrips,
    required this.completedTrips,
    required this.cancelledTrips,
    required this.emergencyTrips,
    required this.deviationCount,
    required this.onTimeCount,
    required this.startedTripCount,
    required this.averageTripDuration,
  });

  const DriverPerformance.empty()
    : totalTrips = 0,
      completedTrips = 0,
      cancelledTrips = 0,
      emergencyTrips = 0,
      deviationCount = 0,
      onTimeCount = 0,
      startedTripCount = 0,
      averageTripDuration = null;

  final int totalTrips;
  final int completedTrips;
  final int cancelledTrips;

  /// Trips that ended up in `TripStatus.emergency` — the trip-level
  /// footprint of a driver-raised SOS. Counted from the trip documents
  /// this query already reads rather than from a second collection-group
  /// query over `emergencies`, which would need its own index.
  final int emergencyTrips;

  /// Closed route-deviation episodes recorded against this driver in
  /// `routeDeviations` (written server-side when an episode ends).
  final int deviationCount;

  /// Completed trips that actually started within the same 10-minute grace
  /// window ReportsTab already uses for the school-wide on-time rate, so
  /// the two numbers mean the same thing.
  final int onTimeCount;

  /// Completed trips that carry a real `startedAt`, i.e. the denominator
  /// [onTimeCount] is a fraction of. Zero means on-time rate is genuinely
  /// unknown for this driver, not 0%.
  final int startedTripCount;

  final Duration? averageTripDuration;

  double? get onTimeRate =>
      startedTripCount == 0 ? null : onTimeCount / startedTripCount;

  double? get completionRate {
    final finished = completedTrips + cancelledTrips;
    return finished == 0 ? null : completedTrips / finished;
  }
}

/// The same 10-minute grace ReportsTab uses for the school-wide on-time
/// rate — kept identical so a per-driver figure can be compared against
/// the school average without the two measuring different things.
const _onTimeGrace = Duration(minutes: 10);

class DriverPerformanceRepository {
  DriverPerformanceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Trips for one driver, newest first — matches the existing
  /// (driverId ASC, scheduledAt DESC) composite index in
  /// firebase/firestore.indexes.json.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchDriverTrips({
    required String schoolId,
    required String driverId,
    int limit = 200,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .orderBy('scheduledAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Closed deviation episodes for the school, newest first — matches the
  /// existing (schoolId ASC, startedAt DESC) index. Filtering down to one
  /// driver happens in [performanceFrom] rather than as a second `where`,
  /// so this needs no additional composite index and the same stream can
  /// back both the per-driver figure and the school-wide history page.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchDeviations(
    String schoolId, {
    int limit = 300,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('routeDeviations')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Pure aggregation over records already fetched — no I/O, so it's
  /// directly unit-testable.
  static DriverPerformance performanceFrom({
    required String driverId,
    required List<SchoolTrip> trips,
    required List<DeviationRecord> deviations,
  }) {
    final driverTrips = trips
        .where((trip) => trip.driverId == driverId)
        .toList();
    final completed = driverTrips
        .where((trip) => trip.status == TripStatus.completed)
        .toList();
    final withStart = completed
        .where((trip) => trip.startedAt != null)
        .toList();
    final onTime = withStart
        .where((trip) => trip.startedAt!.difference(trip.scheduledAt) <= _onTimeGrace)
        .length;

    final durations = completed
        .where((trip) => trip.startedAt != null && trip.completedAt != null)
        .map((trip) => trip.completedAt!.difference(trip.startedAt!))
        .toList();

    return DriverPerformance(
      totalTrips: driverTrips.length,
      completedTrips: completed.length,
      cancelledTrips: driverTrips
          .where((trip) => trip.status == TripStatus.cancelled)
          .length,
      emergencyTrips: driverTrips
          .where((trip) => trip.status == TripStatus.emergency)
          .length,
      deviationCount: deviations
          .where((deviation) => deviation.driverId == driverId)
          .length,
      onTimeCount: onTime,
      startedTripCount: withStart.length,
      averageTripDuration: durations.isEmpty
          ? null
          : Duration(
              seconds:
                  durations.fold<int>(0, (total, d) => total + d.inSeconds) ~/
                  durations.length,
            ),
    );
  }
}
