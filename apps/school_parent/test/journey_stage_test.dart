import 'package:flutter_test/flutter_test.dart';
import 'package:school_parent/features/trips/domain/journey_stage.dart';
import 'package:school_shared/school_shared.dart';

/// Feature: two daily trips / unified child transportation status.
/// Outbound behavior is covered implicitly by every existing call site
/// (default direction) — this focuses on the return-direction branch,
/// which is genuinely new logic, not a rebuild of anything outbound.
void main() {
  group('computeJourneyStage — return direction', () {
    test('an active return trip with no live position yet reads as started', () {
      final stage = computeJourneyStage(
        const JourneyInputs(
          tripStatus: TripStatus.active,
          hasBoarded: true,
          direction: TripDirection.returnTrip,
        ),
      );
      expect(stage, JourneyStage.started);
    });

    test('far from home reads as onTheWay, not continuingToSchool', () {
      final stage = computeJourneyStage(
        const JourneyInputs(
          tripStatus: TripStatus.active,
          hasBoarded: true,
          direction: TripDirection.returnTrip,
          distanceToPickupMeters: 5000,
        ),
      );
      expect(stage, JourneyStage.onTheWay);
    });

    test('within approaching range reads as approachingPickup', () {
      final stage = computeJourneyStage(
        const JourneyInputs(
          tripStatus: TripStatus.active,
          hasBoarded: true,
          direction: TripDirection.returnTrip,
          distanceToPickupMeters: 500,
        ),
      );
      expect(stage, JourneyStage.approachingPickup);
    });

    test('within arrival range reads as arrivedAtPickup', () {
      final stage = computeJourneyStage(
        const JourneyInputs(
          tripStatus: TripStatus.active,
          hasBoarded: true,
          direction: TripDirection.returnTrip,
          distanceToPickupMeters: 50,
        ),
      );
      expect(stage, JourneyStage.arrivedAtPickup);
    });

    test('isDroppedOff wins over distance — the terminal per-child event', () {
      final stage = computeJourneyStage(
        const JourneyInputs(
          tripStatus: TripStatus.active,
          hasBoarded: true,
          direction: TripDirection.returnTrip,
          distanceToPickupMeters: 5000, // still far, but already dropped off
          isDroppedOff: true,
        ),
      );
      expect(stage, JourneyStage.droppedOff);
    });

    test('a scheduled/cancelled/emergency return trip behaves identically '
        'to outbound (direction only changes the active-trip branch)', () {
      for (final status in [
        TripStatus.scheduled,
        TripStatus.cancelled,
        TripStatus.emergency,
        TripStatus.paused,
      ]) {
        final outbound = computeJourneyStage(
          JourneyInputs(tripStatus: status, hasBoarded: false),
        );
        final returnDirection = computeJourneyStage(
          JourneyInputs(
            tripStatus: status,
            hasBoarded: false,
            direction: TripDirection.returnTrip,
          ),
        );
        expect(returnDirection, outbound, reason: 'status: $status');
      }
    });
  });

  group('reachedStepCount — droppedOff', () {
    test('droppedOff reaches the end of the (shorter) return path', () {
      expect(
        reachedStepCount(JourneyStage.droppedOff, hasBoarded: true),
        returnJourneyPath.length,
      );
    });
  });

  group('returnJourneyPath', () {
    test('is shorter than the outbound path and never includes boarded/'
        'continuingToSchool/arrivedAtSchool', () {
      expect(returnJourneyPath.length, lessThan(mainJourneyPath.length));
      expect(returnJourneyPath, isNot(contains(JourneyStage.boarded)));
      expect(
        returnJourneyPath,
        isNot(contains(JourneyStage.continuingToSchool)),
      );
      expect(
        returnJourneyPath,
        isNot(contains(JourneyStage.arrivedAtSchool)),
      );
      expect(returnJourneyPath, contains(JourneyStage.droppedOff));
    });
  });
}
