enum ReassignmentType { driverReassigned, busReassigned, routeChanged, stopSkipped }

extension ReassignmentTypeX on ReassignmentType {
  String get value => switch (this) {
    ReassignmentType.driverReassigned => 'driver_reassigned',
    ReassignmentType.busReassigned => 'bus_reassigned',
    ReassignmentType.routeChanged => 'route_changed',
    ReassignmentType.stopSkipped => 'stop_skipped',
  };

  static ReassignmentType? tryParse(Object? value) {
    if (value is! String) return null;
    for (final type in ReassignmentType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
