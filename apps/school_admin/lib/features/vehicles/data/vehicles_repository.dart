import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// The vehicle-profile and maintenance side of a bus, layered on top of
/// the plain name/plate/isActive CRUD [BusesRepository] already owns.
///
/// Kept as its own repository rather than growing BusesRepository because
/// it reads/writes a different shape of data (the `maintenance`
/// subcollection, plus the vehicle-profile date fields added to
/// `SchoolBus`) and is only ever used by the vehicle-management screens —
/// the buses list, the trip-creation dialog and the analytics tab all keep
/// using BusesRepository unchanged.
class VehiclesRepository {
  VehiclesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _buses(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('buses');
  }

  CollectionReference<Map<String, dynamic>> _maintenance(
    String schoolId,
    String busId,
  ) {
    return _buses(schoolId).doc(busId).collection('maintenance');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBuses(String schoolId) {
    return _buses(schoolId).orderBy('name').snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchBus({
    required String schoolId,
    required String busId,
  }) {
    return _buses(schoolId).doc(busId).snapshots();
  }

  /// Every maintenance/document item for one bus, soonest-due first —
  /// which is the order an admin actually triages them in. A single-field
  /// `orderBy` needs no composite index.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMaintenance({
    required String schoolId,
    required String busId,
  }) {
    return _maintenance(schoolId, busId).orderBy('dueAt').snapshots();
  }

  /// Writes the vehicle-profile fields on the bus document itself.
  /// A null value in [MaintenanceProfileUpdate] means "clear this field",
  /// which is why this takes an explicit update object rather than a
  /// sparse map — an omitted key and an intentionally-cleared date would
  /// otherwise be indistinguishable.
  Future<void> updateVehicleProfile({
    required String schoolId,
    required String busId,
    required VehicleProfileUpdate update,
  }) {
    return _buses(schoolId).doc(busId).update({
      ...update.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> addMaintenanceRecord({
    required String schoolId,
    required String busId,
    required MaintenanceItemType itemType,
    required DateTime dueAt,
    String description = '',
    String? notes,
  }) async {
    final ref = _maintenance(schoolId, busId).doc();

    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'busId': busId,
      'itemType': itemType.value,
      'description': description.trim(),
      'dueAt': Timestamp.fromDate(dueAt),
      'completedAt': null,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  /// Marks one item done. Completing an item also stamps the bus's own
  /// `lastMaintenanceAt`, and — for the three document types that have a
  /// matching expiry field on the bus — rolls that expiry forward to the
  /// [nextDueAt] the admin supplied, so the bus-level warning indicator and
  /// the itemized log can never disagree about whether the insurance is
  /// current.
  Future<void> completeMaintenanceRecord({
    required String schoolId,
    required String busId,
    required String recordId,
    required MaintenanceItemType itemType,
    DateTime? nextDueAt,
    String? notes,
  }) async {
    final batch = _firestore.batch();

    batch.update(_maintenance(schoolId, busId).doc(recordId), {
      'completedAt': FieldValue.serverTimestamp(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final expiryField = _expiryFieldFor(itemType);
    batch.update(_buses(schoolId).doc(busId), {
      'lastMaintenanceAt': FieldValue.serverTimestamp(),
      if (expiryField != null && nextDueAt != null)
        expiryField: Timestamp.fromDate(nextDueAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // A completed recurring item is replaced by a fresh one for the next
    // cycle rather than the completed record being reused — see
    // MaintenanceRecord's own doc comment, which is explicit that history
    // is preserved by creating a new record.
    if (nextDueAt != null) {
      await addMaintenanceRecord(
        schoolId: schoolId,
        busId: busId,
        itemType: itemType,
        dueAt: nextDueAt,
      );
    }
  }

  Future<void> deleteMaintenanceRecord({
    required String schoolId,
    required String busId,
    required String recordId,
  }) {
    return _maintenance(schoolId, busId).doc(recordId).delete();
  }

  /// Which vehicle-profile expiry field on the bus document (if any) a
  /// maintenance item type corresponds to. Oil/tires/brakes/other have no
  /// bus-level expiry — they live purely in the maintenance log.
  static String? _expiryFieldFor(MaintenanceItemType type) => switch (type) {
    MaintenanceItemType.insurance => 'insuranceExpiry',
    MaintenanceItemType.registration => 'registrationExpiry',
    MaintenanceItemType.inspection => 'inspectionExpiry',
    _ => null,
  };
}

/// An explicit, nullable-aware description of a vehicle-profile edit.
/// Every field is a `_Field<T>` wrapper so "leave unchanged" (the field is
/// absent) stays distinguishable from "clear this value" (present, null) —
/// a plain `Map<String, dynamic>` can't express that difference, and
/// silently keeping a stale insurance expiry an admin meant to clear would
/// keep showing a false all-clear on the vehicle list.
class VehicleProfileUpdate {
  const VehicleProfileUpdate({
    this.model,
    this.year,
    this.capacity,
    this.currentDriverId,
    this.insuranceExpiry,
    this.registrationExpiry,
    this.inspectionExpiry,
  });

  final FieldEdit<String>? model;
  final FieldEdit<int>? year;
  final FieldEdit<int>? capacity;
  final FieldEdit<String>? currentDriverId;
  final FieldEdit<DateTime>? insuranceExpiry;
  final FieldEdit<DateTime>? registrationExpiry;
  final FieldEdit<DateTime>? inspectionExpiry;

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{};
    void put(String key, FieldEdit<Object>? edit) {
      if (edit == null) return;
      final value = edit.value;
      data[key] = value is DateTime ? Timestamp.fromDate(value) : value;
    }

    put('model', model);
    put('year', year);
    put('capacity', capacity);
    put('currentDriverId', currentDriverId);
    put('insuranceExpiry', insuranceExpiry);
    put('registrationExpiry', registrationExpiry);
    put('inspectionExpiry', inspectionExpiry);
    return data;
  }
}

/// "Set this field to [value]" — where a null [value] explicitly means
/// clear it. Absence of the whole [FieldEdit] means "don't touch it".
class FieldEdit<T extends Object> {
  const FieldEdit(this.value);
  const FieldEdit.clear() : value = null;

  final T? value;
}
