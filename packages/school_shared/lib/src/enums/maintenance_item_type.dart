enum MaintenanceItemType {
  oilChange,
  tires,
  brakes,
  inspection,
  insurance,
  registration,
  other,
}

extension MaintenanceItemTypeX on MaintenanceItemType {
  String get value => switch (this) {
    MaintenanceItemType.oilChange => 'oil_change',
    _ => name,
  };

  static MaintenanceItemType? tryParse(Object? value) {
    if (value is! String) return null;
    for (final type in MaintenanceItemType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
