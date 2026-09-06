/// Derives "where is this trip up to" purely from the two fields that
/// already carry that information (`stopOrder`, `boardedStudents`) —
/// deliberately not a new persisted field, so it can never drift out of
/// sync with them the way a separately-stored `currentStopIndex` could
/// after a manual reorder or a pause/resume.
class StopProgress {
  const StopProgress({
    required this.completedStopIds,
    required this.currentStopId,
    required this.remainingStopIds,
  });

  final List<String> completedStopIds;
  // Null once every stop (including the school) has been reached — i.e.
  // the trip has nothing left to do but be marked complete.
  final String? currentStopId;
  final List<String> remainingStopIds;

  String? get nextStopId =>
      remainingStopIds.length > 1 ? remainingStopIds[1] : null;
}

StopProgress computeStopProgress({
  required List<String> order,
  required Set<String> boardedStudents,
  required String schoolStopId,
}) {
  final completed = <String>[];
  final remaining = <String>[];

  // Which end of `order` school sits at depends on trip direction: an
  // outbound trip ends at school (the historical, still-common shape this
  // function was originally written for), but a return trip starts there —
  // boarding happens at school before the drive home. Only in the outbound
  // case does school genuinely stay "remaining" until the whole trip is
  // marked complete; on a return trip it's already behind the bus the
  // moment the trip starts, same as if it had its own boardedStudents entry.
  final schoolIsFirst = order.isNotEmpty && order.first == schoolStopId;

  for (final stopId in order) {
    final isSchoolStop = stopId == schoolStopId;
    // The school stop's own "reached" state isn't tracked by
    // boardedStudents (it's not a student). On an outbound trip it's only
    // ever completed by the trip itself finishing, so it always reads as
    // remaining until then rather than being inferred from other students'
    // boarding; on a return trip it's the starting point, already behind
    // the bus from the first stop onward.
    final isReached = isSchoolStop
        ? schoolIsFirst
        : boardedStudents.contains(stopId);
    if (isReached) {
      completed.add(stopId);
    } else {
      remaining.add(stopId);
    }
  }

  return StopProgress(
    completedStopIds: completed,
    currentStopId: remaining.isEmpty ? null : remaining.first,
    remainingStopIds: remaining,
  );
}
