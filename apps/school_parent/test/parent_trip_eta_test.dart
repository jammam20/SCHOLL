import 'package:flutter_test/flutter_test.dart';
import 'package:school_parent/features/tracking/domain/live_bus_position.dart';
import 'package:school_parent/features/tracking/domain/parent_trip_eta.dart';
import 'package:school_parent/features/trips/data/stop_order_repository.dart';
import 'package:school_shared/school_shared.dart';

/// Covers the one piece of judgement the parent app adds on top of the
/// shared ETA engine: which stops a parent is actually allowed to see, and
/// how the child's real position in the full route order is reported
/// alongside an estimate built from a partial view of it.
void main() {
  const student = Student(
    id: 'student-1',
    schoolId: 'school-1',
    name: 'Layla',
    isActive: true,
    parentIds: ['parent-1'],
    routeId: 'route-1',
    latitude: 30.0,
    longitude: 31.0,
  );

  const school = School(
    id: 'school-1',
    name: 'Test School',
    code: 'ABC123',
    isActive: true,
    latitude: 30.05,
    longitude: 31.0,
  );

  // ~1.1 km short of the student's pickup point, moving at 10 m/s.
  final busNearby = LiveBusPosition(
    latitude: 30.01,
    longitude: 31.0,
    speedMetersPerSecond: 10,
    updatedAt: DateTime(2026, 1, 1, 7, 30),
  );

  final now = DateTime(2026, 1, 1, 7, 30);

  group('computeParentTripEta', () {
    test(
      'estimates to the child\'s own stop and ignores unreadable siblings',
      () {
        final result = computeParentTripEta(
          tripStatus: TripStatus.active,
          progress: const TripStopProgress(
            stopOrder: ['other-a', 'student-1', 'other-b', schoolStopId],
          ),
          student: student,
          school: school,
          busPosition: busNearby,
          now: now,
        );

        // Only this child's stop and the school carry coordinates a parent
        // may read, so those are the only two points the engine sees.
        expect(result.eta.nextStopId, 'student-1');
        expect(result.eta.stopsRemaining, 2);
        expect(result.eta.hasEta, isTrue);
        expect(result.eta.unavailableReason, isNull);

        // The position in the route is reported from the *full* order,
        // not from the two-point list the estimate was built on.
        expect(result.stopNumber, 2);
        expect(result.totalStops, 4);
        expect(result.hasStopPosition, isTrue);
      },
    );

    test('moves on to the school once the child has boarded', () {
      final result = computeParentTripEta(
        tripStatus: TripStatus.active,
        progress: const TripStopProgress(
          stopOrder: ['other-a', 'student-1', 'other-b', schoolStopId],
          boardedStudents: {'student-1'},
        ),
        student: student,
        school: school,
        busPosition: busNearby,
        now: now,
      );

      expect(result.eta.nextStopId, schoolStopId);
      expect(result.eta.stopsCompleted, 1);
      expect(result.eta.stopsRemaining, 1);
      expect(result.eta.hasEta, isTrue);
    });

    test('treats a drop-off as a completed stop too', () {
      final result = computeParentTripEta(
        tripStatus: TripStatus.active,
        progress: const TripStopProgress(
          stopOrder: ['student-1', schoolStopId],
          droppedOffStudents: {'student-1'},
        ),
        student: student,
        school: school,
        busPosition: busNearby,
        now: now,
      );

      expect(result.eta.nextStopId, schoolStopId);
      expect(result.eta.stopsCompleted, 1);
    });

    test('falls back to pickup-then-school before the order is computed', () {
      final result = computeParentTripEta(
        tripStatus: TripStatus.active,
        progress: const TripStopProgress(),
        student: student,
        school: school,
        busPosition: busNearby,
        now: now,
      );

      expect(result.eta.nextStopId, 'student-1');
      expect(result.eta.hasEta, isTrue);
      // Nothing real to say about route position yet, so it says nothing.
      expect(result.stopNumber, isNull);
      expect(result.totalStops, 0);
      expect(result.hasStopPosition, isFalse);
    });

    test('reports why there is no ETA when the bus has not broadcast', () {
      final result = computeParentTripEta(
        tripStatus: TripStatus.active,
        progress: const TripStopProgress(
          stopOrder: ['student-1', schoolStopId],
        ),
        student: student,
        school: school,
        now: now,
      );

      expect(result.eta.hasEta, isFalse);
      expect(result.eta.unavailableReason, EtaUnavailableReason.noGpsSignal);
    });

    test('reports why there is no ETA when the trip is not running', () {
      final result = computeParentTripEta(
        tripStatus: TripStatus.paused,
        progress: const TripStopProgress(
          stopOrder: ['student-1', schoolStopId],
        ),
        student: student,
        school: school,
        busPosition: busNearby,
        now: now,
      );

      expect(result.eta.hasEta, isFalse);
      expect(result.eta.unavailableReason, EtaUnavailableReason.tripNotActive);
    });

    test('reports stale GPS rather than a confident-looking old estimate', () {
      final result = computeParentTripEta(
        tripStatus: TripStatus.active,
        progress: const TripStopProgress(
          stopOrder: ['student-1', schoolStopId],
        ),
        student: student,
        school: school,
        busPosition: LiveBusPosition(
          latitude: 30.01,
          longitude: 31.0,
          speedMetersPerSecond: 10,
          updatedAt: now.subtract(const Duration(minutes: 10)),
        ),
        now: now,
      );

      expect(result.eta.hasEta, isFalse);
      expect(result.eta.unavailableReason, EtaUnavailableReason.staleGps);
    });

    test('a child with no pickup point still gets a school ETA', () {
      const noLocation = Student(
        id: 'student-1',
        schoolId: 'school-1',
        name: 'Layla',
        isActive: true,
        parentIds: ['parent-1'],
        routeId: 'route-1',
      );

      final result = computeParentTripEta(
        tripStatus: TripStatus.active,
        progress: const TripStopProgress(
          stopOrder: ['student-1', schoolStopId],
        ),
        student: noLocation,
        school: school,
        busPosition: busNearby,
        now: now,
      );

      expect(result.eta.nextStopId, schoolStopId);
      expect(result.eta.stopsRemaining, 1);
      // The full order still knows where this child sits in the run.
      expect(result.stopNumber, 1);
      expect(result.totalStops, 2);
    });
  });
}
