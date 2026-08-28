import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../domain/emergency_operation_exception.dart';

/// Admin-side monitoring/resolution of emergencies raised by drivers (see
/// EmergenciesRepository in the driver app, which creates the records this
/// one only ever reads and resolves). Uses a `collectionGroup('emergencies')`
/// query — the same technique already used for the cross-school
/// `members` lookup in SuperAdminRepository — because an emergency lives
/// nested under its own trip (`schools/{schoolId}/trips/{tripId}/
/// emergencies/{emergencyId}`), and this needs every one of them across
/// every trip in the school, not just the ones on currently-live trips.
class EmergenciesRepository {
  EmergenciesRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _emergency(
    String schoolId,
    String tripId,
    String emergencyId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .doc(tripId)
        .collection('emergencies')
        .doc(emergencyId);
  }

  /// Every active emergency in the school, newest first — used for live
  /// monitoring (section 8). Pass [status] to instead pull the resolved
  /// history (section 10); omit it for the full newest-first list of both.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchEmergencies({
    required String schoolId,
    EmergencyStatus? status,
    int limit = 30,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collectionGroup('emergencies')
        .where('schoolId', isEqualTo: schoolId);
    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }
    return query.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  /// Convenience over [watchEmergencies] for the live-monitoring case.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveEmergencies(String schoolId) {
    return watchEmergencies(schoolId: schoolId, status: EmergencyStatus.active);
  }

  /// Resolves any emergency in this admin's school. Authorization itself is
  /// enforced by firestore.rules (isSchoolAdmin(schoolId)) and by the app
  /// only being reachable by a signed-in school admin in the first place —
  /// unlike the driver app's own resolveEmergency, there's no narrower
  /// per-record ownership to re-check client-side here (see
  /// TripsRepository.updateStatus in this same app for the same reasoning).
  Future<void> resolveEmergency({
    required String schoolId,
    required String tripId,
    required String emergencyId,
    String? resolutionNote,
  }) async {
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) {
      throw const EmergencyOperationException(
        EmergencyOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final ref = _emergency(schoolId, tripId, emergencyId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const EmergencyOperationException(
          EmergencyOperationError.emergencyNotFound,
          'This emergency could not be found.',
        );
      }

      final status = EmergencyStatusX.tryParse(data['status']) ?? EmergencyStatus.active;
      final eligibility = checkEmergencyResolutionEligibility(
        status: status,
        isAuthorized: true,
      );
      if (eligibility == EmergencyResolutionEligibility.alreadyResolved) {
        throw const EmergencyOperationException(
          EmergencyOperationError.emergencyAlreadyResolved,
          'This emergency has already been resolved.',
        );
      }

      transaction.update(ref, {
        'status': EmergencyStatus.resolved.value,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': adminId,
        if (resolutionNote != null && resolutionNote.trim().isNotEmpty)
          'resolutionNote': resolutionNote.trim(),
      });

      transaction.set(
        _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('trips')
            .doc(tripId)
            .collection('events')
            .doc(),
        {
          'type': 'emergency_resolved',
          'resolvedBy': adminId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }
}
