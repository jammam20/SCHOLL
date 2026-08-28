import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../domain/trip_operation_exception.dart';

class TripsRepository {
  TripsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _trip(String schoolId, String tripId) {
    return _firestore.collection('schools').doc(schoolId).collection('trips').doc(tripId);
  }

  // Matches the composite index (driverId ASC, scheduledAt DESC) in
  // firebase/firestore.indexes.json.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyTrips({
    required String schoolId,
    required String driverId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .orderBy('scheduledAt', descending: true)
        .snapshots();
  }

  // A transaction rather than a blind `.update()`: it re-reads the trip's
  // *current* status from the server at write time and re-validates the
  // transition against it there, inside the same atomic operation — so
  // two rapid calls (a double-tap on "Complete", a retry after a flaky
  // response) can't race past each other into an invalid state the way
  // they could if each just trusted whatever status the client had
  // cached. Still backed by firestore.rules' own isValidTripTransition as
  // the actually-authoritative check; this is what turns a rules
  // rejection into a clear, specific message instead of a raw
  // permission-denied.
  Future<void> updateStatus({
    required String schoolId,
    required String tripId,
    required TripStatus status,
    Map<String, dynamic> extra = const {},
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final tripRef = _trip(schoolId, tripId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(tripRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const TripOperationException(
          TripOperationError.tripNotFound,
          'This trip could not be found.',
        );
      }

      assertOwnership(
        tripDriverId: data['driverId'] as String? ?? '',
        currentUserId: driverId,
      );

      final trip = SchoolTrip.fromMap(snapshot.id, data);
      assertCanTransition(trip.status, status);

      transaction.update(tripRef, {
        'status': status.name,
        ...extra,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(tripRef.collection('events').doc(), {
        'type': status.name,
        'driverId': driverId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
