import 'package:school_shared/school_shared.dart';

/// Why a trip/boarding operation was refused — a stable, checkable
/// identity for callers (the bloc, tests) rather than string-matching a
/// message. [message] is a plain, driver-facing sentence (this app has no
/// l10n layer for trip action errors yet — see the existing
/// `state.actionError` convention in TripsBloc — so this matches that,
/// deliberately not raw Firestore/Dart exception text).
enum TripOperationError {
  invalidTransition,
  unauthorized,
  tripNotFound,
  studentNotOnTrip,
  studentAbsent,
  studentNotBoarded,
  tripNotActive,
  invalidStopOrder,
  emergencyAlreadyActive,
  emergencyNotFound,
  emergencyAlreadyResolved,
  locationUnavailable,
  // Production hardening: bus capacity server enforcement — the boarding
  // transaction re-reads the assigned bus's capacity and the trip's live
  // onboard count from the server on every attempt (see
  // StopOrderRepository.markBoarded), so this can never be bypassed by a
  // stale client count, and Firestore's own transaction retry-on-conflict
  // behavior makes two simultaneous boarding requests resolve one-at-a-time
  // rather than racing past each other.
  busCapacityExceeded,
}

class TripOperationException implements Exception {
  const TripOperationException(this.error, this.message);

  final TripOperationError error;
  final String message;

  @override
  String toString() => message;
}

/// Reuses TripStatus.canTransitionTo (school_shared) — the same state
/// machine firestore.rules' isValidTripTransition mirrors server-side —
/// instead of re-deciding valid transitions here. Throws with a message
/// naming the actual current/attempted statuses so "why was this
/// rejected" is never a mystery.
void assertCanTransition(TripStatus current, TripStatus next) {
  if (!current.canTransitionTo(next)) {
    throw TripOperationException(
      TripOperationError.invalidTransition,
      "Can't move this trip from ${current.name} to ${next.name}.",
    );
  }
}

/// Every write in this app is already scoped to `driverId == currentUser`
/// by both the trips query (TripsRepository.watchMyTrips) and
/// firestore.rules — this is a third, cheap check at the point of write,
/// for defense in depth against a stale/tampered client reference rather
/// than a gap either of those leaves open in normal use.
void assertOwnership({required String tripDriverId, required String currentUserId}) {
  if (tripDriverId != currentUserId) {
    throw const TripOperationException(
      TripOperationError.unauthorized,
      'You are not the driver assigned to this trip.',
    );
  }
}

/// Whether marking [studentId] boarded should actually happen right now.
/// [BoardingEligibility.alreadyBoarded] is not an error — the caller
/// treats it as a no-op success, which is what makes a repeated tap/retry
/// idempotent instead of failing on the second attempt.
enum BoardingEligibility {
  eligible,
  alreadyBoarded,
  absent,
  tripNotActive,
  studentNotOnTrip,
  // Production hardening: bus capacity server enforcement.
  busAtCapacity,
}

/// [busCapacity] and [droppedOffStudents] back the bus-capacity check
/// (Production hardening: previously this was a client-only warning in the
/// admin app's "Add trip" dialog — see admin_home_page.dart's
/// `_isOverCapacity` — with nothing stopping a direct write from exceeding
/// it). [busCapacity] of `null` means the bus has no configured capacity,
/// which is treated as unlimited (matching `SchoolBus.capacity`'s own
/// optional-field semantics) rather than silently blocking every boarding
/// on a bus nobody ever set a seat count for.
///
/// The onboard count is `boardedStudents.length - droppedOffStudents.length`
/// rather than a separately-tracked counter: `droppedOffStudents` is always
/// a subset of `boardedStudents` (see [checkDropOffEligibility] — a student
/// can't be dropped off without having boarded first), so this is exactly
/// "how many students are physically on the bus right now", recomputed
/// fresh from the trip document on every single boarding attempt.
BoardingEligibility checkBoardingEligibility({
  required TripStatus tripStatus,
  required List<String> stopOrder,
  required Set<String> boardedStudents,
  required Set<String> droppedOffStudents,
  required String studentId,
  required bool studentIsAbsentToday,
  int? busCapacity,
}) {
  if (tripStatus != TripStatus.active) return BoardingEligibility.tripNotActive;
  if (!stopOrder.contains(studentId)) return BoardingEligibility.studentNotOnTrip;
  if (boardedStudents.contains(studentId)) return BoardingEligibility.alreadyBoarded;
  if (studentIsAbsentToday) return BoardingEligibility.absent;
  if (busCapacity != null) {
    final onboardNow = boardedStudents.length - droppedOffStudents.length;
    if (onboardNow >= busCapacity) return BoardingEligibility.busAtCapacity;
  }
  return BoardingEligibility.eligible;
}

