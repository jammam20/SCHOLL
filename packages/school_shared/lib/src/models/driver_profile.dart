/// Operational detail for a driver, kept separate from [AppUser]/
/// [SchoolMember] (which stay auth/role/status only) so extending the
/// driver-management feature never touches the auth model every app
/// already depends on. Stored at `schools/{schoolId}/driverProfiles/{uid}`
/// — id equals the driver's uid.
class DriverProfile {
  const DriverProfile({
    required this.uid,
    required this.schoolId,
    this.licenseNumber,
    this.licenseExpiry,
    this.trainingCompletedAt,
    this.documentUrls = const [],
    this.assignedBusIds = const [],
    this.assignedRouteIds = const [],
  });

  final String uid;
  final String schoolId;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final DateTime? trainingCompletedAt;
  final List<String> documentUrls;
  final List<String> assignedBusIds;
  final List<String> assignedRouteIds;

  /// Matches the "license expires in 14 days" alert language from the spec.
  bool licenseExpiringWithin(Duration window, DateTime now) {
    final expiry = licenseExpiry;
    if (expiry == null) return false;
    final diff = expiry.difference(now);
    return diff >= Duration.zero && diff <= window;
  }

  bool get licenseExpired =>
      licenseExpiry != null && licenseExpiry!.isBefore(DateTime.now());

  factory DriverProfile.fromMap(String uid, Map<String, dynamic> data) {
    return DriverProfile(
      uid: uid,
      schoolId: data['schoolId'] as String? ?? '',
      licenseNumber: data['licenseNumber'] as String?,
      licenseExpiry: _asDateTime(data['licenseExpiry']),
      trainingCompletedAt: _asDateTime(data['trainingCompletedAt']),
      documentUrls: List<String>.from(data['documentUrls'] ?? const []),
      assignedBusIds: List<String>.from(data['assignedBusIds'] ?? const []),
      assignedRouteIds: List<String>.from(data['assignedRouteIds'] ?? const []),
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue.toDate();
      return result is DateTime ? result : null;
    } catch (_) {
      return null;
    }
  }
}
