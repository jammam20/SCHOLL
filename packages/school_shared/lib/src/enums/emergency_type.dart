enum EmergencyType { accident, vehicleBreakdown, medical, security, other }

extension EmergencyTypeX on EmergencyType {
  // 'vehicle_breakdown' is stored/compared in snake_case (matching the
  // spec's wire format); every other value happens to be a single word so
  // `.name` already matches.
  String get value => switch (this) {
    EmergencyType.vehicleBreakdown => 'vehicle_breakdown',
    _ => name,
  };

  static EmergencyType? tryParse(Object? value) {
    if (value is! String) return null;
    for (final type in EmergencyType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
