import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// Read-only: the driver app only needs to see students to build and
/// display a trip's pickup order, never to edit them.
class StudentsRepository {
  StudentsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Student>> watchStudentsForRoute({
    required String schoolId,
    required String routeId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('routeId', isEqualTo: routeId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Student.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
