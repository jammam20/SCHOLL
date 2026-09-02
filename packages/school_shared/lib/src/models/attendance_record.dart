/// The canonical, one-per-(student, school day) attendance state (Feature:
/// absence data integrity).
///
/// This is deliberately separate from `absenceLog`, which stays exactly
/// what it always was — an append-only, unconstrained event trail ("10:00
/// marked absent, 10:20 restored, 10:35 marked absent again"). Reporting
/// and analytics must ask "was this student absent on this day, in the
/// end" — a question `absenceLog.length` cannot answer once the same
/// student/day has been toggled more than once. This record answers that
/// exactly, because both writers (`students_repository.dart` in the parent
/// and driver apps) `set(..., merge: true)` the SAME document id
/// (`'${studentId}_${date}'`) instead of appending a new one, so a second
/// toggle overwrites the first rather than adding to a count.
class AttendanceRecord {
  const AttendanceRecord({
    required this.studentId,
    required this.schoolId,
    required this.date,
    required this.isAbsent,
    this.updatedBy,
    this.studentName = '',
  });

  final String studentId;
  final String schoolId;

  /// `'yyyy-MM-dd'`, matching `Student.absentOn`/`isoDateOnly`.
  final String date;
  final bool isAbsent;
  final String? updatedBy;

  // Denormalized at write time (both writers already have it in hand) so
  // admin reporting can group/display by name without a join per record —
  // the same reasoning `SchoolTrip` denormalizes routeName/busName/
  // driverName for.
  final String studentName;

  static String idFor({required String studentId, required String date}) =>
      '${studentId}_$date';

  factory AttendanceRecord.fromMap(Map<String, dynamic> data) {
    return AttendanceRecord(
      studentId: data['studentId'] as String? ?? '',
      schoolId: data['schoolId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      isAbsent: data['isAbsent'] == true,
      updatedBy: data['updatedBy'] as String?,
      studentName: data['studentName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'schoolId': schoolId,
    'date': date,
    'isAbsent': isAbsent,
    'updatedBy': updatedBy,
    'studentName': studentName,
  };
}
