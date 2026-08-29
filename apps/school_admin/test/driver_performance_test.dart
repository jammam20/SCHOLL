import 'package:flutter_test/flutter_test.dart';
import 'package:school_admin/features/driver_management/data/driver_performance_repository.dart';
import 'package:school_shared/school_shared.dart';

final _scheduled = DateTime(2026, 3, 2, 7, 30);

SchoolTrip _trip({
  required String id,
  required String driverId,
  required TripStatus status,
  DateTime? startedAt,
  DateTime? completedAt,
}) => SchoolTrip(
  id: id,
  schoolId: 'school-1',
  routeId: 'route-1',
  busId: 'bus-1',
  driverId: driverId,
  status: status,
  scheduledAt: _scheduled,
  startedAt: startedAt,
  completedAt: completedAt,
);

DeviationRecord _deviation(String id, String driverId) => DeviationRecord(
  id: id,
  schoolId: 'school-1',
  tripId: 'trip-1',
  busId: 'bus-1',
  driverId: driverId,
  status: DeviationStatus.deviationEnded,
  startedAt: _scheduled,
  maxDeviationMeters: 800,
  currentDeviationMeters: 0,
);

void main() {
  group('DriverPerformanceRepository.performanceFrom', () {
    test('counts only the requested driver own trips and deviations', () {
      final performance = DriverPerformanceRepository.performanceFrom(
        driverId: 'driver-1',
        trips: [
          _trip(
            id: 't1',
            driverId: 'driver-1',
            status: TripStatus.completed,
            startedAt: _scheduled,
            completedAt: _scheduled.add(const Duration(minutes: 40)),
          ),
          _trip(id: 't2', driverId: 'driver-2', status: TripStatus.completed),
        ],
        deviations: [
          _deviation('d1', 'driver-1'),
          _deviation('d2', 'driver-2'),
        ],
      );

      expect(performance.totalTrips, 1);
      expect(performance.completedTrips, 1);
      expect(performance.deviationCount, 1);
    });

    test('on-time uses the same 10-minute grace as the school-wide report', () {
      final performance = DriverPerformanceRepository.performanceFrom(
        driverId: 'driver-1',
        trips: [
          // Started 5 minutes late — on time.
          _trip(
            id: 'ontime',
            driverId: 'driver-1',
            status: TripStatus.completed,
            startedAt: _scheduled.add(const Duration(minutes: 5)),
            completedAt: _scheduled.add(const Duration(minutes: 45)),
          ),
          // Started 25 minutes late — not on time.
          _trip(
            id: 'late',
            driverId: 'driver-1',
            status: TripStatus.completed,
            startedAt: _scheduled.add(const Duration(minutes: 25)),
            completedAt: _scheduled.add(const Duration(minutes: 65)),
          ),
        ],
        deviations: const [],
      );

      expect(performance.startedTripCount, 2);
      expect(performance.onTimeCount, 1);
      expect(performance.onTimeRate, 0.5);
    });

    test('on-time rate is null (not zero) when nothing has started', () {
      final performance = DriverPerformanceRepository.performanceFrom(
        driverId: 'driver-1',
        trips: [
          _trip(id: 's1', driverId: 'driver-1', status: TripStatus.scheduled),
        ],
        deviations: const [],
      );

      expect(performance.startedTripCount, 0);
      expect(performance.onTimeRate, isNull);
      expect(performance.averageTripDuration, isNull);
    });

    test('averages duration only over trips with both timestamps', () {
      final performance = DriverPerformanceRepository.performanceFrom(
        driverId: 'driver-1',
        trips: [
          _trip(
            id: 'a',
            driverId: 'driver-1',
            status: TripStatus.completed,
            startedAt: _scheduled,
            completedAt: _scheduled.add(const Duration(minutes: 30)),
          ),
          _trip(
            id: 'b',
            driverId: 'driver-1',
            status: TripStatus.completed,
            startedAt: _scheduled,
            completedAt: _scheduled.add(const Duration(minutes: 50)),
          ),
          // No completedAt — must not drag the average down.
          _trip(
            id: 'c',
            driverId: 'driver-1',
            status: TripStatus.completed,
            startedAt: _scheduled,
          ),
        ],
        deviations: const [],
      );

      expect(performance.averageTripDuration, const Duration(minutes: 40));
    });

    test('counts emergency and cancelled trips separately', () {
      final performance = DriverPerformanceRepository.performanceFrom(
        driverId: 'driver-1',
        trips: [
          _trip(id: 'e', driverId: 'driver-1', status: TripStatus.emergency),
          _trip(id: 'x', driverId: 'driver-1', status: TripStatus.cancelled),
          _trip(id: 'c', driverId: 'driver-1', status: TripStatus.completed),
        ],
        deviations: const [],
      );

      expect(performance.emergencyTrips, 1);
      expect(performance.cancelledTrips, 1);
      expect(performance.completedTrips, 1);
      expect(performance.completionRate, 0.5);
    });

    test('an empty record set yields no fabricated numbers', () {
      const performance = DriverPerformance.empty();
      expect(performance.totalTrips, 0);
      expect(performance.onTimeRate, isNull);
      expect(performance.completionRate, isNull);
      expect(performance.averageTripDuration, isNull);
    });
  });
}
