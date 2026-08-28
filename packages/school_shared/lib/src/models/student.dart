import '../utils/dates.dart';

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

  // False while a student a parent added themselves is awaiting admin
  // approval (see StudentsRepository.addChild in the parent app). Always
  // true for students an admin added directly.
  final bool approved;

  // The 'yyyy-MM-dd' date this student is marked absent, set by a parent
  // from the child settings screen — null means not absent. Self-expiring
  // by comparing against today's date rather than needing a daily reset:
  // see isAbsentOn in the parent/driver apps.
  final String? absentOn;

  bool get hasLocation => latitude != null && longitude != null;

  bool get isAbsentToday => absentOn != null && absentOn == todayIsoDate();

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
    );
  }
}