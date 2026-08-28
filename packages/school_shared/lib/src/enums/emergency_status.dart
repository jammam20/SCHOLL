enum EmergencyStatus { active, resolved }

extension EmergencyStatusX on EmergencyStatus {
  String get value => name;

  static EmergencyStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in EmergencyStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}
