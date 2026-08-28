/// A driver's last-broadcast GPS fix, as written to
/// `schools/{id}/trips/{id}/location` in Realtime Database (see
/// DriverTrackingRepository in the driver app). Parsed once here so
/// LiveTripMap and the parent home screen's journey card read the exact
/// same fields the exact same way instead of each re-parsing the raw map.
class LiveBusPosition {
  const LiveBusPosition({
    required this.latitude,
    required this.longitude,
    this.heading = 0,
    this.speedMetersPerSecond,
    this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final double heading;
  final double? speedMetersPerSecond;
  final DateTime? updatedAt;

  /// Null when the RTDB node is empty (bus hasn't broadcast yet) or
  /// malformed (missing lat/lng) — callers treat that as "no live position
  /// yet", never as an error.
  static LiveBusPosition? fromRtdbValue(Object? raw) {
    if (raw is! Map) return null;
    final data = Map<Object?, Object?>.from(raw);
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;

    final timestampMs = (data['timestamp'] as num?)?.toInt();
    return LiveBusPosition(
      latitude: latitude,
      longitude: longitude,
      heading: (data['heading'] as num?)?.toDouble() ?? 0,
      speedMetersPerSecond: (data['speed'] as num?)?.toDouble(),
      updatedAt: timestampMs != null
          ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
          : null,
    );
  }
}
