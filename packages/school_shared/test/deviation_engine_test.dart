import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  // A short straight path running north along longitude 31.0.
  final path = [
    const TripStopPoint(stopId: 'a', latitude: 30.00, longitude: 31.00, isCompleted: false),
    const TripStopPoint(stopId: 'b', latitude: 30.02, longitude: 31.00, isCompleted: false),
  ];

  group('evaluateDeviation', () {
    test('stays normal while within tolerance of the path', () {
      final result = evaluateDeviation(
        previousStatus: DeviationStatus.normal,
        previousMaxDeviationMeters: 0,
        busLatitude: 30.01,
        busLongitude: 31.0005,
        stopOrder: path,
        toleranceMeters: 400,
      );
      expect(result.status, DeviationStatus.normal);
      expect(result.shouldAlert, isFalse);
    });

    test('transitions normal -> deviationStarted exactly once and alerts', () {
      final result = evaluateDeviation(
        previousStatus: DeviationStatus.normal,
        previousMaxDeviationMeters: 0,
        busLatitude: 30.01,
        busLongitude: 31.02, // far east of the path
        stopOrder: path,
        toleranceMeters: 400,
      );
      expect(result.status, DeviationStatus.deviationStarted);
      expect(result.shouldAlert, isTrue);
      expect(result.distanceMeters, greaterThan(400));
    });

    test('does not re-alert on a subsequent update while still deviating', () {
      final result = evaluateDeviation(
        previousStatus: DeviationStatus.deviationStarted,
        previousMaxDeviationMeters: 500,
        busLatitude: 30.01,
        busLongitude: 31.025,
        stopOrder: path,
        toleranceMeters: 400,
      );
      expect(result.status, DeviationStatus.deviating);
      expect(result.shouldAlert, isFalse);
      expect(result.episodeEnded, isFalse);
    });

    test('tracks the maximum deviation distance across the episode', () {
      final result = evaluateDeviation(
        previousStatus: DeviationStatus.deviating,
        previousMaxDeviationMeters: 300,
        busLatitude: 30.01,
        busLongitude: 31.05, // further than the previous max
        stopOrder: path,
        toleranceMeters: 400,
      );
      expect(result.maxDeviationMeters, greaterThan(300));
    });

    test('transitions deviating -> deviationEnded once back within tolerance', () {
      final result = evaluateDeviation(
        previousStatus: DeviationStatus.deviating,
        previousMaxDeviationMeters: 600,
        busLatitude: 30.01,
        busLongitude: 31.0005,
        stopOrder: path,
        toleranceMeters: 400,
      );
      expect(result.status, DeviationStatus.deviationEnded);
      expect(result.episodeEnded, isTrue);
      expect(result.shouldAlert, isFalse);
      // The closed episode still reports its historical max, not 0.
      expect(result.maxDeviationMeters, 600);
    });

    test('a normal update after deviationEnded resets max to 0', () {
      final result = evaluateDeviation(
        previousStatus: DeviationStatus.deviationEnded,
        previousMaxDeviationMeters: 600,
        busLatitude: 30.01,
        busLongitude: 31.0005,
        stopOrder: path,
        toleranceMeters: 400,
      );
      expect(result.status, DeviationStatus.normal);
      expect(result.maxDeviationMeters, 0);
    });

    test('handles a single-stop path via straight distance to that point', () {
      final result = evaluateDeviation(
        previousStatus: DeviationStatus.normal,
        previousMaxDeviationMeters: 0,
        busLatitude: 30.0,
        busLongitude: 31.0,
        stopOrder: const [
          TripStopPoint(stopId: 'only', latitude: 30.0, longitude: 31.0, isCompleted: false),
        ],
        toleranceMeters: 400,
      );
      expect(result.distanceMeters, closeTo(0, 1));
      expect(result.status, DeviationStatus.normal);
    });
  });
}
