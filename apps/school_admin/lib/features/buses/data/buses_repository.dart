import 'package:cloud_firestore/cloud_firestore.dart';

class BusesRepository {
  BusesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

    return ref.id;
  }

  Future<void> updateBus({
    required String schoolId,
    required String busId,
    required Map<String, dynamic> data,
  }) {
    return _buses(schoolId)
        .doc(busId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> setBusActive({
    required String schoolId,
    required String busId,
    required bool active,
  }) {
    return _buses(schoolId).doc(busId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
