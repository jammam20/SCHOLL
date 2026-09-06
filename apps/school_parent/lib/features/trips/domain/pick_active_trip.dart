import 'package:school_shared/school_shared.dart';

/// Picks the one trip a child's journey card should show out of a route's
/// most recently scheduled candidates (as returned by
/// `TripsRepository.watchLatestTripForRoute`, newest-scheduled-first).
///
/// A trip that is live right now (started, paused, or in an emergency)
/// always wins regardless of its scheduled time — that is the one thing
/// actually happening — so a later-scheduled trip that got cancelled can no
/// longer hide an earlier-scheduled trip that's actually in progress.
/// Failing that, the most recently scheduled non-cancelled trip wins (so a
/// stale cancellation doesn't outrank a real upcoming/completed trip); only
/// when every candidate is cancelled does this fall back to the newest of
/// those, since there's nothing better to show.
SchoolTrip? pickActiveTrip(List<SchoolTrip> candidates) {
  if (candidates.isEmpty) return null;
  const liveStatuses = {
    TripStatus.starting,
    TripStatus.active,
    TripStatus.paused,
    TripStatus.emergency,
  };
  for (final trip in candidates) {
    if (liveStatuses.contains(trip.status)) return trip;
  }
  for (final trip in candidates) {
    if (trip.status != TripStatus.cancelled) return trip;
  }
  return candidates.first;
}
