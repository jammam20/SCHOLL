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

/// The single road-following segment between [from] (typically the bus's
/// live position) and [to] (typically the specific stop it's heading to
/// right now) — deliberately just this one leg, not the rest of the trip's
/// route past [to], so the map reads as "the drive to get there" rather
/// than a full itinerary redrawn on every GPS tick.
///
/// Both ends are snapped onto the nearest vertex of [route] first (a
/// nearest-vertex approximation, not a true point-to-segment projection —
/// fine here since a road polyline already carries many closely-spaced
/// points), then the path is built from [from] through every vertex
/// between the two snapped points and finishing at [to] itself, so the
/// line still visually touches the two real coordinates it connects
/// instead of the approximated snap points. Falls back to the bare
/// two-point line when [route] has fewer than two points to snap onto.
List<GeoPoint> currentLegRoute(
  List<GeoPoint> route,
  GeoPoint from,
  GeoPoint to,
) {
  if (route.length < 2) return [from, to];
  final fromIndex = nearestRouteIndex(route, from);
  final toIndex = nearestRouteIndex(route, to);
  final start = fromIndex < toIndex ? fromIndex : toIndex;
  final end = fromIndex < toIndex ? toIndex : fromIndex;
  final segment = route.sublist(start, end + 1);
  return fromIndex <= toIndex
      ? [from, ...segment, to]
      : [from, ...segment.reversed, to];
}

/// The real, road-following distance (in meters) from [from] to [to],
/// along [route] — sums each leg of [currentLegRoute]'s own path instead
/// of measuring [from]-to-[to] as the crow flies, which noticeably over-
/// or under-states distance once the road bends around a block, a river,
/// or a highway interchange rather than running straight between the two.
/// Falls back to the straight-line distance when [route] doesn't have
/// enough points to snap onto (see [currentLegRoute]).
double routeDistanceMeters(
  List<GeoPoint> route,
  GeoPoint from,
  GeoPoint to,
) {
  final path = currentLegRoute(route, from, to);
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    total += haversineMeters(
      path[i].lat,
      path[i].lng,
      path[i + 1].lat,
      path[i + 1].lng,
    );
  }
  return total;
}
