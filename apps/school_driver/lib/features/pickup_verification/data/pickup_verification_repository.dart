import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../../tracking/data/driver_tracking_repository.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../trips/domain/trip_operation_exception.dart';

/// Secure pickup verification records, stored at
/// `schools/{schoolId}/trips/{tripId}/pickupVerifications/{id}`.
/// firestore.rules allows `create` only for the trip's assigned driver, and
/// never update or delete — a verification attempt is an event, and events
/// don't get edited afterwards.
///
/// **What each method actually verifies**, because getting this wrong would
/// be worse than not having the feature:
///
/// * [PickupVerificationMethod.driverManual] is fully implemented. It is
///   exactly what its name says — the driver's own visual confirmation that
///   the right person is collecting the student — and is recorded as
///   `verified` or `failed` according to what the driver observed.
/// * [PickupVerificationMethod.qrCode] / [PickupVerificationMethod.otp] are
///   selectable and write a *real* record, but always with
///   [PickupVerificationStatus.pending]. There is nowhere in this system for
///   a parent to generate a pickup code today (no field on [Student] holds
///   one, and the parent app has no flow that writes one), so the driver app
///   has nothing to check a presented code against. The code the driver
///   typed is stored verbatim on the record so the school can reconcile it
///   by hand, and the record says plainly that no automated match ran.
///   Returning `verified` here would be claiming a check this code does not
///   perform.
class PickupVerificationRepository {
  PickupVerificationRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DriverTrackingRepository? tracking,
    AuditLogRepository? auditLog,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _tracking = tracking ?? DriverTrackingRepository(),
       _auditLog = auditLog ?? AuditLogRepository(firestore: firestore, auth: auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DriverTrackingRepository _tracking;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _verifications(
    String schoolId,
    String tripId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .doc(tripId)
        .collection('pickupVerifications');
  }

  /// The status a given attempt resolves to. Pure and separate from the
  /// write so the "an unimplemented method can never report success" rule
  /// is one readable expression rather than a branch buried in a batch.
  static PickupVerificationStatus outcomeFor({
    required PickupVerificationMethod method,
    required bool driverConfirmed,
  }) {
    return switch (method) {
      PickupVerificationMethod.driverManual =>
        driverConfirmed
            ? PickupVerificationStatus.verified
            : PickupVerificationStatus.failed,
      PickupVerificationMethod.qrCode ||
      PickupVerificationMethod.otp => PickupVerificationStatus.pending,
    };
  }

  /// Records one verification attempt and its audit entry in a single
  /// batch, and returns the status actually stored.
  ///
  /// [driverConfirmed] only means anything for
  /// [PickupVerificationMethod.driverManual]; for the code-based methods the
  /// outcome is `pending` regardless (see the class doc).
  Future<PickupVerificationStatus> recordVerification({
    required String schoolId,
    required String tripId,
    required String studentId,
    required PickupVerificationMethod method,
    required bool driverConfirmed,
    String? authorizedPersonName,
    String? presentedCode,
    String? notes,
  }) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw const TripOperationException(
        TripOperationError.unauthorized,
        'You need to be signed in to do that.',
      );
    }

    final status = outcomeFor(method: method, driverConfirmed: driverConfirmed);
    final location = await _tracking.getLastKnownLocation(
      schoolId: schoolId,
      tripId: tripId,
    );

    final noteParts = <String>[
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
      if (status == PickupVerificationStatus.pending)
        'Presented code recorded as '
            '"${presentedCode?.trim() ?? ''}". No automated code match ran: '
            'the driver app has no parent-generated code to check it against.',
    ];

    final verificationRef = _verifications(schoolId, tripId).doc();
    final batch = _firestore.batch();

    batch.set(verificationRef, {
      'schoolId': schoolId,
      'tripId': tripId,
      'studentId': studentId,
      'driverId': driverId,
      'method': method.value,
      'status': status.value,
      'recordedAt': FieldValue.serverTimestamp(),
      if (authorizedPersonName != null && authorizedPersonName.trim().isNotEmpty)
        'authorizedPersonName': authorizedPersonName.trim(),
      if (location != null) 'latitude': location.latitude,
      if (location != null) 'longitude': location.longitude,
      if (noteParts.isNotEmpty) 'notes': noteParts.join(' '),
    });

    batch.set(
      _auditLog.newEntryRef(schoolId),
      _auditLog.buildEntry(
        schoolId: schoolId,
        action: switch (status) {
          PickupVerificationStatus.verified => AuditActions.pickupVerified,
          PickupVerificationStatus.failed =>
            AuditActions.pickupVerificationFailed,
          PickupVerificationStatus.pending =>
            AuditActions.pickupVerificationPending,
        },
        entityType: 'pickupVerification',
        entityId: verificationRef.id,
        tripId: tripId,
        studentId: studentId,
        metadata: {'method': method.value, 'status': status.value},
      ),
    );

    await batch.commit();
    return status;
  }
}
