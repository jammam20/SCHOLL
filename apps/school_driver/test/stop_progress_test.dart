import 'package:flutter_test/flutter_test.dart';
import 'package:school_driver/features/trips/domain/stop_progress.dart';

void main() {
  const schoolStopId = '__school__';
  const order = ['student-1', 'student-2', 'student-3', schoolStopId];

  test('nothing boarded yet: current stop is the first one, all else remaining', () {
    final progress = computeStopProgress(
      order: order,
      boardedStudents: {},
      schoolStopId: schoolStopId,
    );

    expect(progress.completedStopIds, isEmpty);
    expect(progress.currentStopId, 'student-1');
    expect(progress.nextStopId, 'student-2');
    expect(progress.remainingStopIds, order);
  });

  test('some boarded: completed/current/remaining reflect it correctly', () {
    final progress = computeStopProgress(
      order: order,
      boardedStudents: {'student-1', 'student-2'},
      schoolStopId: schoolStopId,
    );

    expect(progress.completedStopIds, ['student-1', 'student-2']);
    expect(progress.currentStopId, 'student-3');
    expect(progress.nextStopId, schoolStopId);
    expect(progress.remainingStopIds, ['student-3', schoolStopId]);
  });

  test('the school stop is never marked completed by boardedStudents alone', () {
    final progress = computeStopProgress(
      order: order,
      boardedStudents: {'student-1', 'student-2', 'student-3', schoolStopId},
      schoolStopId: schoolStopId,
    );

    // Even if something odd got into boardedStudents under the school's
    // sentinel id, the school stop itself only ever comes from the trip
    // being completed — not from this field.
    expect(progress.completedStopIds, ['student-1', 'student-2', 'student-3']);
    expect(progress.currentStopId, schoolStopId);
  });

  test('everything boarded except the school stop still leaves it current', () {
    final progress = computeStopProgress(
      order: order,
      boardedStudents: {'student-1', 'student-2', 'student-3'},
      schoolStopId: schoolStopId,
    );

    expect(progress.currentStopId, schoolStopId);
    expect(progress.nextStopId, isNull);
  });

  test('an empty order reports no current stop', () {
    final progress = computeStopProgress(
      order: const [],
      boardedStudents: const {},
      schoolStopId: schoolStopId,
    );

    expect(progress.currentStopId, isNull);
    expect(progress.completedStopIds, isEmpty);
    expect(progress.remainingStopIds, isEmpty);
  });
}
