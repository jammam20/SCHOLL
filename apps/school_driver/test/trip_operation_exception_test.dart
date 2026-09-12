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
        droppedOffStudents: {},
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
        droppedOffStudents: {},
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
        droppedOffStudents: {},
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
          droppedOffStudents: {},
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
        droppedOffStudents: {},
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
          droppedOffStudents: {},
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
          droppedOffStudents: {},
          studentId: 'student-2',
          studentIsAbsentToday: false,
        ),
        BoardingEligibility.eligible,
      );
    });

    group('bus capacity (production hardening)', () {
      test('no configured capacity never blocks boarding', () {
        final result = checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: stopOrder,
          boardedStudents: {'student-1'},
          droppedOffStudents: {},
          studentId: 'student-2',
          studentIsAbsentToday: false,
          busCapacity: null,
        );
        expect(result, BoardingEligibility.eligible);
      });

      test('capacity of 1: the first boarding is eligible', () {
        final result = checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: stopOrder,
          boardedStudents: {},
          droppedOffStudents: {},
          studentId: 'student-1',
          studentIsAbsentToday: false,
          busCapacity: 1,
        );
        expect(result, BoardingEligibility.eligible);
      });

      test('capacity of 1: a second boarding while the first is still aboard is refused', () {
        final result = checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: stopOrder,
          boardedStudents: {'student-1'},
          droppedOffStudents: {},
          studentId: 'student-2',
          studentIsAbsentToday: false,
          busCapacity: 1,
        );
        expect(result, BoardingEligibility.busAtCapacity);
      });

      test('exactly at capacity (29 of 30) allows the 30th boarding', () {
        final boarded = {for (var i = 0; i < 29; i++) 'student-$i'};
        final result = checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: [...boarded, 'student-29', '__school__'],
          boardedStudents: boarded,
          droppedOffStudents: {},
          studentId: 'student-29',
          studentIsAbsentToday: false,
          busCapacity: 30,
        );
        expect(result, BoardingEligibility.eligible);
      });

      test('one student over capacity (30 of 30) is refused', () {
        final boarded = {for (var i = 0; i < 30; i++) 'student-$i'};
        final result = checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: [...boarded, 'student-30', '__school__'],
          boardedStudents: boarded,
          droppedOffStudents: {},
          studentId: 'student-30',
          studentIsAbsentToday: false,
          busCapacity: 30,
        );
        expect(result, BoardingEligibility.busAtCapacity);
      });

      test('a drop-off frees a seat for the next boarding', () {
        // 2 boarded, 1 already dropped off -> 1 truly onboard right now,
        // so a bus with capacity 2 has exactly one free seat left.
        final freedSeatResult = checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: [...stopOrder, 'student-3'],
          boardedStudents: {'student-1', 'student-2'},
          droppedOffStudents: {'student-1'},
          studentId: 'student-3',
          studentIsAbsentToday: false,
          busCapacity: 2,
        );
        expect(freedSeatResult, BoardingEligibility.eligible);
      });

      test('capacity is checked before the absence check', () {
        // Documents precedence: an absent student at a full bus is still
        // reported as busAtCapacity-irrelevant since absence is checked
        // first in the function body — this test pins that order so a
        // future reorder is a deliberate choice, not an accident.
        final result = checkBoardingEligibility(
          tripStatus: TripStatus.active,
          stopOrder: stopOrder,
          boardedStudents: {'student-1'},
          droppedOffStudents: {},
          studentId: 'student-2',
          studentIsAbsentToday: true,
          busCapacity: 1,
        );
        expect(result, BoardingEligibility.absent);
      });
    });
  });

  group('checkDropOffEligibility', () {
    const stopOrder = ['student-1', 'student-2', '__school__'];

    test('eligible when active, on the trip, boarded, and not yet dropped off', () {
      final result = checkDropOffEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {'student-1'},
        droppedOffStudents: {},
        studentId: 'student-1',
      );
      expect(result, DropOffEligibility.eligible);
    });

    test('already dropped off is reported distinctly (not an error) for idempotency', () {
      final result = checkDropOffEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {'student-1'},
        droppedOffStudents: {'student-1'},
        studentId: 'student-1',
      );
      expect(result, DropOffEligibility.alreadyDroppedOff);
    });

    test('a student who never boarded cannot be dropped off', () {
      final result = checkDropOffEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {},
        droppedOffStudents: {},
        studentId: 'student-1',
      );
      expect(result, DropOffEligibility.notBoarded);
    });

    test('an already-dropped-off student stays idempotent even if unboarded', () {
      final result = checkDropOffEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {},
        droppedOffStudents: {'student-1'},
        studentId: 'student-1',
      );
      expect(result, DropOffEligibility.alreadyDroppedOff);
    });

    test('drop-off is refused when the trip is not active', () {
      for (final status in [
        TripStatus.scheduled,
        TripStatus.starting,
        TripStatus.paused,
        TripStatus.completed,
        TripStatus.cancelled,
        TripStatus.emergency,
      ]) {
        final result = checkDropOffEligibility(
          tripStatus: status,
          stopOrder: stopOrder,
          boardedStudents: {'student-1'},
          droppedOffStudents: {},
          studentId: 'student-1',
        );
        expect(result, DropOffEligibility.tripNotActive, reason: 'status: $status');
      }
    });

    test('a student not on this trip is refused', () {
      final result = checkDropOffEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {'someone-elses-kid'},
        droppedOffStudents: {},
        studentId: 'someone-elses-kid',
      );
      expect(result, DropOffEligibility.studentNotOnTrip);
    });

    test('multiple students remain independently tracked', () {
      final boarded = {'student-1', 'student-2'};
      final droppedOff = {'student-1'};
      expect(
        checkDropOffEligibility(
          tripStatus: TripStatus.active,
          stopOrder: stopOrder,
          boardedStudents: boarded,
          droppedOffStudents: droppedOff,
          studentId: 'student-1',
        ),
        DropOffEligibility.alreadyDroppedOff,
      );
      expect(
        checkDropOffEligibility(
          tripStatus: TripStatus.active,
          stopOrder: stopOrder,
          boardedStudents: boarded,
          droppedOffStudents: droppedOff,
          studentId: 'student-2',
        ),
        DropOffEligibility.eligible,
      );
    });

    test('the school sentinel stop is never a droppable student', () {
      // It is in the stop order, but nobody ever boards it, so the only
      // honest answer is "not boarded" rather than eligible.
      final result = checkDropOffEligibility(
        tripStatus: TripStatus.active,
        stopOrder: stopOrder,
        boardedStudents: {'student-1'},
        droppedOffStudents: {},
        studentId: '__school__',
      );
      expect(result, DropOffEligibility.notBoarded);
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

  group('tripNeedingTracking', () {
    SchoolTrip trip(String id, TripStatus status) => SchoolTrip(
      id: id,
      schoolId: 'school-1',
      routeId: 'route-1',
      busId: 'bus-1',
      driverId: 'driver-1',
      status: status,
      scheduledAt: DateTime(2026, 1, 1),
    );

    test('returns the active trip when one exists', () {
      final trips = [
        trip('t1', TripStatus.scheduled),
        trip('t2', TripStatus.active),
        trip('t3', TripStatus.completed),
      ];
      expect(tripNeedingTracking(trips)?.id, 't2');
    });

    test('returns the emergency trip when one exists', () {
      final trips = [trip('t1', TripStatus.emergency)];
      expect(tripNeedingTracking(trips)?.id, 't1');
    });

    test('returns null when no trip is active or in emergency', () {
      final trips = [
        trip('t1', TripStatus.scheduled),
        trip('t2', TripStatus.paused),
        trip('t3', TripStatus.completed),
        trip('t4', TripStatus.cancelled),
      ];
      expect(tripNeedingTracking(trips), isNull);
    });

    test('returns null for an empty trip list', () {
      expect(tripNeedingTracking(const []), isNull);
    });

    test('a paused trip is not returned, matching stopTracking on pause', () {
      final trips = [trip('t1', TripStatus.paused)];
      expect(tripNeedingTracking(trips), isNull);
    });
  });
}
