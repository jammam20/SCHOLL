import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

/// Raised when an acknowledge/resolve can't proceed — carries a real,
/// user-facing explanation instead of a raw Firestore error string, the
/// same way EmergencyOperationException already does for SOS handling.
class IncidentOperationException implements Exception {
  const IncidentOperationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Admin-side reading and triage of driver-filed incident reports at
/// `schools/{schoolId}/incidents/{id}`. Incidents are created by the
/// driver app — this app never creates one, matching firestore.rules,
/// which only allows `create` when `driverId == request.auth.uid`.
///
/// The two update paths below write *exactly* the field sets
/// firestore.rules permits (`status`/`acknowledgedAt`/`acknowledgedBy` for
/// an acknowledge; those plus `resolvedAt`/`resolvedBy`/`resolutionNotes`
/// for a resolve) and nothing else — notably no `updatedAt`, which that
/// rule's `hasOnly(...)` list does not include and which would therefore
/// make every write fail.
class IncidentsRepository {
  IncidentsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuditLogRepository? auditLog,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _incidents(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('incidents');
  }

  /// Newest first, matching the (schoolId ASC, createdAt DESC) composite
  /// index already declared in firebase/firestore.indexes.json. Status
  /// filtering is applied client-side by the incidents page so the one
  /// stream serves every filter tab without a second subscription.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncidents(
    String schoolId, {
    int limit = 100,
  }) {
    return _incidents(schoolId)
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Only the incidents still needing attention — used by the dashboard
  /// alert feed and the live-ops map, which care about open work rather
  /// than history. Filtered client-side off [watchIncidents] for the same
  /// reason: one subscription, no extra index.
  Stream<List<SchoolIncident>> watchOpenIncidents(String schoolId) {
    return watchIncidents(schoolId).map(
      (snapshot) => snapshot.docs
          .map((doc) => SchoolIncident.fromMap(doc.id, doc.data()))
          .where((incident) => incident.status != IncidentStatus.resolved)
          .toList(),
    );
  }

  /// Moves a `reported` incident to `acknowledged`. Guarded client-side
  /// against a stale UI (two admins acting on the same row) so the user
  /// gets a real explanation rather than an opaque permission-denied from
  /// the rule's own status precondition.
  Future<void> acknowledgeIncident({
    required String schoolId,
    required String incidentId,
  }) async {
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) {
      throw const IncidentOperationException(
        'You need to be signed in to do that.',
      );
    }

    final ref = _incidents(schoolId).doc(incidentId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const IncidentOperationException(
        'This incident could not be found.',
      );
    }

    final status =
        IncidentStatusX.tryParse(data['status']) ?? IncidentStatus.reported;
    if (status != IncidentStatus.reported) {
      throw const IncidentOperationException(
        'This incident has already been acknowledged.',
      );
    }

    await ref.update({
      'status': IncidentStatus.acknowledged.value,
      'acknowledgedAt': FieldValue.serverTimestamp(),
      'acknowledgedBy': adminId,
    });

    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.incidentAcknowledged,
      entityType: 'incident',
      entityId: incidentId,
      tripId: data['tripId'] as String?,
      busId: data['busId'] as String?,
      driverId: data['driverId'] as String?,
      metadata: {'incidentType': data['type']?.toString() ?? ''},
    );
  }

  /// Resolves a `reported` or `acknowledged` incident. When resolving
  /// straight from `reported` (an admin who fixes something before ever
  /// pressing acknowledge), the acknowledge stamps are written in the same
  /// update — the resolve rule's `hasOnly` list explicitly permits them,
  /// so the record never ends up resolved-but-never-acknowledged.
  Future<void> resolveIncident({
    required String schoolId,
    required String incidentId,
    required String resolutionNotes,
  }) async {
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) {
      throw const IncidentOperationException(
        'You need to be signed in to do that.',
      );
    }

    final notes = resolutionNotes.trim();
    if (notes.isEmpty) {
      throw const IncidentOperationException(
        'Add a short note describing how this was resolved.',
      );
    }

    final ref = _incidents(schoolId).doc(incidentId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const IncidentOperationException(
        'This incident could not be found.',
      );
    }

    final status =
        IncidentStatusX.tryParse(data['status']) ?? IncidentStatus.reported;
    if (status == IncidentStatus.resolved) {
      throw const IncidentOperationException(
        'This incident has already been resolved.',
      );
    }

    await ref.update({
      'status': IncidentStatus.resolved.value,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': adminId,
      'resolutionNotes': notes,
      if (status == IncidentStatus.reported) ...{
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'acknowledgedBy': adminId,
      },
    });

    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.incidentResolved,
      entityType: 'incident',
      entityId: incidentId,
      tripId: data['tripId'] as String?,
      busId: data['busId'] as String?,
      driverId: data['driverId'] as String?,
      metadata: {
        'incidentType': data['type']?.toString() ?? '',
        'resolutionNotes': notes,
      },
    );
  }
}
