/// Who put an [AttendanceRecord] into its current state.
///
/// The distinction matters to the person reading it, not just to auditing:
/// a parent declaring "not riding today" in advance and a driver observing
/// "wasn't at the stop just now" are different facts with different
/// urgency, and the parent app renders them differently. Both still settle
/// into the same canonical record so reporting counts one absence, not two.
enum AttendanceSource {
  /// A parent declared the absence for their own child, usually ahead of
  /// the trip. The bus skips the stop.
  parent,

  /// The driver reached the stop and the student wasn't there. This is an
  /// observation, not a decision — it never edits the student's own record
  /// (see StudentsRepository.reportAbsence in the driver app).
  driver,

  /// A school admin set it on the student's behalf.
  school;

  String get value => name;

  static AttendanceSource fromValue(Object? value) => switch (value) {
    'driver' => AttendanceSource.driver,
    'school' => AttendanceSource.school,
    _ => AttendanceSource.parent,
  };
}

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
    this.source = AttendanceSource.parent,
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

  /// Which side put this record in its current state.
  ///
  /// `updatedBy` already carries *who*, but only as a uid — a parent
  /// reading their own child's record can't resolve that to a role, and
  /// firestore.rules deliberately won't let them read the driver's user
  /// document to find out. Storing the role alongside it is what lets the
  /// parent app tell "I marked my child absent" apart from "the driver
  /// reached the stop and my child wasn't there", which are very
  /// different things to see on a phone at 7am.
  final AttendanceSource source;

  /// True when this record exists because a driver reported a no-show,
  /// rather than because a parent or the school declared the absence.
  bool get isDriverNoShow => isAbsent && source == AttendanceSource.driver;

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
      // Records written before this field existed came from the parent or
      // school flows, which is what the default resolves to.
      source: AttendanceSource.fromValue(data['source']),
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'schoolId': schoolId,
    'date': date,
    'isAbsent': isAbsent,
    'updatedBy': updatedBy,
    'studentName': studentName,
    'source': source.value,
  };
}
