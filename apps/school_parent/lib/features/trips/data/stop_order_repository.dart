import 'package:cloud_firestore/cloud_firestore.dart';

/// Sentinel appended to the end of every computed stop order to represent
/// the school itself — the trip's fixed final destination. Mirrors
/// apps/school_driver/lib/features/trips/data/stop_order_repository.dart,
/// which is the one that actually sets this field.
const schoolStopId = '__school__';

/// The three per-trip progress fields the parent app reads together —
/// today's pickup order and which of its stops are already done. They all
/// live on the same trip document, so they're parsed from one snapshot
/// instead of the three separate `.snapshots()` listeners this used to
/// open (which also let the card render a stop order and a boarded set
/// from two different moments in time).
class TripStopProgress {
  const TripStopProgress({
    this.stopOrder = const [],
    this.boardedStudents = const {},
    this.droppedOffStudents = const {},
  });

  /// Student ids in pickup order, ending with [schoolStopId]. Empty until
  /// the driver's app computes it for the day.
  final List<String> stopOrder;

  /// Students the driver has marked as boarded on this trip.
  final Set<String> boardedStudents;

  /// Students the driver has marked as dropped off on this trip — the
  /// mirror image of [boardedStudents] for the return leg.
  final Set<String> droppedOffStudents;

  bool isCompletedStop(String studentId) =>
      boardedStudents.contains(studentId) ||
      droppedOffStudents.contains(studentId);
}

/// Read-only: the parent app only displays a trip's pickup order and
/// progress, never sets it.
class StopOrderRepository {
  StopOrderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<TripStopProgress> watchStopProgress({
    required String schoolId,
    required String tripId,
  }) {
    return _trip(schoolId, tripId).snapshots().map((snapshot) {
      final data = snapshot.data();
      return TripStopProgress(
        stopOrder: _stringList(data?['stopOrder']),
        boardedStudents: _stringList(data?['boardedStudents']).toSet(),
        droppedOffStudents: _stringList(data?['droppedOffStudents']).toSet(),
      );
    });
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList();
  }

  DocumentReference<Map<String, dynamic>> _trip(String schoolId, String tripId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('trips')
        .doc(tripId);
  }
}
