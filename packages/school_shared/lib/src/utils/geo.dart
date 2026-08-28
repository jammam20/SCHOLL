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
