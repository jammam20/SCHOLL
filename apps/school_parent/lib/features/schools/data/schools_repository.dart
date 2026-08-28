import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// Read-only: the parent app only needs the school's location, as every
/// trip's fixed final stop.
class SchoolsRepository {
  SchoolsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<School?> watchSchool(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) return null;
      return School.fromMap(snapshot.id, data);
    });
  }
}
