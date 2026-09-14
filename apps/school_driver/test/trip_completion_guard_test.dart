import 'package:flutter_test/flutter_test.dart';
import 'package:school_driver/features/trips/domain/trip_completion_guard.dart';
import 'package:school_shared/school_shared.dart';

TripCompletionInputs inputs({
  TripDirection direction = TripDirection.outbound,
  List<String> stopOrder = const ['s1', 's2'],
  Set<String> boarded = const {'s1', 's2'},
  Set<String> dropped = const {'s1', 's2'},
  Set<String> excused = const {},
  double? metresFromSchool = 20,
  bool schoolHasLocation = true,
  bool hasPositionFix = true,
}) {
  return TripCompletionInputs(
    direction: direction,
    stopOrder: stopOrder,
    boardedStudents: boarded,
    droppedOffStudents: dropped,
    excusedStudents: excused,
    metresFromSchool: metresFromSchool,
    schoolHasLocation: schoolHasLocation,
    hasPositionFix: hasPositionFix,
  );
}

void main() {
  group('checkTripCompletion', () {
    test('a fully handled outbound trip at the school can be completed', () {
      expect(checkTripCompletion(inputs()), isNull);
    });

    test('a student who never boarded and was never excused blocks it', () {
      expect(
        checkTripCompletion(inputs(boarded: {'s1'}, dropped: {'s1'})),
        TripCompletionBlocker.studentsUnaccountedFor,
      );
    });

    test('an absent student counts as accounted for', () {
      expect(
        checkTripCompletion(
          inputs(boarded: {'s1'}, dropped: {'s1'}, excused: {'s2'}),
        ),
        isNull,
      );
    });

    test('a student still on board blocks it', () {
      expect(
        checkTripCompletion(inputs(dropped: {'s1'})),
        TripCompletionBlocker.studentsStillOnBoard,
      );
    });

    test('a child still aboard is reported before a location problem', () {
      // A driver parked in the school yard with a child still on the bus
      // must hear about the child, not about where they are standing.
      expect(
        checkTripCompletion(inputs(dropped: {'s1'}, metresFromSchool: 9000)),
        TripCompletionBlocker.studentsStillOnBoard,
      );
    });

    test('an outbound trip far from the school cannot be completed', () {
      expect(
        checkTripCompletion(inputs(metresFromSchool: 2500)),
        TripCompletionBlocker.notAtSchool,
      );
    });

    test('the radius forgives a large campus and ordinary GPS drift', () {
      expect(checkTripCompletion(inputs(metresFromSchool: 280)), isNull);
      expect(
        checkTripCompletion(inputs(metresFromSchool: 320)),
        TripCompletionBlocker.notAtSchool,
      );
    });

    test('an unverifiable arrival is blocked, never waved through', () {
      expect(
        checkTripCompletion(inputs(schoolHasLocation: false)),
        TripCompletionBlocker.schoolLocationUnknown,
      );
      expect(
        checkTripCompletion(inputs(hasPositionFix: false)),
        TripCompletionBlocker.positionUnknown,
      );
      expect(
        checkTripCompletion(inputs(metresFromSchool: null)),
        TripCompletionBlocker.positionUnknown,
      );
    });

    test('a return trip ends at a home, so no school check applies', () {
      expect(
        checkTripCompletion(
          inputs(direction: TripDirection.returnTrip, metresFromSchool: 9000),
        ),
        isNull,
      );
      // It still has to hand every child over.
      expect(
        checkTripCompletion(
          inputs(
            direction: TripDirection.returnTrip,
            dropped: {'s1'},
            metresFromSchool: 9000,
          ),
        ),
        TripCompletionBlocker.studentsStillOnBoard,
      );
    });

    test('an empty run completes without a roster complaint', () {
      expect(
        checkTripCompletion(
          inputs(stopOrder: const [], boarded: const {}, dropped: const {}),
        ),
        isNull,
      );
    });

    test('a boarding recorded for someone off the manifest is ignored', () {
      // Defensive: stale client state must not be able to wedge a trip
      // closed forever by referencing a student who isn't on this run.
      expect(
        checkTripCompletion(
          inputs(boarded: {'s1', 's2', 'ghost'}, dropped: {'s1', 's2'}),
        ),
        isNull,
      );
    });
  });

  group('studentsStillOnBoard', () {
    test('returns exactly who has not been handed over', () {
      expect(
        studentsStillOnBoard(
          stopOrder: const ['s1', 's2', 's3'],
          boardedStudents: const {'s1', 's2', 's3'},
          droppedOffStudents: const {'s2'},
        ),
        {'s1', 's3'},
      );
    });

    test('ignores boardings for students not on this run', () {
      expect(
        studentsStillOnBoard(
          stopOrder: const ['s1'],
          boardedStudents: const {'s1', 'ghost'},
          droppedOffStudents: const {},
        ),
        {'s1'},
      );
    });
  });
}
