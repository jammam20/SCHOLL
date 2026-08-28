import '../enums/emergency_status.dart';
import '../enums/emergency_type.dart';

/// A structured emergency record raised by a driver mid-trip — separate
/// from (but linked to) the trip's own `status` field, which still just
/// flips to `TripStatus.emergency` through the existing trip state machine
/// (see TripStatus.canTransitionTo). This model exists because the trip
/// document alone has no room for an emergency's type, its location at the
/// moment it was raised, or how/when/by whom it was resolved — and because
/// a trip could, in principle, need that detail recorded even though only
/// one emergency can ever be active for a trip at a time.
class SchoolEmergency {
  const SchoolEmergency({
    required this.id,
    required this.schoolId,
    required this.tripId,
    required this.driverId,
    required this.busId,
    required this.type,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.routeId,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
    this.driverNote,
  });

  final String id;
  final String schoolId;
  final String tripId;
  final String driverId;
  final String busId;
  final String? routeId;
  final EmergencyType type;
  final EmergencyStatus status;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNote;
  final String? driverNote;

  bool get isActive => status == EmergencyStatus.active;

  factory SchoolEmergency.fromMap(String id, Map<String, dynamic> data) {
    return SchoolEmergency(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      busId: data['busId'] as String? ?? '',
      routeId: data['routeId'] as String?,
      type: EmergencyTypeX.tryParse(data['type']) ?? EmergencyType.other,
      status: EmergencyStatusX.tryParse(data['status']) ?? EmergencyStatus.active,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      resolvedAt: _asDateTime(data['resolvedAt']),
      resolvedBy: data['resolvedBy'] as String?,
      resolutionNote: data['resolutionNote'] as String?,
      driverNote: data['driverNote'] as String?,
    );
  }

  /// Accepts a [DateTime] directly, or anything exposing a Firestore-style
  /// `toDate()` method (i.e. a `Timestamp`), without this package taking a
  /// hard dependency on `cloud_firestore` — mirrors SchoolTrip's own
  /// `_asDateTime` helper.
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
