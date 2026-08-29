import 'dart:math' as math;

import '../enums/deviation_status.dart';
import 'eta_engine.dart' show TripStopPoint;

/// Result of evaluating one new GPS fix against a trip's expected path.
/// [shouldAlert] is true on exactly the update that transitions
/// NORMAL/DEVIATION_ENDED -> DEVIATION_STARTED — callers (the
/// onDriverLocationWritten Cloud Function; this Dart version exists so the
/// same state machine is unit-testable and available client-side for
/// display/tests) fire an admin notification only on that one update, never
/// on every subsequent GPS write while still deviating. [episodeEnded] is
/// true on exactly the update that transitions DEVIATING/DEVIATION_STARTED
/// -> DEVIATION_ENDED, which is when a closed history record should be
/// written for reporting.
class DeviationEvaluation {
  const DeviationEvaluation({
    required this.status,
    required this.distanceMeters,
    required this.maxDeviationMeters,
    required this.shouldAlert,
    required this.episodeEnded,
  });

  final DeviationStatus status;
  final double distanceMeters;
  final double maxDeviationMeters;
  final bool shouldAlert;
  final bool episodeEnded;
}

/// Expected path = the straight-line corridor connecting every stop in trip
/// order (there is no separately-stored route polyline in this system —
/// see SchoolRoute's own doc comment — so the trip's own stop-by-stop
/// sequence is the closest thing to "the expected route" that actually
/// exists). A bus further than [toleranceMeters] from every segment of that
/// corridor is considered off-route.
DeviationEvaluation evaluateDeviation({
  required DeviationStatus previousStatus,
  required double previousMaxDeviationMeters,
  required double busLatitude,
  required double busLongitude,
  required List<TripStopPoint> stopOrder,
  required double toleranceMeters,
}) {
  final distance = _distanceToPathMeters(busLatitude, busLongitude, stopOrder);

  final wasDeviating = previousStatus == DeviationStatus.deviationStarted ||
      previousStatus == DeviationStatus.deviating;

  if (distance <= toleranceMeters) {
    if (wasDeviating) {
      return DeviationEvaluation(
        status: DeviationStatus.deviationEnded,
        distanceMeters: distance,
        maxDeviationMeters: previousMaxDeviationMeters,
        shouldAlert: false,
        episodeEnded: true,
      );
    }
    return DeviationEvaluation(
      status: DeviationStatus.normal,
      distanceMeters: distance,
      maxDeviationMeters: 0,
      shouldAlert: false,
      episodeEnded: false,
    );
  }

  if (wasDeviating) {
    return DeviationEvaluation(
      status: DeviationStatus.deviating,
      distanceMeters: distance,
      maxDeviationMeters: math.max(previousMaxDeviationMeters, distance),
      shouldAlert: false,
      episodeEnded: false,
    );
  }

  return DeviationEvaluation(
    status: DeviationStatus.deviationStarted,
    distanceMeters: distance,
    maxDeviationMeters: distance,
    shouldAlert: true,
    episodeEnded: false,
  );
}

double _distanceToPathMeters(
  double lat,
  double lng,
  List<TripStopPoint> stopOrder,
) {
  if (stopOrder.isEmpty) return 0;
  if (stopOrder.length == 1) {
    return _haversine(lat, lng, stopOrder[0].latitude, stopOrder[0].longitude);
  }

  var minDistance = double.infinity;
  for (var i = 0; i < stopOrder.length - 1; i++) {
    final d = _distanceToSegmentMeters(
      lat,
      lng,
      stopOrder[i].latitude,
      stopOrder[i].longitude,
      stopOrder[i + 1].latitude,
      stopOrder[i + 1].longitude,
    );
    if (d < minDistance) minDistance = d;
  }
  return minDistance;
}

/// Point-to-segment distance using a local equirectangular (flat-earth)
/// projection, accurate enough for the few-kilometer scale a single school
/// route covers — full great-circle segment projection isn't worth the
/// complexity at this scale.
double _distanceToSegmentMeters(
  double pLat,
  double pLng,
  double aLat,
  double aLng,
  double bLat,
  double bLng,
) {
  const metersPerDegreeLat = 111320.0;
  final metersPerDegreeLng = 111320.0 * math.cos(_degToRad(pLat));

  final px = pLng * metersPerDegreeLng;
  final py = pLat * metersPerDegreeLat;
  final ax = aLng * metersPerDegreeLng;
  final ay = aLat * metersPerDegreeLat;
  final bx = bLng * metersPerDegreeLng;
  final by = bLat * metersPerDegreeLat;

  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;

  double t;
  if (lengthSquared == 0) {
    t = 0;
  } else {
    t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
  }

  final closestX = ax + t * dx;
  final closestY = ay + t * dy;
  final ddx = px - closestX;
  final ddy = py - closestY;
  return math.sqrt(ddx * ddx + ddy * ddy);
}

double _haversine(double lat1, double lng1, double lat2, double lng2) {
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
