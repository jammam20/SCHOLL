import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// Raised when a pickup point can't be saved — carries user-facing copy
/// rather than a raw Firestore error, matching [SchoolLocationException]'s
/// approach for the school's own coordinate.
class PickupPointException implements Exception {
  const PickupPointException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Admin-managed shared pickup locations at
/// `schools/{schoolId}/pickupPoints/{id}` — distinct from a student's own
/// door-to-door coordinate. firestore.rules allows any active member to
/// read (a parent needs to see the point their child is assigned to) and
/// only a school admin to write.
class PickupPointsRepository {
  PickupPointsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _points(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('pickupPoints');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPickupPoints(
    String schoolId,
  ) {
    return _points(schoolId).orderBy('name').snapshots();
  }

  /// Coordinates are range-checked client-side before the write, for the
  /// same reason [SchoolsRepository.updateLocation] does it: a bad
  /// tap/drag would otherwise persist a coordinate every nearest-point
  /// calculation and arrival check would then use.
  Future<String> createPickupPoint({
    required String schoolId,
    required String name,
    required double latitude,
    required double longitude,
    String? routeId,
    double radiusMeters = 100,
  }) async {
    _validate(name: name, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters);

    final ref = _points(schoolId).doc();
    await ref.set({
      'id': ref.id,
      ...PickupPoint(
        id: ref.id,
        schoolId: schoolId,
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        routeId: routeId,
        radiusMeters: radiusMeters,
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> updatePickupPoint({
    required String schoolId,
    required String pickupPointId,
    required String name,
    required double latitude,
    required double longitude,
    String? routeId,
    double radiusMeters = 100,
    required bool isActive,
  }) {
    _validate(name: name, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters);

    return _points(schoolId).doc(pickupPointId).update({
      'name': name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      // Written explicitly (rather than omitted) so clearing a point's
      // route actually clears it instead of silently keeping the old one.
      'routeId': routeId,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setPickupPointActive({
    required String schoolId,
    required String pickupPointId,
    required bool isActive,
  }) {
    return _points(schoolId).doc(pickupPointId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePickupPoint({
    required String schoolId,
    required String pickupPointId,
  }) {
    return _points(schoolId).doc(pickupPointId).delete();
  }

  /// Assigns (or clears, with a null [pickupPointId]) a student's shared
  /// pickup point. Student writes are admin-only per firestore.rules'
  /// `students/{studentId}` write rule.
  Future<void> assignStudentToPickupPoint({
    required String schoolId,
    required String studentId,
    required String? pickupPointId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .update({
          'pickupPointId': pickupPointId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  void _validate({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) {
    if (name.trim().isEmpty) {
      throw const PickupPointException('Give this pickup point a name.');
    }
    if (!isValidLatLng(latitude, longitude)) {
      throw const PickupPointException('That location is not valid.');
    }
    if (radiusMeters <= 0) {
      throw const PickupPointException(
        'The safe-zone radius must be greater than zero.',
      );
    }
  }
}
