import 'package:firebase_database/firebase_database.dart';

import '../domain/live_trip_position.dart';

/// A read-only view of the RTDB location node the driver's own tracking
/// writes to. Deliberately a separate, tiny repository rather than a new
/// method on DriverTrackingRepository: that class owns the *write* side
/// (the foreground service, permissions, the position stream) and is the
/// one piece of this app that must not be disturbed, while this is a plain
/// listener that the driver's own navigation view needs — the same shape
/// ParentTrackingRepository/OpsTrackingRepository already use against the
/// identical node.
class TripLocationRepository {
  TripLocationRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  Stream<LiveTripPosition?> watchTripPosition({
    required String schoolId,
    required String tripId,
  }) {
    return _database
        .ref('schools/$schoolId/trips/$tripId/location')
        .onValue
        .map((event) => LiveTripPosition.fromRtdbValue(event.snapshot.value));
  }
}
