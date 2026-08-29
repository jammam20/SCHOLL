class SchoolBus {
  const SchoolBus({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.plateNumber,
    required this.isActive,
    this.model,
    this.year,
    this.capacity,
    this.currentDriverId,
    this.insuranceExpiry,
    this.registrationExpiry,
    this.inspectionExpiry,
    this.lastMaintenanceAt,
  });

  final String id;
  final String schoolId;
  final String name;
  final String plateNumber;
  final bool isActive;

  // Vehicle profile fields (Feature: Vehicle Management). All optional —
  // a bus created before this existed, or one an admin hasn't filled in
  // yet, still works everywhere a bus is used; the vehicle management
  // screen is what prompts filling these in and surfaces warnings when
  // they're missing or expiring.
  final String? model;
  final int? year;
  final int? capacity;
  final String? currentDriverId;
  final DateTime? insuranceExpiry;
  final DateTime? registrationExpiry;
  final DateTime? inspectionExpiry;
  final DateTime? lastMaintenanceAt;

  bool _isExpiringOrExpired(DateTime? expiry, DateTime now, Duration within) {
    if (expiry == null) return false;
    return expiry.difference(now) <= within;
  }

  bool hasExpiringDocuments(DateTime now, {Duration within = const Duration(days: 30)}) {
    return _isExpiringOrExpired(insuranceExpiry, now, within) ||
        _isExpiringOrExpired(registrationExpiry, now, within) ||
        _isExpiringOrExpired(inspectionExpiry, now, within);
  }

  factory SchoolBus.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return SchoolBus(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      plateNumber: data['plateNumber'] as String? ?? '',
      isActive: data['isActive'] == true,
      model: data['model'] as String?,
      year: (data['year'] as num?)?.toInt(),
      capacity: (data['capacity'] as num?)?.toInt(),
      currentDriverId: data['currentDriverId'] as String?,
      insuranceExpiry: _asDateTime(data['insuranceExpiry']),
      registrationExpiry: _asDateTime(data['registrationExpiry']),
      inspectionExpiry: _asDateTime(data['inspectionExpiry']),
      lastMaintenanceAt: _asDateTime(data['lastMaintenanceAt']),
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
