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
    double deviationToleranceMeters = defaultDeviationToleranceMeters,
    // Feature: two daily trips / absence cutoff — minutes since UTC
    // midnight, see SchoolRoute's own doc comment. Must be accepted here as
    // well as in updateRoute: a route created with its daily schedule
    // already set (the common case — the Add route dialog collects both
    // directions up front) previously had that schedule silently dropped
    // until the admin happened to re-save through Edit.
    int? outboundScheduledMinutes,
    int? returnScheduledMinutes,
  }) async {
    final ref = _routes(schoolId).doc();

    await ref.set({
      'id': ref.id,
      'schoolId': schoolId,
      'name': name.trim(),
      'description': description?.trim(),
      'isActive': true,
      'deviationToleranceMeters': deviationToleranceMeters,
      'outboundScheduledMinutes': outboundScheduledMinutes,
      'returnScheduledMinutes': returnScheduledMinutes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  /// Edits a route's name/description and its deviation tolerance — the
  /// corridor width (in metres) the `onDriverLocationWritten` Cloud
  /// Function measures each bus against before flagging a route deviation.
  /// A rural route and a dense-urban one genuinely need different values,
  /// which is why this is per-route rather than a single school-wide
  /// constant.
  Future<void> updateRoute({
    required String schoolId,
    required String routeId,
    required String name,
    String? description,
    required double deviationToleranceMeters,
    required bool isActive,
    // Feature: two daily trips / absence cutoff — minutes since UTC
    // midnight, see SchoolRoute's own doc comment. Passing null clears that
    // direction's schedule (it isn't run on this route / no cutoff can be
    // computed from it).
    int? outboundScheduledMinutes,
    int? returnScheduledMinutes,
  }) {
    return _routes(schoolId).doc(routeId).update({
      'name': name.trim(),
      'description': description?.trim(),
      'deviationToleranceMeters': deviationToleranceMeters,
      'isActive': isActive,
      'outboundScheduledMinutes': outboundScheduledMinutes,
      'returnScheduledMinutes': returnScheduledMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRouteActive({
    required String schoolId,
    required String routeId,
    required bool active,
  }) {
    return _routes(schoolId).doc(routeId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Matches `SchoolRoute.deviationToleranceMeters`'s own default and the
/// `DEFAULT_DEVIATION_TOLERANCE_METERS` fallback in functions/src/index.ts
/// — a route created without an explicit value must behave identically on
/// both sides.
const defaultDeviationToleranceMeters = 400.0;

/// The sane range an admin may set a tolerance to. Below ~50 m ordinary
/// street-level GPS noise would trip constant false deviations; above
/// ~2 km a genuine detour would never be caught.
const minDeviationToleranceMeters = 50.0;
const maxDeviationToleranceMeters = 2000.0;
