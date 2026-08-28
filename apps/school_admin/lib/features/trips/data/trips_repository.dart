import 'package:cloud_firestore/cloud_firestore.dart';

class TripsRepository {
  TripsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _trips(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('trips');
  }

  // `limit` keeps this from reading every trip the school has ever
  // scheduled on every page load — the admin_home_page._TripsTab UI bumps
  // it by _pageSize each time "Load more" is tapped rather than fetching
  // everything up front.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTrips(
    String schoolId, {
    int limit = 30,
  }) {
    return _trips(schoolId)
        .orderBy('scheduledAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<String> createTrip({
    required String schoolId,
    required String routeId,
    required String routeName,
    required String busId,
    required String busName,
    required String busPlateNumber,
    required String driverId,
    required String driverName,
    required DateTime scheduledAt,
  }) async {
    final ref = _trips(schoolId).doc();

    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'routeId': routeId,
      'routeName': routeName,
      'busId': busId,
      'busName': busName,
      'busPlateNumber': busPlateNumber,
      'driverId': driverId,
      'driverName': driverName,
      'status': 'scheduled',
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  // A direct write — firestore.rules already grants a school admin full
  // write access to `trips/{tripId}`, so unlike the driver app's own
  // updateStatus (which needs isValidTripTransition to fence a driver's
  // narrower self-update), this doesn't need the same guard.
  Future<void> updateStatus({
    required String schoolId,
    required String tripId,
    required String status,
  }) {
    return _trips(schoolId).doc(tripId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
