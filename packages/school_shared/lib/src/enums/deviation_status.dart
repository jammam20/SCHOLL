/// Mirrors the exact state machine described for route-deviation detection:
/// NORMAL -> DEVIATION_STARTED -> DEVIATING -> DEVIATION_ENDED. Persisted
/// per-trip (one live document) so consecutive GPS updates can tell
/// "already alerted for this deviation" from "a new one just started"
/// instead of re-alerting on every position update.
enum DeviationStatus { normal, deviationStarted, deviating, deviationEnded }

extension DeviationStatusX on DeviationStatus {
  String get value => switch (this) {
    DeviationStatus.deviationStarted => 'deviation_started',
    DeviationStatus.deviationEnded => 'deviation_ended',
    _ => name,
  };

  static DeviationStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final s in DeviationStatus.values) {
      if (s.value == value) return s;
    }
    return null;
  }
}
