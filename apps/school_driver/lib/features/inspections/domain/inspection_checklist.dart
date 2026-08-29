/// Pure, dependency-free description of a vehicle inspection checklist —
/// deliberately kept out of both the repository and the UI (matching how
/// `trip_operation_exception.dart` holds the trip feature's decision logic)
/// so "what counts as a pass" is one testable function rather than a rule
/// re-implemented at each call site.
library;

/// Which end of the trip an inspection belongs to. The same item set is
/// used for both — the difference is when it's recorded and what it gates
/// (a failed `pre` inspection blocks the trip from starting; a `post` one
/// is a record of how the vehicle came back).
enum InspectionType { pre, post }

extension InspectionTypeX on InspectionType {
  /// Matches the `type('pre'|'post')` field name the stored document uses.
  String get value => name;

  static InspectionType? tryParse(Object? value) {
    if (value is! String) return null;
    for (final type in InspectionType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// The checklist itself. Stored as a `Map<String, bool>` keyed by
/// [InspectionItemX.value] rather than a list of booleans, so adding or
/// reordering an item later can never silently reinterpret an already-
/// written historical inspection.
enum InspectionItem {
  brakes,
  tires,
  lights,
  mirrors,
  doors,
  emergencyEquipment,
}

extension InspectionItemX on InspectionItem {
  /// snake_case wire values, matching the convention IncidentType and
  /// EmergencyType already use for multi-word values.
  String get value => switch (this) {
    InspectionItem.emergencyEquipment => 'emergency_equipment',
    _ => name,
  };

  static InspectionItem? tryParse(Object? value) {
    if (value is! String) return null;
    for (final item in InspectionItem.values) {
      if (item.value == value) return item;
    }
    return null;
  }
}

/// Whether a submitted checklist passes. v1 treats *every* listed item as
/// critical, per the feature's own "if a critical item fails, the vehicle
/// cannot start the route" — there is no partial pass, and a missing answer
/// counts as a fail rather than being assumed good, so an incompletely
/// filled form can never gate a trip open.
bool isInspectionPassed(Map<String, bool> items) {
  for (final item in InspectionItem.values) {
    if (items[item.value] != true) return false;
  }
  return true;
}

/// The items that were answered "no" (or left unanswered), in checklist
/// order — what the driver is shown when an inspection blocks a trip, so
/// "the vehicle cannot start" always names the reason.
List<InspectionItem> failedInspectionItems(Map<String, bool> items) {
  return [
    for (final item in InspectionItem.values)
      if (items[item.value] != true) item,
  ];
}
