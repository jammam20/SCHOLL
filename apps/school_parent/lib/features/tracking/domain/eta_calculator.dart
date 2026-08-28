/// A fallback speed used to keep ETAs sane when the bus is stationary (e.g.
/// stuck at a light or just started moving) and its reported GPS speed is
/// near zero. Roughly city-street bus speed. Shared by LiveTripMap and the
/// child journey card so both ever show the same number for the same trip.
const fallbackSpeedMetersPerSecond = 6.0;

/// The GPS speed below which it's treated as noise rather than the bus's
/// real pace (stopped at a light still reports a small nonzero speed).
const _minReliableSpeedMetersPerSecond = 1.5;

/// Straight-line ETA from a distance and the bus's last-reported speed —
/// deliberately simple (no traffic/route-shape awareness): the same
/// estimate LiveTripMap already showed, just factored out so it isn't
/// reimplemented wherever else an ETA needs to be shown. Returns null when
/// there's no distance yet (bus hasn't started broadcasting).
Duration? estimateEta({
  required double? distanceMeters,
  required double? reportedSpeedMetersPerSecond,
}) {
  if (distanceMeters == null) return null;
  final speed =
      reportedSpeedMetersPerSecond != null &&
          reportedSpeedMetersPerSecond > _minReliableSpeedMetersPerSecond
      ? reportedSpeedMetersPerSecond
      : fallbackSpeedMetersPerSecond;
  return Duration(seconds: (distanceMeters / speed).round());
}
