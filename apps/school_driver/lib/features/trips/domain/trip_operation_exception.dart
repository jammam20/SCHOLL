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
  tripNotActive,
  invalidStopOrder,
  emergencyAlreadyActive,
  emergencyNotFound,
  emergencyAlreadyResolved,
  locationUnavailable,
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
enum BoardingEligibility { eligible, alreadyBoarded, absent, tripNotActive, studentNotOnTrip }

BoardingEligibility checkBoardingEligibility({
  required TripStatus tripStatus,
  required List<String> stopOrder,
  required Set<String> boardedStudents,
  required String studentId,
  required bool studentIsAbsentToday,
}) {
  if (tripStatus != TripStatus.active) return BoardingEligibility.tripNotActive;
  if (!stopOrder.contains(studentId)) return BoardingEligibility.studentNotOnTrip;
  if (boardedStudents.contains(studentId)) return BoardingEligibility.alreadyBoarded;
  if (studentIsAbsentToday) return BoardingEligibility.absent;
  return BoardingEligibility.eligible;
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
