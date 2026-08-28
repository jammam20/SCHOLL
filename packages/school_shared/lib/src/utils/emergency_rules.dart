import '../enums/emergency_status.dart';
import '../enums/trip_status.dart';

/// Whether a driver may raise a new emergency right now. Doesn't cover "an
/// emergency is already active for this trip" — that's a stronger, more
/// specific case the trip's own status already rules out (a trip can only
/// reach `TripStatus.emergency` once, and `eligible` here requires it to
/// still be `active`/`paused`), and callers with access to live trip data
/// can surface that friendlier, more specific message before ever reaching
/// this pure check (see EmergenciesRepository.createEmergency in the
/// driver app).
enum EmergencyCreationEligibility { eligible, tripNotActive, locationUnavailable }

EmergencyCreationEligibility checkEmergencyCreationEligibility({
  required TripStatus tripStatus,
  required bool hasLocation,
}) {
  if (!hasLocation) return EmergencyCreationEligibility.locationUnavailable;
  if (tripStatus != TripStatus.active && tripStatus != TripStatus.paused) {
    return EmergencyCreationEligibility.tripNotActive;
  }
  return EmergencyCreationEligibility.eligible;
}

enum EmergencyResolutionEligibility { eligible, alreadyResolved, unauthorized }

/// Shared by both the driver app (resolving their own emergency) and the
/// admin app (resolving any emergency in their school) — `isAuthorized`
/// is computed differently by each caller (driver: they raised it; admin:
/// already gated by their role/school), but "already resolved" always
/// means the same thing either way.
EmergencyResolutionEligibility checkEmergencyResolutionEligibility({
  required EmergencyStatus status,
  required bool isAuthorized,
}) {
  if (status == EmergencyStatus.resolved) {
    return EmergencyResolutionEligibility.alreadyResolved;
  }
  if (!isAuthorized) return EmergencyResolutionEligibility.unauthorized;
  return EmergencyResolutionEligibility.eligible;
}
