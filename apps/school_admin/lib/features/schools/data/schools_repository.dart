import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../audit/data/audit_log_repository.dart';

class SchoolLocationException implements Exception {
  const SchoolLocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SchoolsRepository {
  SchoolsRepository({FirebaseFirestore? firestore, AuditLogRepository? auditLog})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auditLog = auditLog ?? AuditLogRepository();

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> get _schools =>
      _firestore.collection('schools');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSchools() {
    return _schools
        .orderBy('name')
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSchool(
      String schoolId,
      ) {
    return _schools.doc(schoolId).snapshots();
  }

  Future<String> createSchool({
    required String name,
    required String code,
    String? phone,
    String? address,
  }) async {
    final ref = _schools.doc();

    await ref.set({
      'id': ref.id,
      'name': name.trim(),
      'code': code.trim(),
      'phone': phone?.trim(),
      'address': address?.trim(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> setSchoolActive(
      String schoolId,
      bool active,
      ) {
    return _schools.doc(schoolId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSchool({
    required String schoolId,
    required Map<String, dynamic> data,
  }) {
    return _schools.doc(schoolId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // firestore.rules' schools/{schoolId} update rule already grants a school
  // admin a direct write restricted to exactly ['latitude', 'longitude',
  // 'updatedAt'] — no Cloud Function is actually needed for this (the
  // previous callable-based version depended on Functions being deployed,
  // which they weren't, so this always threw). Validated client-side first
  // since a bad tap/drag could otherwise write an out-of-range coordinate
  // that every trip would then use as its fixed final stop.
  Future<void> updateLocation({
    required String schoolId,
    required double latitude,
    required double longitude,
  }) async {
    if (!isValidLatLng(latitude, longitude)) {
      throw const SchoolLocationException('That location is not valid.');
    }

    try {
      await _schools.doc(schoolId).update({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const SchoolLocationException(
          "You don't have permission to change this school's location.",
        );
      }
      throw const SchoolLocationException(
        "Couldn't save the school's location. Please try again.",
      );
    }
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.schoolLocationUpdated,
      entityType: 'school',
      entityId: schoolId,
    );
  }

  /// Operational settings — trip start window, absence cutoff, calendar
  /// (Features: driver trip start window, absence cutoff, school calendar).
  /// A null minutes value clears that restriction entirely, matching how
  /// `firestore.rules`/`School` treat "not configured".
  Future<void> updateSettings({
    required String schoolId,
    int? tripStartWindowMinutes,
    int? absenceCutoffMinutes,
    required List<int> weeklyHolidays,
    required List<String> specialHolidays,
  }) async {
    await _schools.doc(schoolId).update({
      'tripStartWindowMinutes': tripStartWindowMinutes,
      'absenceCutoffMinutes': absenceCutoffMinutes,
      'weeklyHolidays': weeklyHolidays,
      'specialHolidays': specialHolidays,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _auditLog.recordSafely(
      schoolId: schoolId,
      action: AuditActions.schoolSettingsUpdated,
      entityType: 'school',
      entityId: schoolId,
    );
  }
}