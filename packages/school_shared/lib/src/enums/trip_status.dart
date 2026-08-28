enum TripStatus {
  scheduled,
  starting,
  active,
  paused,
  completed,
  cancelled,
  emergency,
}

extension TripStatusX on TripStatus {
  bool canTransitionTo(TripStatus next) => switch (this) {
    TripStatus.scheduled =>
      next == TripStatus.starting || next == TripStatus.cancelled,
    TripStatus.starting =>
      next == TripStatus.active || next == TripStatus.cancelled,
    TripStatus.active =>
      next == TripStatus.paused ||
          next == TripStatus.completed ||
          next == TripStatus.emergency,
    TripStatus.paused =>
      next == TripStatus.active ||
          next == TripStatus.cancelled ||
          next == TripStatus.emergency,
    TripStatus.emergency =>
      next == TripStatus.completed || next == TripStatus.cancelled,
    TripStatus.completed || TripStatus.cancelled => false,
  };
}
