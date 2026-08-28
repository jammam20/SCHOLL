class RouteStop {
  const RouteStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sequence,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int sequence;

  factory RouteStop.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return RouteStop(
      id: id,
      name: data['name'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      sequence: data['sequence'] as int? ?? 0,
    );
  }
}