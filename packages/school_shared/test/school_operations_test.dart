import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  group('School.isHoliday — school calendar', () {
    School schoolWith({List<int> weekly = const [], List<String> special = const []}) {
      return School(
        id: 's1',
        name: 'Test School',
        code: 'T1',
        isActive: true,
        weeklyHolidays: weekly,
        specialHolidays: special,
      );
    }

    test('flags a configured weekly holiday', () {
      final school = schoolWith(weekly: [DateTime.friday, DateTime.saturday]);
      expect(school.isHoliday(DateTime(2026, 9, 4)), isTrue); // Friday
      expect(school.isHoliday(DateTime(2026, 9, 5)), isTrue); // Saturday
      expect(school.isHoliday(DateTime(2026, 9, 6)), isFalse); // Sunday
    });

    test('flags a special one-off date regardless of weekday', () {
      final school = schoolWith(special: ['2026-12-25']);
      expect(school.isHoliday(DateTime(2026, 12, 25)), isTrue);
      expect(school.isHoliday(DateTime(2026, 12, 26)), isFalse);
    });

    test('a school with no calendar configured has no holidays', () {
      final school = schoolWith();
      for (var day = 1; day <= 7; day++) {
        expect(school.isHoliday(DateTime(2026, 9, day)), isFalse);
      }
    });

    test('School.fromMap parses weeklyHolidays/specialHolidays back out', () {
      final school = School.fromMap('s1', {
        'name': 'Test',
        'code': 'T1',
        'isActive': true,
        'weeklyHolidays': [5, 6],
        'specialHolidays': ['2026-01-01'],
      });
      expect(school.weeklyHolidays, [5, 6]);
      expect(school.specialHolidays, ['2026-01-01']);
      expect(school.isHoliday(DateTime(2026, 1, 1)), isTrue);
    });
  });

  group('TripDirection — two daily trips', () {
    test('round-trips through its stored string value', () {
      expect(TripDirection.outbound.value, 'outbound');
      expect(TripDirection.returnTrip.value, 'return');
      expect(TripDirection.fromValue('outbound'), TripDirection.outbound);
      expect(TripDirection.fromValue('return'), TripDirection.returnTrip);
    });

    test('an unrecognized or missing value defaults to outbound', () {
      expect(TripDirection.fromValue(null), TripDirection.outbound);
      expect(TripDirection.fromValue('nonsense'), TripDirection.outbound);
    });

    test('SchoolTrip.fromMap defaults direction to outbound for pre-existing trips', () {
      final trip = SchoolTrip.fromMap('t1', {
        'schoolId': 's1',
        'routeId': 'r1',
        'busId': 'b1',
        'driverId': 'd1',
        'status': 'scheduled',
        // No 'direction' key at all — an old trip document.
      });
      expect(trip.direction, TripDirection.outbound);
    });

    test('SchoolTrip.fromMap/toMap round-trip a return trip', () {
      final trip = SchoolTrip.fromMap('t1', {
        'schoolId': 's1',
        'routeId': 'r1',
        'busId': 'b1',
        'driverId': 'd1',
        'status': 'scheduled',
        'direction': 'return',
      });
      expect(trip.direction, TripDirection.returnTrip);
      expect(trip.toMap()['direction'], 'return');
    });
  });

  group('AttendanceRecord — absence data integrity', () {
    test('idFor is deterministic per student+day, not a fresh id each call', () {
      final id1 = AttendanceRecord.idFor(studentId: 'stu1', date: '2026-09-01');
      final id2 = AttendanceRecord.idFor(studentId: 'stu1', date: '2026-09-01');
      expect(id1, id2);
      expect(id1, 'stu1_2026-09-01');
    });

    test('a second write for the same student+day would overwrite (upsert), not append', () {
      // This is the actual fix for the double-counting bug: two writers
      // (or one writer toggling twice) computing the same id means a
      // Firestore .set(..., merge:true) call updates one document instead
      // of creating a second one.
      final morning = AttendanceRecord.idFor(studentId: 'stu1', date: '2026-09-01');
      final laterSameDay = AttendanceRecord.idFor(studentId: 'stu1', date: '2026-09-01');
      final differentDay = AttendanceRecord.idFor(studentId: 'stu1', date: '2026-09-02');
      expect(morning, laterSameDay);
      expect(morning, isNot(differentDay));
    });

    test('toMap/fromMap round-trip preserves isAbsent and studentName', () {
      const record = AttendanceRecord(
        studentId: 'stu1',
        schoolId: 's1',
        date: '2026-09-01',
        isAbsent: true,
        updatedBy: 'parent-uid',
        studentName: 'Omar',
      );
      final restored = AttendanceRecord.fromMap(record.toMap());
      expect(restored.studentId, 'stu1');
      expect(restored.isAbsent, isTrue);
      expect(restored.studentName, 'Omar');
    });
  });

  group('localTimeToUtcMinutes / utcMinutesToLocalTime — trip-start-window '
      'and absence-cutoff schedule storage', () {
    test('round-trips an arbitrary local time back to the same hour/minute', () {
      for (final time in [(0, 0), (7, 0), (12, 30), (23, 59), (6, 45)]) {
        final (hour, minute) = time;
        final utcMinutes = localTimeToUtcMinutes(hour, minute);
        final (restoredHour, restoredMinute) = utcMinutesToLocalTime(utcMinutes);
        expect(
          restoredHour,
          hour,
          reason: 'hour should round-trip for $hour:$minute',
        );
        expect(
          restoredMinute,
          minute,
          reason: 'minute should round-trip for $hour:$minute',
        );
      }
    });

    test('produces a value within a single day (0-1439 minutes)', () {
      final utcMinutes = localTimeToUtcMinutes(7, 0);
      expect(utcMinutes, inInclusiveRange(0, 1439));
    });
  });
}
