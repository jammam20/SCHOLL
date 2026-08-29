import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// Operational detail for drivers — `schools/{schoolId}/driverProfiles/{uid}`
/// (license, training, assigned buses/routes) — layered on top of the
/// existing `members/{uid}` record that [DriversRepository] owns.
///
/// The two are deliberately never merged: `members` stays auth/role/status
/// only (its firestore.rules update rule restricts an admin to exactly
/// `status`/`isActive`/`updatedAt`, so license fields could not live there
/// even if we wanted them to), while `driverProfiles` is fully
/// admin-writable. Approving or suspending a driver still goes through
/// DriversRepository, unchanged.
class DriverProfilesRepository {
  DriverProfilesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _profiles(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('driverProfiles');
  }

  /// Every profile in the school. Unordered on purpose — a profile
  /// document's id is the driver's uid and it carries no name, so the
  /// driver-management screen sorts by the member record's `displayName`
  /// after joining the two, rather than by anything on this document.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchProfiles(String schoolId) {
    return _profiles(schoolId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile({
    required String schoolId,
    required String uid,
  }) {
    return _profiles(schoolId).doc(uid).snapshots();
  }

  /// Upsert, not update — a driver who has never had operational detail
  /// recorded has no profile document at all, so the first save has to
  /// create it. `merge: true` keeps any field this form doesn't own
  /// (`documentUrls`, written by whatever uploads them) intact.
  Future<void> saveProfile({
    required String schoolId,
    required String uid,
    String? licenseNumber,
    DateTime? licenseExpiry,
    DateTime? trainingCompletedAt,
    List<String>? assignedBusIds,
    List<String>? assignedRouteIds,
  }) {
    return _profiles(schoolId).doc(uid).set({
      'uid': uid,
      'schoolId': schoolId,
      'licenseNumber': licenseNumber?.trim(),
      'licenseExpiry': licenseExpiry == null
          ? null
          : Timestamp.fromDate(licenseExpiry),
      'trainingCompletedAt': trainingCompletedAt == null
          ? null
          : Timestamp.fromDate(trainingCompletedAt),
      'assignedBusIds': ?assignedBusIds,
      'assignedRouteIds': ?assignedRouteIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// A driver's member record joined to their optional [DriverProfile] —
/// what every driver-management screen actually renders. `profile` is null
/// for a driver nobody has recorded operational detail for yet, which is
/// the normal state for a newly-approved driver.
class DriverWithProfile {
  const DriverWithProfile({
    required this.uid,
    required this.displayName,
    required this.status,
    this.profile,
  });

  final String uid;
  final String displayName;
  final String status;
  final DriverProfile? profile;

  bool get isApproved => status == 'approved';

  /// The spec's own "License expires in N days" alert window.
  static const licenseAlertWindow = Duration(days: 14);

  bool licenseExpiringSoon(DateTime now) =>
      profile?.licenseExpiringWithin(licenseAlertWindow, now) ?? false;

  bool get licenseExpired => profile?.licenseExpired ?? false;

  /// True when this driver needs an admin to do something about their
  /// paperwork — used to sort them to the top of the list and to drive the
  /// "needs attention" count.
  bool needsAttention(DateTime now) =>
      licenseExpired || licenseExpiringSoon(now);
}
