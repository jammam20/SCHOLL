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

  for (final stopId in order) {
    final isSchoolStop = stopId == schoolStopId;
    // The school stop's own "reached" state isn't tracked by
    // boardedStudents (it's not a student) — it's only ever completed by
    // the trip itself finishing, so it always reads as remaining until
    // then rather than being inferred from other students' boarding.
    final isReached = !isSchoolStop && boardedStudents.contains(stopId);
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
