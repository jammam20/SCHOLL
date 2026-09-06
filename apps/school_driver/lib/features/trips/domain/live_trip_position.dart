/// The bus's last-broadcast GPS fix, as written to
/// `schools/{id}/trips/{id}/location` in Realtime Database by
/// DriverTrackingRepository.
///
/// The driver app reads back the node it writes rather than holding onto
/// the raw `Position` objects from its own Geolocator stream: that node is
/// the single value everyone else in the system (parents, admin live ops)
/// is actually seeing, so an ETA computed from it is the same ETA a parent
/// is looking at — including its staleness. Reading a private, fresher
/// in-memory position would let the driver see a confident ETA at moments
/// when nobody else could.
class LiveTripPosition {
  const LiveTripPosition({
    required this.latitude,
    required this.longitude,
    this.heading = 0,
    this.speedMetersPerSecond,
    this.updatedAt,
  });

  final double latitude;
  final double longitude;

  /// The device's real GPS heading in degrees, 0 when unavailable.
  final double heading;
  final double? speedMetersPerSecond;
  final DateTime? updatedAt;

  /// Null when the node is empty (tracking hasn't broadcast yet) or
  /// malformed (missing lat/lng) — callers treat that as "no live position
  /// yet", never as an error, and never substitute a zeroed coordinate.
  static LiveTripPosition? fromRtdbValue(Object? raw) {
    if (raw is! Map) return null;
    final data = Map<Object?, Object?>.from(raw);
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;

    final timestampMs = (data['timestamp'] as num?)?.toInt();
    return LiveTripPosition(
      latitude: latitude,
      longitude: longitude,
      heading: (data['heading'] as num?)?.toDouble() ?? 0,
      speedMetersPerSecond: (data['speed'] as num?)?.toDouble(),
      updatedAt: timestampMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestampMs),
    );
  }
}
