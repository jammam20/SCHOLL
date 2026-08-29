import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// Read-only. The driver app needs exactly one thing from the school
/// document: its coordinates, which are every trip's fixed final stop and
/// therefore the last point in the ETA engine's stop list (see
/// `computeTripEta` and the `__school__` sentinel in StopOrderRepository).
/// firestore.rules opens `schools/{schoolId}` reads to any active member,
/// so no extra permission is involved.
class SchoolsRepository {
  SchoolsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Emits null while the document is missing — a school whose admin hasn't
  /// set a location yet is a normal state the ETA view degrades around, not
  /// an error.
  Stream<School?> watchSchool({required String schoolId}) {
    return _firestore.collection('schools').doc(schoolId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return School.fromMap(snapshot.id, data);
    });
  }
}
