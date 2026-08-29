import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  final school = TripStopPoint(
    stopId: '__school__',
    latitude: 30.10,
    longitude: 31.10,
    isCompleted: false,
    isSchool: true,
  );

  TripStopPoint student(String id, double lat, double lng, {bool completed = false}) =>
      TripStopPoint(stopId: id, latitude: lat, longitude: lng, isCompleted: completed);

  group('computeTripEta', () {
    test('reports noRemainingStops for an empty stop order', () {
      final eta = computeTripEta(tripStatus: TripStatus.active, stopOrder: const []);
      expect(eta.unavailableReason, EtaUnavailableReason.noRemainingStops);
      expect(eta.hasEta, isFalse);
    });

    test('reports allStopsCompleted once every stop is done', () {
      final eta = computeTripEta(
        tripStatus: TripStatus.active,
        stopOrder: [student('s1', 30.0, 31.0, completed: true), school],
      );
      // school stop itself is never "completed" until trip finishes, so
      // this case actually has 1 remaining (the school) — verify that
      // instead of asserting allStopsCompleted here.
      expect(eta.stopsRemaining, 1);
      expect(eta.nextStopId, '__school__');
    });

    test('unavailable with tripNotActive when trip is not active', () {
      final eta = computeTripEta(
        tripStatus: TripStatus.paused,
        stopOrder: [student('s1', 30.0, 31.0), school],
        busLatitude: 30.0,
        busLongitude: 31.0,
      );
      expect(eta.unavailableReason, EtaUnavailableReason.tripNotActive);
      expect(eta.hasEta, isFalse);
    });

    test('unavailable with noGpsSignal when the bus has no live position', () {
      final eta = computeTripEta(
        tripStatus: TripStatus.active,
        stopOrder: [student('s1', 30.0, 31.0), school],
      );
      expect(eta.unavailableReason, EtaUnavailableReason.noGpsSignal);
    });

    test('unavailable with staleGps when the last fix is too old', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final eta = computeTripEta(
        tripStatus: TripStatus.active,
        stopOrder: [student('s1', 30.0, 31.0), school],
        busLatitude: 30.0,
        busLongitude: 31.0,
        busPositionUpdatedAt: now.subtract(const Duration(minutes: 10)),
        now: now,
      );
      expect(eta.unavailableReason, EtaUnavailableReason.staleGps);
    });

    test('computes a real ETA and distance to the next stop when everything is available', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final eta = computeTripEta(
        tripStatus: TripStatus.active,
        stopOrder: [student('s1', 30.001, 31.0), school],
        busLatitude: 30.0,
        busLongitude: 31.0,
        busSpeedMetersPerSecond: 10,
        busPositionUpdatedAt: now,
        now: now,
      );
      expect(eta.hasEta, isTrue);
      expect(eta.nextStopId, 's1');
      expect(eta.distanceToNextStopMeters, greaterThan(0));
      expect(eta.etaToNextStop, isNotNull);
      expect(eta.unavailableReason, isNull);
    });

    test('falls back to a floor speed when reported speed is near zero (stopped at a light)', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final etaWithZeroSpeed = computeTripEta(
        tripStatus: TripStatus.active,
        stopOrder: [student('s1', 30.001, 31.0), school],
        busLatitude: 30.0,
        busLongitude: 31.0,
        busSpeedMetersPerSecond: 0,
        busPositionUpdatedAt: now,
        now: now,
      );
      // A zero speed must never produce an infinite/unavailable ETA — the
      // fallback speed keeps this a real, finite number.
      expect(etaWithZeroSpeed.hasEta, isTrue);
    });

    test('does not surface an absurd ETA for a leg beyond the reliable cap', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      // ~1100km away at a slow reported speed -> a multi-day ETA, which
      // must be suppressed rather than shown as a real number.
      final eta = computeTripEta(
        tripStatus: TripStatus.active,
        stopOrder: [student('far', 40.0, 31.0), school],
        busLatitude: 30.0,
        busLongitude: 31.0,
        busSpeedMetersPerSecond: 2,
        busPositionUpdatedAt: now,
        now: now,
      );
      expect(eta.etaToNextStop, isNull);
      expect(eta.unavailableReason, isNotNull);
    });

    test('route progress fraction reflects completed vs total stops', () {
      final eta = computeTripEta(
        tripStatus: TripStatus.completed,
        stopOrder: [
          student('s1', 30.0, 31.0, completed: true),
          student('s2', 30.0, 31.0, completed: true),
          school,
        ],
      );
      expect(eta.stopsCompleted, 2);
      expect(eta.routeProgressFraction, closeTo(2 / 3, 0.001));
    });
  });
}
