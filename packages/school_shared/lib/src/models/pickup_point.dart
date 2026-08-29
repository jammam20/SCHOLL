/// A shared, admin-defined safe pickup location — distinct from a student's
/// individual door-to-door [Student.latitude]/[Student.longitude]. Lets a
/// student be assigned to a nearby shared point instead of requiring a
/// pickup at their exact home address. `radiusMeters` is the "safe zone"
/// used the same way a student's own point already is for arrival
/// proximity checks.
class PickupPoint {
  const PickupPoint({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.routeId,
    this.radiusMeters = 100,
    this.isActive = true,
  });

  final String id;
  final String schoolId;
  final String name;
  final double latitude;
  final double longitude;
  final String? routeId;
  final double radiusMeters;
  final bool isActive;

  factory PickupPoint.fromMap(String id, Map<String, dynamic> data) {
    return PickupPoint(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      routeId: data['routeId'] as String?,
      radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 100,
      isActive: data['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'schoolId': schoolId,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    if (routeId != null) 'routeId': routeId,
    'radiusMeters': radiusMeters,
    'isActive': isActive,
  };
}
