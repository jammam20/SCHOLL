/// Which leg of the school day a trip covers (Feature: two daily trips).
///
/// There is still one base [SchoolRoute] per road — direction only changes
/// how its stops are ordered and which end is the fixed endpoint, not the
/// set of stops themselves. See `TripDirection.stopOrder` callers in the
/// admin/driver repositories for how a route's stop list gets reversed for
/// [returnTrip].
enum TripDirection {
  outbound,
  returnTrip;

  /// The literal stored on `SchoolTrip.direction` — `'return'`, not
  /// `'returnTrip'` (`return` is a reserved word, so the enum member can't
  /// be named that, but the persisted value should read naturally).
  String get value => switch (this) {
    TripDirection.outbound => 'outbound',
    TripDirection.returnTrip => 'return',
  };

  static TripDirection fromValue(Object? value) =>
      value == 'return' ? TripDirection.returnTrip : TripDirection.outbound;
}
