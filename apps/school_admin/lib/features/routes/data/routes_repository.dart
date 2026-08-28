import 'package:cloud_firestore/cloud_firestore.dart';

class RoutesRepository {
  RoutesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _routes(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('routes');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRoutes(String schoolId) {
    return _routes(schoolId).orderBy('name').snapshots();
  }

  Future<String> createRoute({
    required String schoolId,
    required String name,
    String? description,
  }) async {
    final ref = _routes(schoolId).doc();

    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'name': name.trim(),
      'description': description?.trim(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }
}
