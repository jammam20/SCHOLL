import '../utils/dates.dart';

class School {
  const School({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.tripStartWindowMinutes,
    this.absenceCutoffMinutes,
    this.weeklyHolidays = const [],
    this.specialHolidays = const [],
  });

  final String id;
  final String name;
  final String code;
  final bool isActive;

  // The school's own location — every trip's fixed final stop. Writable
  // only through the updateSchoolLocation callable (firestore.rules
  // restricts direct writes on `schools/{id}` to system admins).
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  // How many minutes before a trip's scheduledAt a driver is allowed to
  // start it (Feature: driver trip start window). Null means "not
  // configured" — firestore.rules treats that as no restriction, so an
  // existing school that never sets this keeps behaving exactly as before.
  final int? tripStartWindowMinutes;

  // How many minutes before a trip's scheduled time a parent may still
  // mark their child absent for that trip (Feature: absence cutoff). Null
  // means no cutoff is enforced.
  final int? absenceCutoffMinutes;

  // Recurring weekly holidays, as DateTime.weekday values (1 = Monday ...
  // 7 = Sunday) — e.g. [5, 6] for Friday+Saturday. Used to skip generating
  // trips on those days (Feature: school calendar).
  final List<int> weeklyHolidays;

  // One-off holiday dates, `'yyyy-MM-dd'`, in addition to the weekly
  // pattern above (Feature: school calendar).
  final List<String> specialHolidays;

  factory School.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return School(
      id: id,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      isActive: data['isActive'] == true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      tripStartWindowMinutes: (data['tripStartWindowMinutes'] as num?)?.toInt(),
      absenceCutoffMinutes: (data['absenceCutoffMinutes'] as num?)?.toInt(),
      weeklyHolidays: (data['weeklyHolidays'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      specialHolidays: (data['specialHolidays'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Whether [date] falls on a configured weekly or special holiday.
  bool isHoliday(DateTime date) {
    if (weeklyHolidays.contains(date.weekday)) return true;
    return specialHolidays.contains(isoDateOnly(date));
  }
}
