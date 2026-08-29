/// Deliberately a 3-step lifecycle (not the 2-step active/resolved that
/// SchoolEmergency uses) — an incident report needs a distinct "someone at
/// the school has seen this" signal before resolution, since incidents
/// (behavior issues, route-blocked reports) aren't all time-critical enough
/// to assume immediate action the way a raised emergency is.
enum IncidentStatus { reported, acknowledged, resolved }

extension IncidentStatusX on IncidentStatus {
  String get value => name;

  static IncidentStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in IncidentStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}
