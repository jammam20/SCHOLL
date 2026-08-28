import 'package:cloud_firestore/cloud_firestore.dart';

class TripsRepository {
  TripsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // firestore.rules lets a parent read a student document only when their
  // uid appears in that document's parentIds — this query only ever
  // returns documents this parent is already allowed to see.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyStudents({
    required String schoolId,
    required String parentUid,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('parentIds', arrayContains: parentUid)
        .snapshots();
  }

  // Matches the composite index (routeId ASC, scheduledAt DESC) in
  // firebase/firestore.indexes.json. There's no explicit "today's trip"
  // concept yet (see the Trips feature gap noted in the project review), so
  // this just returns the most recently scheduled trip for the route.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchLatestTripForRoute({
    required String schoolId,
    required String routeId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .where('routeId', isEqualTo: routeId)
        .orderBy('scheduledAt', descending: true)
        .limit(1)
        .snapshots();
  }
}
