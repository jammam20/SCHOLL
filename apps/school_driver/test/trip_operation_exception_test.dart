import 'package:flutter_test/flutter_test.dart';
import 'package:school_driver/features/trips/domain/trip_operation_exception.dart';
import 'package:school_shared/school_shared.dart';

void main() {
  group('assertCanTransition', () {
    test('allows a valid transition without throwing', () {
      expect(
        () => assertCanTransition(TripStatus.active, TripStatus.paused),
        returnsNormally,
      );
    });

    test('rejects an invalid transition with a specific message', () {
      expect(
        () => assertCanTransition(TripStatus.scheduled, TripStatus.completed),
        throwsA(
          isA<TripOperationException>()
              .having((e) => e.error, 'error', TripOperationError.invalidTransition)
              .having((e) => e.message, 'message', contains('scheduled'))
              .having((e) => e.message, 'message', contains('completed')),
        ),
      );
    });
  });

  group('assertOwnership', () {
    test('allows the assigned driver', () {
      expect(
        () => assertOwnership(tripDriverId: 'driver-1', currentUserId: 'driver-1'),
        returnsNormally,
      );
    });

    test('rejects a different driver', () {
      expect(
        () => assertOwnership(tripDriverId: 'driver-1', currentUserId: 'driver-2'),
        throwsA(
          isA<TripOperationException>()
              .having((e) => e.error, 'error', TripOperationError.unauthorized),
        ),
      );
    });
  });

  group('checkBoardingEligibility', () {
    const stopOrder = ['student-1', 'student-2', '__school__'];

    test('eligible when active, on the trip, present, and not yet boarded', () {
      final result = checkBoardingEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {},
        studentId: 'student-1',
        studentIsAbsentToday: false,
      );
      expect(result, BoardingEligibility.eligible);
    });

    test('already boarded is reported distinctly (not an error) for idempotency', () {
      final result = checkBoardingEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {'student-1'},
        studentId: 'student-1',
        studentIsAbsentToday: false,
      );
      expect(result, BoardingEligibility.alreadyBoarded);
    });

    test('an absent student cannot be boarded', () {
      final result = checkBoardingEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {},
        studentId: 'student-1',
        studentIsAbsentToday: true,
      );
      expect(result, BoardingEligibility.absent);
    });

    test('boarding is refused when the trip is not active', () {
      for (final status in [
        TripStatus.scheduled,
        TripStatus.starting,
        TripStatus.paused,
        TripStatus.completed,
        TripStatus.cancelled,
        TripStatus.emergency,
      ]) {
        final result = checkBoardingEligibility(
          tripStatus: status,
          stopOrder: stopOrder,
          boardedStudents: {},
          studentId: 'student-1',
          studentIsAbsentToday: false,
        );
        expect(result, BoardingEligibility.tripNotActive, reason: 'status: $status');
      }
    });

    test('a student not on this trip is refused', () {
      final result = checkBoardingEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {},
        studentId: 'someone-elses-kid',
        studentIsAbsentToday: false,
      );
      expect(result, BoardingEligibility.studentNotOnTrip);
    });

    test('multiple students remain independently tracked', () {
      final boarded = {'student-1'};
      expect(
        checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: stopOrder,
          boardedStudents: boarded,
          studentId: 'student-1',
          studentIsAbsentToday: false,
        ),
        BoardingEligibility.alreadyBoarded,
      );
      expect(
        checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: stopOrder,
          boardedStudents: boarded,
          studentId: 'student-2',
          studentIsAbsentToday: false,
        ),
        BoardingEligibility.eligible,
      );
    });
  });

  group('isValidStopReorder', () {
    test('accepts a reorder of exactly the same stops', () {
      expect(
        isValidStopReorder(
          currentOrder: ['a', 'b', '__school__'],
          newOrder: ['b', 'a', '__school__'],
        ),
        isTrue,
      );
    });

    test('rejects a reorder that drops a stop', () {
      expect(
        isValidStopReorder(
          currentOrder: ['a', 'b', '__school__'],
          newOrder: ['a', '__school__'],
        ),
        isFalse,
      );
    });

    test('rejects a reorder that invents a new stop', () {
      expect(
        isValidStopReorder(
          currentOrder: ['a', 'b', '__school__'],
          newOrder: ['a', 'b', 'c', '__school__'],
        ),
        isFalse,
      );
    });

    test('rejects a reorder with a duplicated stop', () {
      expect(
        isValidStopReorder(
          currentOrder: ['a', 'b', '__school__'],
          newOrder: ['a', 'a', '__school__'],
        ),
        isFalse,
      );
    });
  });
}
