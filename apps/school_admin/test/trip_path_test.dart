import 'package:flutter_test/flutter_test.dart';
import 'package:school_admin/features/ops/domain/trip_path.dart';
import 'package:school_shared/school_shared.dart';

Student _student(String id, {double? lat, double? lng}) => Student(
  id: id,
  schoolId: 'school-1',
  name: 'Student $id',
  isActive: true,
  latitude: lat,
  longitude: lng,
);

void main() {
  group('buildTripPath', () {
    test('resolves stops in order and numbers them from 1', () {
      final path = buildTripPath(
        stopOrder: const ['a', 'b'],
        studentsById: {
          'a': _student('a', lat: 30.0, lng: 31.0),
          'b': _student('b', lat: 30.1, lng: 31.1),
        },
        boardedStudentIds: const [],
        droppedOffStudentIds: const [],
      );

      expect(path.map((s) => s.stopId), ['a', 'b']);
      expect(path.map((s) => s.sequence), [1, 2]);
      expect(path.every((s) => s.progress == TripStopProgress.pending), isTrue);
    });

    test('appends the school for the __school__ sentinel', () {
      final path = buildTripPath(
        stopOrder: const ['a', schoolStopSentinel],
        studentsById: {'a': _student('a', lat: 30.0, lng: 31.0)},
        boardedStudentIds: const [],
        droppedOffStudentIds: const [],
        schoolLatitude: 30.5,
        schoolLongitude: 31.5,
        schoolLabel: 'Test School',
      );

      expect(path, hasLength(2));
      expect(path.last.isSchool, isTrue);
      expect(path.last.label, 'Test School');
      expect(path.last.progress, TripStopProgress.school);
    });

    test('skips stops with no coordinate, keeping numbering contiguous', () {
      final path = buildTripPath(
        stopOrder: const ['a', 'missing', 'b'],
        studentsById: {
          'a': _student('a', lat: 30.0, lng: 31.0),
          // 'missing' has no student record at all.
          'b': _student('b', lat: 30.1, lng: 31.1),
        },
        boardedStudentIds: const [],
        droppedOffStudentIds: const [],
      );

      expect(path.map((s) => s.stopId), ['a', 'b']);
      expect(path.map((s) => s.sequence), [1, 2]);
    });

    test('skips the school stop when the school has no coordinate', () {
      final path = buildTripPath(
        stopOrder: const ['a', schoolStopSentinel],
        studentsById: {'a': _student('a', lat: 30.0, lng: 31.0)},
        boardedStudentIds: const [],
        droppedOffStudentIds: const [],
      );

      expect(path, hasLength(1));
      expect(path.single.isSchool, isFalse);
    });

    test('a student with a null latitude is skipped', () {
      final path = buildTripPath(
        stopOrder: const ['a'],
        studentsById: {'a': _student('a')},
        boardedStudentIds: const [],
        droppedOffStudentIds: const [],
      );

      expect(path, isEmpty);
    });

    test('droppedOff takes precedence over boarded', () {
      final path = buildTripPath(
        stopOrder: const ['a', 'b'],
        studentsById: {
          'a': _student('a', lat: 30.0, lng: 31.0),
          'b': _student('b', lat: 30.1, lng: 31.1),
        },
        boardedStudentIds: const ['a', 'b'],
        droppedOffStudentIds: const ['b'],
      );

      expect(path[0].progress, TripStopProgress.boarded);
      expect(path[1].progress, TripStopProgress.droppedOff);
    });
  });

  group('toEtaStopPoints', () {
    test('treats boarded and dropped-off stops as completed', () {
      final path = buildTripPath(
        stopOrder: const ['a', 'b', 'c'],
        studentsById: {
          'a': _student('a', lat: 30.0, lng: 31.0),
          'b': _student('b', lat: 30.1, lng: 31.1),
          'c': _student('c', lat: 30.2, lng: 31.2),
        },
        boardedStudentIds: const ['a'],
        droppedOffStudentIds: const ['b'],
      );

      final points = toEtaStopPoints(path);
      expect(points.map((p) => p.isCompleted), [true, true, false]);
    });

    test('feeds computeTripEta so the next stop is the first unhandled one', () {
      final path = buildTripPath(
        stopOrder: const ['a', 'b'],
        studentsById: {
          'a': _student('a', lat: 30.0, lng: 31.0),
          'b': _student('b', lat: 30.01, lng: 31.0),
        },
        boardedStudentIds: const ['a'],
        droppedOffStudentIds: const [],
      );

      final eta = computeTripEta(
        tripStatus: TripStatus.active,
        stopOrder: toEtaStopPoints(path),
        busLatitude: 30.005,
        busLongitude: 31.0,
        busSpeedMetersPerSecond: 8,
        busPositionUpdatedAt: DateTime.now(),
      );

      expect(eta.nextStopId, 'b');
      expect(eta.stopsCompleted, 1);
      expect(eta.etaToNextStop, isNotNull);
    });
  });

  group('closestPointOnPath', () {
    test('projects onto the nearest segment', () {
      final path = buildTripPath(
        stopOrder: const ['a', 'b'],
        studentsById: {
          'a': _student('a', lat: 30.0, lng: 31.0),
          'b': _student('b', lat: 30.0, lng: 31.1),
        },
        boardedStudentIds: const [],
        droppedOffStudentIds: const [],
      );

      // A point directly "north" of the middle of a due-east segment
      // projects back down onto that segment at roughly the same longitude.
      final nearest = closestPointOnPath(
        latitude: 30.01,
        longitude: 31.05,
        path: path,
      );

      expect(nearest, isNotNull);
      expect(nearest!.latitude, closeTo(30.0, 0.001));
      expect(nearest.longitude, closeTo(31.05, 0.001));
    });

    test('clamps to a segment endpoint when the bus is past the end', () {
      final path = buildTripPath(
        stopOrder: const ['a', 'b'],
        studentsById: {
          'a': _student('a', lat: 30.0, lng: 31.0),
          'b': _student('b', lat: 30.0, lng: 31.1),
        },
        boardedStudentIds: const [],
        droppedOffStudentIds: const [],
      );

      final nearest = closestPointOnPath(
        latitude: 30.0,
        longitude: 31.5,
        path: path,
      );

      expect(nearest, isNotNull);
      expect(nearest!.longitude, closeTo(31.1, 0.001));
    });

    test('returns null for a path with fewer than two points', () {
      final path = buildTripPath(
        stopOrder: const ['a'],
        studentsById: {'a': _student('a', lat: 30.0, lng: 31.0)},
        boardedStudentIds: const [],
        droppedOffStudentIds: const [],
      );

      expect(
        closestPointOnPath(latitude: 30.5, longitude: 31.5, path: path),
        isNull,
      );
    });
  });

  group('formatEtaMinutes', () {
    test('returns null for a null duration', () {
      expect(formatEtaMinutes(null), isNull);
    });

    test('collapses sub-minute ETAs', () {
      expect(formatEtaMinutes(const Duration(seconds: 20)), '<1 min');
    });

    test('renders whole minutes', () {
      expect(formatEtaMinutes(const Duration(minutes: 7, seconds: 30)), '7 min');
    });
  });
}
