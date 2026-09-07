import 'dart:math' as math;

/// Great-circle distance between two coordinates, in meters.
double haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degToRad(double degrees) => degrees * (math.pi / 180);

/// Whether (latitude, longitude) is a real, in-range coordinate pair — the
/// same range check `firebase/database.rules.json` enforces server-side for
/// RTDB writes, reused client-side so a bad tap/drag never even attempts a
/// write that the rules would reject anyway (see SchoolsRepository in the
/// admin app).
bool isValidLatLng(double latitude, double longitude) {
  return latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

/// A plain lat/lng pair — the same shape `SchoolTrip.routePolyline` already
/// uses, so callers can pass that field straight in without wrapping it in
/// a map-package-specific type (`LatLng`, `Position`, ...).
typedef GeoPoint = ({double lat, double lng});

/// Index of the point in [route] closest to [target] (straight-line, not
/// routed — fine for snapping onto an already-road-shaped polyline where
/// points are only tens of meters apart).
int nearestRouteIndex(List<GeoPoint> route, GeoPoint target) {
  var bestIndex = 0;
  var bestDistance = double.infinity;
  for (var i = 0; i < route.length; i++) {
    final point = route[i];
    final dLat = point.lat - target.lat;
    final dLng = point.lng - target.lng;
    final distance = dLat * dLat + dLng * dLng;
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }
  return bestIndex;
}

/// The part of a road-following [route] that is still ahead of [from] (a
/// live GPS position) — the Uber-style picture where the road behind the
/// moving marker simply isn't drawn any more, only what's left to drive.
///
/// Snaps [from] onto the nearest vertex of [route] and returns [from]
/// followed by every vertex after that one, so the line starts exactly at
/// the live position rather than jumping to the snapped point first.
/// Returns just `[from]` when [route] has fewer than two points (nothing
/// to trim against).
List<GeoPoint> remainingRoute(List<GeoPoint> route, GeoPoint from) {
  if (route.length < 2) return [from];
  final index = nearestRouteIndex(route, from);
  return [from, ...route.sublist(index + 1)];
}
