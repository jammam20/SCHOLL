import '../enums/trip_direction.dart';
import '../enums/trip_status.dart';

class SchoolTrip {
  const SchoolTrip({
    required this.id,
    required this.schoolId,
    required this.routeId,
    required this.busId,
    required this.driverId,
    required this.status,
    required this.scheduledAt,
    this.direction = TripDirection.outbound,
    this.routeName = '',
    this.busName = '',
    this.busPlateNumber = '',
    this.driverName = '',
    this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.resumedAt,
    this.cancelledAt,
    this.cancelReason,
  });

  final String id;
  final String schoolId;
  final String routeId;
  final String busId;
  final String driverId;
  final TripStatus status;
  final DateTime scheduledAt;

  // Feature: two daily trips. Defaults to outbound so every trip document
  // written before this field existed keeps behaving exactly as it always
  // did — a school that never touches direction just runs one outbound
  // trip per day, same as before.
  final TripDirection direction;
  // Set once, by the driver app, the first time the trip actually goes
  // active (not re-set on a pause/resume) and when it's marked completed —
  // real operational timestamps used for on-time and duration reporting,
  // as opposed to scheduledAt which is just the plan.
  final DateTime? startedAt;
  final DateTime? completedAt;
  // Set (and overwritten) on every pause/resume cycle — only the most
  // recent pause/resume is kept here; the full history of every
  // pause/resume/board/etc. lives in the trip's `events` subcollection
  // instead (see TripsRepository/StopOrderRepository in the driver app).
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  // Denormalized onto the trip document at creation time (see
  // TripsRepository.createTrip in the admin app) so the driver and parent
  // apps can render a trip card from this document alone, without needing
  // separate read access to the buses/routes/members collections.
  final String routeName;
  final String busName;
  final String busPlateNumber;
  final String driverName;

  factory SchoolTrip.fromMap(String id, Map<String, dynamic> data) {
    return SchoolTrip(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      routeId: data['routeId'] as String? ?? '',
      busId: data['busId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      status: _statusFromValue(data['status']) ?? TripStatus.scheduled,
      scheduledAt: _asDateTime(data['scheduledAt']) ?? DateTime.now(),
      direction: TripDirection.fromValue(data['direction']),
      routeName: data['routeName'] as String? ?? '',
      busName: data['busName'] as String? ?? '',
      busPlateNumber: data['busPlateNumber'] as String? ?? '',
      driverName: data['driverName'] as String? ?? '',
      startedAt: _asDateTime(data['startedAt']),
      completedAt: _asDateTime(data['completedAt']),
      pausedAt: _asDateTime(data['pausedAt']),
      resumedAt: _asDateTime(data['resumedAt']),
      cancelledAt: _asDateTime(data['cancelledAt']),
      cancelReason: data['cancelReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'routeId': routeId,
      'routeName': routeName,
      'busId': busId,
      'busName': busName,
      'busPlateNumber': busPlateNumber,
      'driverId': driverId,
      'driverName': driverName,
      'status': status.name,
      'direction': direction.value,
    };
  }

  static TripStatus? _statusFromValue(Object? value) {
    if (value is! String) return null;
    for (final status in TripStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }

  /// Accepts a [DateTime] directly, or anything exposing a Firestore-style
  /// `toDate()` method (i.e. a `Timestamp`), without this package taking a
  /// hard dependency on `cloud_firestore` — school_shared stays
  /// framework-agnostic, matching AuthRepository's design intent.
  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue.toDate();
      return result is DateTime ? result : null;
    } catch (_) {
      return null;
    }
  }
}
