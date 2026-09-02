import 'package:school_shared/school_shared.dart';

/// How far along a single trip is, from one child's point of view. Ordered
/// so `index` (for the "main path" stages) can drive a linear timeline —
/// [noActiveTrip], [paused], [cancelled] and [emergency] are side-states
/// that interrupt or precede that path rather than sitting on it.
///
/// Every stage here is derived from data the app already has (trip.status,
/// trip.startedAt, the boardedStudents set, and — once the bus is
/// broadcasting — its live distance to the child's pickup point and to the
/// school). Nothing is invented: with no live position yet, the stage
/// simply doesn't advance past [started].
enum JourneyStage {
  noActiveTrip,
  scheduled,
  delayed,
  started,
  onTheWay,
  approachingPickup,
  arrivedAtPickup,
  boarded,
  continuingToSchool,
  arrivedAtSchool,
  // Feature: two daily trips / unified child transportation status. A
  // return trip's meaningful per-child milestone is being handed off at
  // their own drop-off point, not a shared "arrived at school" moment —
  // see computeJourneyStage's TripDirection.returnTrip branch. Never
  // emitted for an outbound trip.
  droppedOff,
  completed,
  paused,
  emergency,
  cancelled,
}

/// The 9-step path a normal trip walks through, in order. Used to render
/// completed/current/upcoming — [JourneyStage] values outside this list
/// (noActiveTrip, delayed, paused, emergency, cancelled) are side-states
/// handled separately by the UI, not positions on this timeline.
const mainJourneyPath = [
  JourneyStage.scheduled,
  JourneyStage.started,
  JourneyStage.onTheWay,
  JourneyStage.approachingPickup,
  JourneyStage.arrivedAtPickup,
  JourneyStage.boarded,
  JourneyStage.continuingToSchool,
  JourneyStage.arrivedAtSchool,
  JourneyStage.completed,
];

/// The return-trip equivalent of [mainJourneyPath] (Feature: two daily
/// trips). Deliberately shorter and in a different order than the outbound
/// path — a return trip's students are already aboard when it leaves the
/// school (there is no shared "arrived" moment to walk toward; each child's
/// own drop-off is the destination), so "boarded" isn't a step worth
/// showing here and [JourneyStage.droppedOff] replaces "arrived at
/// school"/"completed" as the meaningful last step. Reuses the *same*
/// enum values as the shared early positions (started/onTheWay/
/// approachingPickup/arrivedAtPickup) since the underlying distance-based
/// computation is identical — only the on-screen wording differs, per
/// direction, in journey_stage_visuals.dart.
const returnJourneyPath = [
  JourneyStage.scheduled,
  JourneyStage.started,
  JourneyStage.onTheWay,
  JourneyStage.approachingPickup,
  JourneyStage.arrivedAtPickup,
  JourneyStage.droppedOff,
];

/// A bus is considered "at" a point once within this many meters — mirrors
/// the threshold LiveTripMap already used for "arriving at pickup point".
const arrivedProximityMeters = 100.0;

/// Beyond [arrivedProximityMeters] but within this range, the bus reads as
/// "approaching" rather than just "on the way".
const approachingProximityMeters = 800.0;

/// How long after its scheduled time a still-unstarted trip reads as
/// [JourneyStage.delayed] instead of just [JourneyStage.scheduled].
const delayedGrace = Duration(minutes: 10);

/// Everything the stage computation needs, gathered from the trip document,
/// the boardedStudents field, and (once available) the driver's live RTDB
/// position relative to the child's pickup point and the school. All
/// optional/derived fields are `null` when that data isn't available yet
/// (e.g. the bus hasn't started broadcasting) — the computation treats
/// "unknown" as "hasn't happened", never guesses.
class JourneyInputs {
  const JourneyInputs({
    required this.tripStatus,
    required this.hasBoarded,
    this.distanceToPickupMeters,
    this.distanceToSchoolMeters,
    this.now,
    this.scheduledAt,
    this.direction = TripDirection.outbound,
    this.isDroppedOff = false,
  });

  final TripStatus? tripStatus;
  final bool hasBoarded;
  final double? distanceToPickupMeters;
  final double? distanceToSchoolMeters;
  final DateTime? now;
  final DateTime? scheduledAt;

