import '../enums/trip_status.dart';
import '../utils/geo.dart';

/// A single point on a trip's stop-by-stop path — one entry per
/// `stopOrder` id (a student's pickup point, or the school for the final
/// sentinel stop), in trip order. This is the same sequence
/// StopOrderRepository/StopProgress already work with; the ETA/route-
/// progress/deviation engines below just add distance/time reasoning on
/// top of it instead of introducing a separate "route path" concept.
class TripStopPoint {
  const TripStopPoint({
    required this.stopId,
    required this.latitude,
    required this.longitude,
    required this.isCompleted,
    this.isSchool = false,
  });

  final String stopId;
  final double latitude;
  final double longitude;
  final bool isCompleted;
  final bool isSchool;
}

/// Why an ETA couldn't be computed — surfaced to the UI so "ETA
/// unavailable" always says *why* instead of just hiding the number.
enum EtaUnavailableReason {
  tripNotActive,
  noGpsSignal,
  staleGps,
  allStopsCompleted,
  noRemainingStops,
}

/// A fallback speed used to keep ETAs sane when the bus is stationary (e.g.
/// stuck at a light or just started moving) and its reported GPS speed is
/// near zero. Roughly city-street bus speed.
const fallbackSpeedMetersPerSecond = 6.0;

/// The GPS speed below which it's treated as noise rather than the bus's
/// real pace (stopped at a light still reports a small nonzero speed).
const minReliableSpeedMetersPerSecond = 1.5;

/// A GPS fix older than this is treated as "no live signal" rather than
/// trusted for a live ETA — avoids showing a confident-looking ETA number
/// computed from a bus's location several minutes ago.
const staleGpsThreshold = Duration(minutes: 3);

/// A single-stop-leg ETA beyond this is treated as unreliable rather than
/// shown as a specific number — avoids an "absurd ETA" (e.g. a bad speed
/// reading producing "ETA: 4 hours" for a stop that's actually 2km away).
const maxReliableEtaPerLeg = Duration(hours: 2);

class TripEta {
  const TripEta({
    required this.stopsCompleted,
    required this.stopsRemaining,
    required this.routeProgressFraction,
    this.nextStopId,
    this.distanceToNextStopMeters,
    this.etaToNextStop,
    this.distanceToFinalStopMeters,
    this.etaToFinalStop,
    this.unavailableReason,
  });

  final int stopsCompleted;
  final int stopsRemaining;
  final double routeProgressFraction;

  final String? nextStopId;
  final double? distanceToNextStopMeters;
  final Duration? etaToNextStop;
  final double? distanceToFinalStopMeters;
  final Duration? etaToFinalStop;

  /// Non-null whenever [etaToNextStop] is null and there *should* have been
  /// one (i.e. not simply because the trip is already fully complete).
  final EtaUnavailableReason? unavailableReason;

  bool get hasEta => etaToNextStop != null;
}

/// The real ETA engine: bus GPS -> route progress -> next stop -> distance
/// -> speed -> ETA, exactly the chain the feature calls for. Deliberately a
/// pure function of its inputs (like the rest of this package's domain
/// logic) so parent/driver/admin apps all get identical numbers for the
/// same trip instead of three separate ad-hoc calculations.
///
/// Distance is great-circle (haversine) between consecutive stop points,
/// not a road-routing distance — this project has no Directions API
/// integration, and adding one would mean a new paid dependency; the
/// straight-line estimate is the same approach LiveTripMap already used
/// for its single-stop ETA, just generalized to the whole remaining route
/// and given explicit "why is this unavailable" reasoning.
TripEta computeTripEta({
  required TripStatus tripStatus,
  required List<TripStopPoint> stopOrder,
  double? busLatitude,
  double? busLongitude,
  double? busSpeedMetersPerSecond,
  DateTime? busPositionUpdatedAt,
  DateTime? now,
}) {
  final nowTime = now ?? DateTime.now();
  final completed = stopOrder.where((s) => s.isCompleted).length;
  final remaining = stopOrder.where((s) => !s.isCompleted).toList();
  final progress =
      stopOrder.isEmpty ? 0.0 : completed / stopOrder.length;

  if (stopOrder.isEmpty) {
    return TripEta(
      stopsCompleted: 0,
      stopsRemaining: 0,
      routeProgressFraction: 0,
      unavailableReason: EtaUnavailableReason.noRemainingStops,
    );
  }

  if (remaining.isEmpty) {
    return TripEta(
      stopsCompleted: completed,
      stopsRemaining: 0,
      routeProgressFraction: 1,
      unavailableReason: EtaUnavailableReason.allStopsCompleted,
    );
  }

  final nextStop = remaining.first;
  final finalStop = remaining.last;

  EtaUnavailableReason? reason;
  if (tripStatus != TripStatus.active) {
    reason = EtaUnavailableReason.tripNotActive;
  } else if (busLatitude == null || busLongitude == null) {
    reason = EtaUnavailableReason.noGpsSignal;
  } else if (busPositionUpdatedAt != null &&
      nowTime.difference(busPositionUpdatedAt) > staleGpsThreshold) {
    reason = EtaUnavailableReason.staleGps;
  }

  if (reason != null) {
    return TripEta(
      stopsCompleted: completed,
      stopsRemaining: remaining.length,
      routeProgressFraction: progress,
      nextStopId: nextStop.stopId,
      unavailableReason: reason,
    );
  }

  final speed =
      busSpeedMetersPerSecond != null &&
              busSpeedMetersPerSecond > minReliableSpeedMetersPerSecond
          ? busSpeedMetersPerSecond
          : fallbackSpeedMetersPerSecond;

  final distanceToNext = haversineMeters(
    busLatitude!,
    busLongitude!,
    nextStop.latitude,
    nextStop.longitude,
  );
  final etaToNext = Duration(seconds: (distanceToNext / speed).round());

  // Distance to the final remaining stop = distance to next stop + the
  // sum of each subsequent leg along the remaining stop order — a
  // reasonable approximation of "how far is left on this trip" given we
  // have no road-routing distance to fall back on.
  var distanceToFinal = distanceToNext;
  for (var i = 0; i < remaining.length - 1; i++) {
    distanceToFinal += haversineMeters(
      remaining[i].latitude,
      remaining[i].longitude,
      remaining[i + 1].latitude,
      remaining[i + 1].longitude,
    );
  }
  final etaToFinal = Duration(seconds: (distanceToFinal / speed).round());

  final nextLegReliable = etaToNext <= maxReliableEtaPerLeg;

  return TripEta(
    stopsCompleted: completed,
    stopsRemaining: remaining.length,
    routeProgressFraction: progress,
    nextStopId: nextStop.stopId,
    distanceToNextStopMeters: distanceToNext,
    etaToNextStop: nextLegReliable ? etaToNext : null,
    distanceToFinalStopMeters: finalStop == nextStop ? null : distanceToFinal,
    etaToFinalStop: (finalStop == nextStop || !nextLegReliable) ? null : etaToFinal,
    unavailableReason: nextLegReliable ? null : EtaUnavailableReason.staleGps,
  );
}
