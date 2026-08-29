import '../enums/incident_status.dart';
import '../enums/incident_type.dart';

/// A general operational incident report — deliberately separate from
/// [SchoolEmergency]/SOS: not every incident (a route-blocked report, a
/// student-behavior note) should flip the whole trip to
/// `TripStatus.emergency` and blast every parent on the route the way a
/// driver-raised SOS does. Reported by a driver against a trip/bus, tracked
/// through report -> acknowledge -> resolve, optionally with a photo.
class SchoolIncident {
  const SchoolIncident({
    required this.id,
    required this.schoolId,
    required this.type,
    required this.status,
    required this.createdAt,
    this.tripId,
    this.busId,
    this.driverId,
    this.routeId,
    this.latitude,
    this.longitude,
    this.notes,
    this.photoUrl,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
  });

  final String id;
  final String schoolId;
  final IncidentType type;
  final IncidentStatus status;
  final DateTime createdAt;

  final String? tripId;
  final String? busId;
  final String? driverId;
  final String? routeId;

  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? photoUrl;

  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;

  bool get hasLocation => latitude != null && longitude != null;

  factory SchoolIncident.fromMap(String id, Map<String, dynamic> data) {
    return SchoolIncident(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      type: IncidentTypeX.tryParse(data['type']) ?? IncidentType.other,
      status: IncidentStatusX.tryParse(data['status']) ?? IncidentStatus.reported,
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      tripId: data['tripId'] as String?,
      busId: data['busId'] as String?,
      driverId: data['driverId'] as String?,
      routeId: data['routeId'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      photoUrl: data['photoUrl'] as String?,
      acknowledgedAt: _asDateTime(data['acknowledgedAt']),
      acknowledgedBy: data['acknowledgedBy'] as String?,
      resolvedAt: _asDateTime(data['resolvedAt']),
      resolvedBy: data['resolvedBy'] as String?,
      resolutionNotes: data['resolutionNotes'] as String?,
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
