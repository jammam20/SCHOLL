import 'package:firebase_database/firebase_database.dart';

class ParentTrackingRepository {
  ParentTrackingRepository({
    FirebaseDatabase? database,
  }) : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  Stream<DatabaseEvent> watchTripLocation({
    required String schoolId,
    required String tripId,
  }) {
    return _database
        .ref('schools/$schoolId/trips/$tripId/location')
        .onValue;
  }
}