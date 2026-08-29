import 'package:school_shared/school_shared.dart';

/// One candidate pickup point with its straight-line distance from a
/// student's own coordinate.
class PickupPointSuggestion {
  const PickupPointSuggestion({
    required this.point,
    required this.distanceMeters,
  });

  final PickupPoint point;
  final double distanceMeters;

  /// Whether the student's home coordinate already falls inside this
  /// point's own safe-zone radius — i.e. the point is not merely the
  /// closest, it actually covers them.
  bool get withinRadius => distanceMeters <= point.radiusMeters;
}

/// Ranks active pickup points by plain great-circle distance from a
/// student's coordinate, nearest first.
///
/// This is an ordinary distance sort using [haversineMeters] — the same
/// function the deviation and ETA engines use — and nothing more. It is
/// **not** a recommendation model, and deliberately isn't described as one
/// anywhere in the UI: there is no learning, no scoring beyond distance,
/// and no data behind it other than two coordinates. Points on a route
/// other than the student's assigned one are still included (with their
/// route surfaced in the UI), because a nearby point on a neighbouring
/// route is a real, legitimate option an admin may want to pick.
///
/// Returns an empty list when the student has no coordinate of their own,
/// since there is then nothing to measure from.
List<PickupPointSuggestion> rankPickupPointsByDistance({
  required double? studentLatitude,
  required double? studentLongitude,
  required List<PickupPoint> points,
  int limit = 5,
}) {
  if (studentLatitude == null || studentLongitude == null) return const [];
  if (!isValidLatLng(studentLatitude, studentLongitude)) return const [];

  final suggestions =
      points
          .where((point) => point.isActive)
          .map(
            (point) => PickupPointSuggestion(
              point: point,
              distanceMeters: haversineMeters(
                studentLatitude,
                studentLongitude,
                point.latitude,
                point.longitude,
              ),
            ),
          )
          .toList()
        ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

  return suggestions.take(limit).toList();
}

/// A human-readable distance: metres below 1 km, one decimal kilometre
/// above. Locale-independent (digits and a unit only), so the same helper
/// serves both languages.
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
