import '../utils/dates.dart';
import 'pickup_verification.dart';

class Student {
  const Student({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.isActive,
    this.parentIds = const [],
    this.routeId,
    this.latitude,
    this.longitude,
    this.approved = true,
    this.absentOn,
    this.scheduledAbsenceDates = const [],
    this.pickupPointId,
    this.authorizedPickupPersons = const [],
  });

  final String id;
  final String schoolId;
  final String name;
  final bool isActive;
  final List<String> parentIds;

  // Which route (and therefore which trips) this student rides. Set by an
  // admin from the Students tab; used by the parent app to find the trip
  // that corresponds to this student.
  final String? routeId;

  // The student's pickup point (door-to-door, not a shared bus stop — see
  // RouteStop, which is unused for this). Set by an admin from the Students
  // tab; used to build each trip's pickup order and to trigger
  // arrival/ETA notifications for this student's parents specifically.
  final double? latitude;
  final double? longitude;

  // Optional shared/safe pickup point (Feature: Smart Pickup Points) this
  // student is assigned to instead of (or in addition to) their exact
  // door-to-door coordinate above. Null means "uses latitude/longitude
  // directly", matching all existing behavior unchanged.
  final String? pickupPointId;

  // People a parent has pre-authorized to collect this student (Feature:
  // Secure Student Pickup). Empty by default — every existing student
  // continues to work exactly as before until a parent adds one.
  final List<AuthorizedPickupPerson> authorizedPickupPersons;

  // False while a student a parent added themselves is awaiting admin
  // approval (see StudentsRepository.addChild in the parent app). Always
  // true for students an admin added directly.
  final bool approved;

  // The 'yyyy-MM-dd' date this student is marked absent, set by a parent
  // from the child settings screen — null means not absent. Self-expiring
  // by comparing against today's date rather than needing a daily reset:
  // see isAbsentOn in the parent/driver apps.
  final String? absentOn;

  // Future (or today's) absence dates a parent has scheduled ahead of time
  // (Feature: Student Ridership — "mark my child absent on a future date"),
  // each a 'yyyy-MM-dd' string like [absentOn]. Kept as a separate field
  // rather than replacing [absentOn] so nothing reading the older
  // single-date field needs to change — [isAbsentToday]/[isAbsentOn] are
  // the single source of truth that already check both. A driver/admin
  // marking today absent still writes [absentOn]; a parent scheduling a
  // date ahead of time writes it into this list instead, and it's expected
  // to be pruned (a date removed once it's in the past) by whoever manages
  // the list — see StudentsRepository.setScheduledAbsences in the parent
  // app, which does that pruning on every write.
  final List<String> scheduledAbsenceDates;

  bool get hasLocation => latitude != null && longitude != null;

  bool get isAbsentToday => isAbsentOn(todayIsoDate());

  bool isAbsentOn(String isoDate) =>
      absentOn == isoDate || scheduledAbsenceDates.contains(isoDate);

  factory Student.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return Student(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      isActive: data['isActive'] == true,
      parentIds: List<String>.from(
        data['parentIds'] ?? const [],
      ),
      routeId: data['routeId'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      approved: data['approved'] != false,
      absentOn: data['absentOn'] as String?,
      scheduledAbsenceDates: List<String>.from(
        data['scheduledAbsenceDates'] ?? const [],
      ),
      pickupPointId: data['pickupPointId'] as String?,
      authorizedPickupPersons: (data['authorizedPickupPersons'] as List?)
              ?.map((e) => AuthorizedPickupPerson.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }
}
