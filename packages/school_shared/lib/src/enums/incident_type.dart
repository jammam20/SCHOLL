enum IncidentType {
  accident,
  vehicleBreakdown,
  studentMedical,
  studentBehavior,
  routeBlocked,
  policeEmergency,
  other,
}

extension IncidentTypeX on IncidentType {
  // snake_case wire values, matching EmergencyType's convention for
  // multi-word values; single-word values use `.name` as-is.
  String get value => switch (this) {
    IncidentType.vehicleBreakdown => 'vehicle_breakdown',
    IncidentType.studentMedical => 'student_medical',
    IncidentType.studentBehavior => 'student_behavior',
    IncidentType.routeBlocked => 'route_blocked',
    IncidentType.policeEmergency => 'police_emergency',
    _ => name,
  };

  static IncidentType? tryParse(Object? value) {
    if (value is! String) return null;
    for (final type in IncidentType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
