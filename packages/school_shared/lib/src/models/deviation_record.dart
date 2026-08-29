import '../enums/deviation_status.dart';

/// One deviation episode for a trip — created when a bus is first found
/// further than the route's tolerance from its expected path, updated as
/// the deviation continues, and closed (endedAt set) once the bus is back
/// within tolerance. `schools/{schoolId}/trips/{tripId}/deviation` holds
/// the single *live* record (upserted per trip, mirrors the RTDB
/// notifyState dedup pattern so an admin alert only fires once per
/// episode); `schools/{schoolId}/routeDeviations/{id}` holds the closed
/// history copy used for reporting (see functions/src/index.ts, which owns
/// writing both — this is a read model for clients).
class DeviationRecord {
  const DeviationRecord({
    required this.id,
    required this.schoolId,
    required this.tripId,
    required this.busId,
    required this.driverId,
    required this.status,
    required this.startedAt,
    required this.maxDeviationMeters,
    required this.currentDeviationMeters,
    this.routeId,
    this.endedAt,
  });

  final String id;
  final String schoolId;
  final String tripId;
  final String busId;
  final String driverId;
  final String? routeId;
  final DeviationStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double maxDeviationMeters;
  final double currentDeviationMeters;

  bool get isOngoing => endedAt == null && status != DeviationStatus.normal;

  factory DeviationRecord.fromMap(String id, Map<String, dynamic> data) {
    return DeviationRecord(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      busId: data['busId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      routeId: data['routeId'] as String?,
      status: DeviationStatusX.tryParse(data['status']) ?? DeviationStatus.normal,
      startedAt: _asDateTime(data['startedAt']) ?? DateTime.now(),
      endedAt: _asDateTime(data['endedAt']),
      maxDeviationMeters: (data['maxDeviationMeters'] as num?)?.toDouble() ?? 0,
      currentDeviationMeters: (data['currentDeviationMeters'] as num?)?.toDouble() ?? 0,
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