/// Whether marking [studentId] dropped off should actually happen right
/// now. Deliberately shaped exactly like [checkBoardingEligibility] — same
/// pure-function-returning-an-enum contract, same "the already-done case is
/// not an error" rule — so the two halves of ridership (picked up, handed
/// over) can never drift into two different notions of what's allowed.
///
/// [DropOffEligibility.alreadyDroppedOff] is checked *before*
/// [DropOffEligibility.notBoarded] so that a repeated tap stays idempotent
/// even in the odd case where a student's boarding record was removed
/// out from under an already-recorded drop-off — the drop-off already
/// happened, and re-reporting it as "not boarded" would be a lie about a
/// fact this trip already recorded.
enum DropOffEligibility {
  eligible,
  alreadyDroppedOff,
  notBoarded,
  tripNotActive,
  studentNotOnTrip,
}

DropOffEligibility checkDropOffEligibility({
  required TripStatus tripStatus,
  required List<String> stopOrder,
  required Set<String> boardedStudents,
  required Set<String> droppedOffStudents,
  required String studentId,
}) {
  if (tripStatus != TripStatus.active) return DropOffEligibility.tripNotActive;
  if (!stopOrder.contains(studentId)) return DropOffEligibility.studentNotOnTrip;
  if (droppedOffStudents.contains(studentId)) {
    return DropOffEligibility.alreadyDroppedOff;
  }
  if (!boardedStudents.contains(studentId)) return DropOffEligibility.notBoarded;
  return DropOffEligibility.eligible;
}

/// A trip's stop order may only be *reordered* — every reorder must carry
/// exactly the same set of stop ids as the one it replaces (no stop
/// silently dropped, none duplicated, none invented). Applying this before
/// every write is what keeps "the driver reordered stops by hand" from
/// ever being able to desync from "who's actually on this trip".
bool isValidStopReorder({
  required List<String> currentOrder,
  required List<String> newOrder,
}) {
  if (newOrder.toSet().length != newOrder.length) return false;
  final currentSet = currentOrder.toSet();
  final newSet = newOrder.toSet();
  return currentSet.length == newSet.length && currentSet.containsAll(newSet);
}

/// The trip (if any) that should currently have live GPS tracking running,
/// given a driver's full trip list — exactly a trip in [TripStatus.active]
/// or [TripStatus.emergency]. Used by TripsBloc to make the GPS stream
/// match what the trip list actually says is happening any time a new
/// snapshot arrives (including the very first one after an app launch or
/// process restart), rather than only reacting to the button tap that
/// originally started it — so a trip that was already active when the app
/// (re)opened is never silently left untracked. A driver is expected to
/// have at most one active/emergency trip at a time per the trip-status
/// transition rules; if more than one is somehow found, the first one
/// found wins rather than tracking none.
SchoolTrip? tripNeedingTracking(List<SchoolTrip> trips) {
  for (final trip in trips) {
    if (trip.status == TripStatus.active || trip.status == TripStatus.emergency) {
      return trip;
    }
  }
  return null;
}
