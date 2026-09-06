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
  // this returns the most recently *scheduled* candidates for the route —
  // deliberately more than one. A single result picked by scheduledAt alone
  // is wrong whenever a later-scheduled trip on the same route gets
  // cancelled (or two same-day trips exist): it would permanently shadow an
  // earlier-scheduled trip that is actually active right now. The caller
  // (child_journey_card.dart's _TripSection) picks the right one out of
  // these candidates — this method can't do that itself since Firestore
  // can't order by "is this the one that's live" without a stored field.
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
        .limit(10)
        .snapshots();
  }
}