  // Feature: two daily trips / unified child transportation status.
  final TripDirection direction;

  // From TripStopProgress.isDroppedOff(studentId) — only meaningful for a
  // return trip; ignored for outbound, where drop-off is the shared
  // "arrived at school" moment instead of a per-child event.
  final bool isDroppedOff;
}

/// The single source of truth for "where is this child's journey right
/// now" — both the child card and the journey timeline read from this so
/// they can never disagree with each other.
JourneyStage computeJourneyStage(JourneyInputs input) {
  final status = input.tripStatus;
  if (status == null) return JourneyStage.noActiveTrip;

  switch (status) {
    case TripStatus.cancelled:
      return JourneyStage.cancelled;
    case TripStatus.emergency:
      return JourneyStage.emergency;
    case TripStatus.paused:
      return JourneyStage.paused;
    case TripStatus.scheduled:
      final now = input.now;
      final scheduledAt = input.scheduledAt;
      if (now != null &&
          scheduledAt != null &&
          now.difference(scheduledAt) > delayedGrace) {
        return JourneyStage.delayed;
      }
      return JourneyStage.scheduled;
    case TripStatus.starting:
      return JourneyStage.started;
    case TripStatus.active:
      if (input.direction == TripDirection.returnTrip) {
        // A return trip's students board at the school before it departs —
        // there is no live "approaching the pickup" moment for that, so
        // boarding isn't rendered as a step (see returnJourneyPath). The
        // one per-child event worth tracking is being dropped off at their
        // own point, which distanceToPickupMeters already measures
        // correctly (it's always "distance from the bus to this student's
        // own location", pickup or drop-off alike).
        if (input.isDroppedOff) return JourneyStage.droppedOff;

        final toDropoff = input.distanceToPickupMeters;
        if (toDropoff == null) return JourneyStage.started;
        if (toDropoff <= arrivedProximityMeters) {
          return JourneyStage.arrivedAtPickup;
        }
        if (toDropoff <= approachingProximityMeters) {
          return JourneyStage.approachingPickup;
        }
        return JourneyStage.onTheWay;
      }

      if (input.hasBoarded) {
        final toSchool = input.distanceToSchoolMeters;
        if (toSchool != null && toSchool <= arrivedProximityMeters) {
          return JourneyStage.arrivedAtSchool;
        }
        return JourneyStage.continuingToSchool;
      }

      final toPickup = input.distanceToPickupMeters;
      if (toPickup == null) return JourneyStage.started;
      if (toPickup <= arrivedProximityMeters) {
        return JourneyStage.arrivedAtPickup;
      }
      if (toPickup <= approachingProximityMeters) {
        return JourneyStage.approachingPickup;
      }
      return JourneyStage.onTheWay;
    case TripStatus.completed:
      return JourneyStage.completed;
  }
}

/// Which [mainJourneyPath] steps are already behind us, for a completed/
/// current/upcoming timeline render. A side-state (delayed/paused/
/// emergency/cancelled/noActiveTrip) still has a well-defined "how far did
/// we get" position — e.g. [JourneyStage.paused] means everything up to
/// [JourneyStage.onTheWay] (say) already happened before the pause.
int reachedStepCount(JourneyStage stage, {required bool hasBoarded}) {
  switch (stage) {
    case JourneyStage.noActiveTrip:
      return 0;
    case JourneyStage.scheduled:
    case JourneyStage.delayed:
      return 1;
    case JourneyStage.started:
      return 2;
    case JourneyStage.onTheWay:
      return 3;
    case JourneyStage.approachingPickup:
      return 4;
    case JourneyStage.arrivedAtPickup:
      return 5;
    case JourneyStage.boarded:
      return 6;
    case JourneyStage.continuingToSchool:
      return 7;
    case JourneyStage.arrivedAtSchool:
      return 8;
    case JourneyStage.droppedOff:
      return returnJourneyPath.length;
    case JourneyStage.completed:
      return 9;
    case JourneyStage.paused:
    case JourneyStage.emergency:
      // Best-effort: we know whether boarding happened, which is the one
      // sub-stage that can't be inferred from "how far along" alone once
      // live position isn't the deciding factor anymore.
      return hasBoarded ? 6 : 2;
    case JourneyStage.cancelled:
      return hasBoarded ? 6 : 1;
  }
}
