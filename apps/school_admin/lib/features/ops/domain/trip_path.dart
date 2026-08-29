import 'dart:math' as math;

import 'package:school_shared/school_shared.dart';

/// The sentinel stop id the driver app writes into a trip's `stopOrder`
/// to mean "the school itself" — the final stop of every trip. Mirrors
/// the `"__school__"` literal `evaluateRouteDeviation` in
/// functions/src/index.ts checks for; if the two ever disagree the map
/// would draw a different expected path than the deviation engine
/// measures against, so they must stay identical.
const schoolStopSentinel = '__school__';

/// One stop on a trip's expected path, resolved to a real coordinate and
/// carrying enough state for the map to render it: its position in the
/// order, whose stop it is, and whether the driver has already handled it.
class TripPathStop {
  const TripPathStop({
    required this.stopId,
    required this.sequence,
    required this.latitude,
    required this.longitude,
    required this.isSchool,
    required this.label,
    required this.progress,
  });

  final String stopId;

  /// 1-based, so the numbered markers on the map read "1, 2, 3…" the way a
  /// driver's own stop list does.
  final int sequence;
  final double latitude;
  final double longitude;
  final bool isSchool;

  /// The student's name, or the school's name for the final stop.
  final String label;
  final TripStopProgress progress;
}

/// What has happened at a stop, from the trip document's own
/// `boardedStudents` / `droppedOffStudents` arrays.
enum TripStopProgress {
  /// Not yet reached.
  pending,

  /// The student has been picked up (`boardedStudents` contains them).
  boarded,

  /// The student has been dropped off (`droppedOffStudents` contains
  /// them) — takes precedence over `boarded`, since a dropped-off student
  /// was necessarily boarded first.
  droppedOff,

  /// The school's own final stop, which has no per-student boarding state.
  school,
}

/// Resolves a trip's `stopOrder` into real coordinates.
///
/// This is the *same* construction the server-side deviation engine
/// performs (`evaluateRouteDeviation` in functions/src/index.ts): walk
/// `stopOrder` in order, resolve each id to a student's latitude/longitude
/// — or the school's, for the [schoolStopSentinel] — and skip any entry
/// whose coordinate is missing. Rebuilding it identically here is what
/// makes the polyline the admin sees genuinely "the expected path the bus
/// is being measured against", rather than a decorative line.
///
/// [studentsById] and [schoolLatitude]/[schoolLongitude] come from
/// collections the admin app already reads.
List<TripPathStop> buildTripPath({
  required List<String> stopOrder,
  required Map<String, Student> studentsById,
  required List<String> boardedStudentIds,
  required List<String> droppedOffStudentIds,
  double? schoolLatitude,
  double? schoolLongitude,
  String schoolLabel = '',
}) {
  final stops = <TripPathStop>[];

  for (final stopId in stopOrder) {
    if (stopId == schoolStopSentinel) {
      if (schoolLatitude == null || schoolLongitude == null) continue;
      stops.add(
        TripPathStop(
          stopId: stopId,
          sequence: stops.length + 1,
          latitude: schoolLatitude,
          longitude: schoolLongitude,
          isSchool: true,
          label: schoolLabel,
          progress: TripStopProgress.school,
        ),
      );
      continue;
    }

    final student = studentsById[stopId];
    final latitude = student?.latitude;
    final longitude = student?.longitude;
    if (student == null || latitude == null || longitude == null) continue;

    stops.add(
      TripPathStop(
        stopId: stopId,
        sequence: stops.length + 1,
        latitude: latitude,
        longitude: longitude,
        isSchool: false,
        label: student.name,
        progress: droppedOffStudentIds.contains(stopId)
            ? TripStopProgress.droppedOff
            : boardedStudentIds.contains(stopId)
            ? TripStopProgress.boarded
            : TripStopProgress.pending,
      ),
    );
  }

  return stops;
}

/// Converts a resolved path into the [TripStopPoint] list the shared ETA
/// engine consumes. A stop counts as "completed" for ETA purposes once the
/// driver has handled it (boarded or dropped off) — which is exactly what
/// makes `computeTripEta` treat the *next* unhandled stop as the one the
/// bus is heading for.
List<TripStopPoint> toEtaStopPoints(List<TripPathStop> path) {
  return [
    for (final stop in path)
      TripStopPoint(
        stopId: stop.stopId,
        latitude: stop.latitude,
        longitude: stop.longitude,
        isCompleted:
            stop.progress == TripStopProgress.boarded ||
            stop.progress == TripStopProgress.droppedOff,
        isSchool: stop.isSchool,
      ),
  ];
}

/// The point on a trip's expected path closest to [latitude]/[longitude],
/// used to draw the "how far off route is this bus" connector on the map.
///
/// Uses the same local equirectangular (flat-earth) projection the shared
/// deviation engine uses for its point-to-segment distance — accurate at
/// the few-kilometre scale one school route covers, and consistent with
/// the number the server actually measured. Returns null for a path with
/// fewer than two points, where there is no corridor to project onto.
({double latitude, double longitude})? closestPointOnPath({
  required double latitude,
  required double longitude,
  required List<TripPathStop> path,
}) {
  if (path.length < 2) return null;

  // Degrees are projected to metres about the bus's own latitude so the
  // x/y plane is locally isotropic; the result is converted straight back.
  final metersPerDegreeLng = 111320.0 * _cosDegrees(latitude);
  const metersPerDegreeLat = 111320.0;
  if (metersPerDegreeLng == 0) return null;

  final px = longitude * metersPerDegreeLng;
  final py = latitude * metersPerDegreeLat;

  double? bestX;
  double? bestY;
  var bestDistanceSquared = double.infinity;

  for (var i = 0; i < path.length - 1; i++) {
    final ax = path[i].longitude * metersPerDegreeLng;
    final ay = path[i].latitude * metersPerDegreeLat;
    final bx = path[i + 1].longitude * metersPerDegreeLng;
    final by = path[i + 1].latitude * metersPerDegreeLat;

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

    final cx = ax + t * dx;
    final cy = ay + t * dy;
    final ddx = px - cx;
    final ddy = py - cy;
    final distanceSquared = ddx * ddx + ddy * ddy;

    if (distanceSquared < bestDistanceSquared) {
      bestDistanceSquared = distanceSquared;
      bestX = cx;
      bestY = cy;
    }
  }

  if (bestX == null || bestY == null) return null;
  return (
    latitude: bestY / metersPerDegreeLat,
    longitude: bestX / metersPerDegreeLng,
  );
}

double _cosDegrees(double degrees) => math.cos(degrees * math.pi / 180);

/// A short "in 4 min" style label for an ETA duration, or null when there
/// isn't one to show. Kept here (rather than in the widget) so the map and
/// the bus list can't drift apart in how they phrase the same number.
String? formatEtaMinutes(Duration? eta) {
  if (eta == null) return null;
  final minutes = eta.inMinutes;
  if (minutes < 1) return '<1 min';
  return '$minutes min';
}
