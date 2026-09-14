import 'package:school_shared/school_shared.dart';

/// How close the bus has to actually be to the school before an outbound
/// trip may be closed as "arrived".
///
/// Deliberately looser than the parent app's 100 m "arrived at your stop"
/// threshold: a school is a compound, not a kerbside point, and the pin an
/// admin drops is usually on the gate rather than wherever the bus bay is.
/// 300 m forgives that and ordinary GPS drift while still being far too
/// tight to pass from the previous stop.
const schoolArrivalRadiusMetres = 300.0;

/// Why a trip cannot be completed yet.
///
/// Completion is the moment the trip's record becomes the permanent answer
/// to "where did every child end up today", so it must not be reachable
/// while that answer is still incomplete. Each blocker below is a state
/// where finishing would write a record that is silently wrong.
enum TripCompletionBlocker {
  /// Someone on the manifest is neither boarded nor reported absent — the
  /// record would simply not say what happened to them.
  studentsUnaccountedFor,

  /// Someone is still marked on board. Completing here would leave a child
  /// recorded as picked up and never handed over.
  studentsStillOnBoard,

  /// An outbound trip ends at the school, so the bus has to be there. This
  /// is what stops "arrived" from being a button a driver can press from
  /// anywhere.
  notAtSchool,

  /// The school has no location saved, so [notAtSchool] cannot be judged.
  /// Treated as a blocker rather than waved through: an unverifiable claim
  /// of arrival is exactly what this guard exists to prevent.
  schoolLocationUnknown,

  /// No GPS fix yet, so the bus's own position is unknown.
  positionUnknown,
}

/// Everything the guard needs. All of it is already in hand at the call
/// site — the trip document, the student manifest, and the driver app's own
/// last known position — so this stays a pure function with no I/O.
class TripCompletionInputs {
  const TripCompletionInputs({
    required this.direction,
    required this.stopOrder,
    required this.boardedStudents,
    required this.droppedOffStudents,
    required this.excusedStudents,
    this.metresFromSchool,
    this.schoolHasLocation = true,
    this.hasPositionFix = true,
  });

  final TripDirection direction;

  /// Student ids on today's run, in order. The school's own sentinel stop
  /// is filtered out by the caller.
  final List<String> stopOrder;

  final Set<String> boardedStudents;
  final Set<String> droppedOffStudents;

  /// Students who are legitimately not riding: marked absent by a parent or
  /// the school, or reported not-at-stop by this driver. They count as
  /// accounted for — the record will say why they never boarded.
  final Set<String> excusedStudents;

  final double? metresFromSchool;
  final bool schoolHasLocation;
  final bool hasPositionFix;
}

/// The first reason this trip cannot be completed, or null when it can.
///
/// Ordered deliberately: the roster problems come before the location one,
/// because a driver standing in the school yard with a child still on the
/// bus should be told about the child, not about where they are parked.
TripCompletionBlocker? checkTripCompletion(TripCompletionInputs input) {
  final riders = input.stopOrder.toSet();

  // 1 — nobody left in limbo.
  final unaccounted = riders.difference(
    input.boardedStudents.union(input.excusedStudents),
  );
  if (unaccounted.isNotEmpty) {
    return TripCompletionBlocker.studentsUnaccountedFor;
  }

  // 2 — nobody still aboard.
  final stillOnBoard = input.boardedStudents
      .intersection(riders)
      .difference(input.droppedOffStudents);
  if (stillOnBoard.isNotEmpty) {
    return TripCompletionBlocker.studentsStillOnBoard;
  }

  // 3 — an outbound trip has to actually end at the school. A return trip
  // ends at the last child's own stop, so there is nothing to check against.
  if (input.direction == TripDirection.outbound) {
    if (!input.schoolHasLocation) {
      return TripCompletionBlocker.schoolLocationUnknown;
    }
    if (!input.hasPositionFix || input.metresFromSchool == null) {
      return TripCompletionBlocker.positionUnknown;
    }
    if (input.metresFromSchool! > schoolArrivalRadiusMetres) {
      return TripCompletionBlocker.notAtSchool;
    }
  }

  return null;
}

/// Students who are on board right now — the set "Drop off all" acts on.
Set<String> studentsStillOnBoard({
  required List<String> stopOrder,
  required Set<String> boardedStudents,
  required Set<String> droppedOffStudents,
}) {
  return boardedStudents
      .intersection(stopOrder.toSet())
      .difference(droppedOffStudents);
}
