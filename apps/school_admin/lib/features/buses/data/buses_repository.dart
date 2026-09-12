import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

class BusesRepository {
  BusesRepository({FirebaseFirestore? firestore, AuditLogRepository? auditLog})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> _buses(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('buses');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBuses(String schoolId) {
    return _buses(schoolId).orderBy('name').snapshots();
  }

  Future<String> createBus({
    required String schoolId,
    required String name,
    required String plateNumber,
    int? capacity,
  }) async {
    final ref = _buses(schoolId).doc();

    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'name': name.trim(),
      'plateNumber': plateNumber.trim(),
      'capacity': capacity,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.busCreated,
      entityType: 'bus',
      entityId: ref.id,
      busId: ref.id,
      metadata: {'plateNumber': plateNumber.trim(), 'capacity': ?capacity},
    );

    return ref.id;
  }

  Future<void> updateBus({
    required String schoolId,
    required String busId,
    required Map<String, dynamic> data,
  }) async {
    await _buses(schoolId)
        .doc(busId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.busUpdated,
      entityType: 'bus',
      entityId: busId,
      busId: busId,
      metadata: {'fields': data.keys.toList()},
    );
  }

  Future<void> setBusActive({
    required String schoolId,
    required String busId,
    required bool active,
  }) async {
    await _buses(schoolId).doc(busId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: active ? AuditActions.busRestored : AuditActions.busArchived,
      entityType: 'bus',
      entityId: busId,
      busId: busId,
    );
  }
}
