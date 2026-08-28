import 'package:cloud_firestore/cloud_firestore.dart';

/// Sentinel appended to the end of every computed stop order to represent
/// the school itself — the trip's fixed final destination. Mirrors
/// apps/school_driver/lib/features/trips/data/stop_order_repository.dart,
/// which is the one that actually sets this field.
const schoolStopId = '__school__';

/// Read-only: the parent app only displays a trip's pickup order, never
/// sets it.
class StopOrderRepository {
  StopOrderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<String>> watchStopOrder({
    required String schoolId,
    required String tripId,
  }) {
    return _trip(schoolId, tripId).snapshots().map((snapshot) {
      final order = snapshot.data()?['stopOrder'];
      if (order is! List) return const <String>[];
      return order.whereType<String>().toList();
    });
  }

  Stream<Set<String>> watchBoardedStudents({
    required String schoolId,
    required String tripId,
  }) {
    return _trip(schoolId, tripId).snapshots().map((snapshot) {
      final boarded = snapshot.data()?['boardedStudents'];
      if (boarded is! List) return const <String>{};
      return boarded.whereType<String>().toSet();
    });
  }

  DocumentReference<Map<String, dynamic>> _trip(String schoolId, String tripId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .doc(tripId);
  }
}
