import 'package:firebase_database/firebase_database.dart';

/// Read-only mirror of the driver/parent tracking repositories, used by the
/// admin app's "Live Ops" tab to watch every active trip's location at once.
class OpsTrackingRepository {
  OpsTrackingRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  Stream<DatabaseEvent> watchTripLocation({
    required String schoolId,
    required String tripId,
  }) {
    return _database.ref('schools/$schoolId/trips/$tripId/location').onValue;
  }
}
