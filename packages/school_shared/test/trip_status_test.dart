import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  group('TripStatus.canTransitionTo', () {
    test('scheduled can start or be cancelled', () {
      expect(TripStatus.scheduled.canTransitionTo(TripStatus.starting), isTrue);
      expect(TripStatus.scheduled.canTransitionTo(TripStatus.cancelled), isTrue);
    });

    test('scheduled cannot jump straight to active or completed', () {
      expect(TripStatus.scheduled.canTransitionTo(TripStatus.active), isFalse);
      expect(TripStatus.scheduled.canTransitionTo(TripStatus.completed), isFalse);
    });

    test('starting can only become active or cancelled', () {
      expect(TripStatus.starting.canTransitionTo(TripStatus.active), isTrue);
      expect(TripStatus.starting.canTransitionTo(TripStatus.cancelled), isTrue);
      expect(TripStatus.starting.canTransitionTo(TripStatus.paused), isFalse);
    });

    test('active can pause, complete, or raise an emergency', () {
      expect(TripStatus.active.canTransitionTo(TripStatus.paused), isTrue);
      expect(TripStatus.active.canTransitionTo(TripStatus.completed), isTrue);
      expect(TripStatus.active.canTransitionTo(TripStatus.emergency), isTrue);
    });

    test('cannot complete a trip that has not started', () {
      expect(TripStatus.scheduled.canTransitionTo(TripStatus.completed), isFalse);
      expect(TripStatus.starting.canTransitionTo(TripStatus.completed), isFalse);
    });

    test('cannot resume (go active) a trip that is not paused', () {
      expect(TripStatus.scheduled.canTransitionTo(TripStatus.active), isFalse);
      expect(TripStatus.completed.canTransitionTo(TripStatus.active), isFalse);
    });

    test('paused can resume, be cancelled, or escalate to emergency', () {
      expect(TripStatus.paused.canTransitionTo(TripStatus.active), isTrue);
      expect(TripStatus.paused.canTransitionTo(TripStatus.cancelled), isTrue);
      expect(TripStatus.paused.canTransitionTo(TripStatus.emergency), isTrue);
    });

    test('emergency can only resolve to completed or cancelled', () {
      expect(TripStatus.emergency.canTransitionTo(TripStatus.completed), isTrue);
      expect(TripStatus.emergency.canTransitionTo(TripStatus.cancelled), isTrue);
      expect(TripStatus.emergency.canTransitionTo(TripStatus.active), isFalse);
    });

    test('a completed trip cannot transition anywhere, including restarting', () {
      for (final next in TripStatus.values) {
        expect(TripStatus.completed.canTransitionTo(next), isFalse);
      }
    });

    test('a cancelled trip cannot transition anywhere, including restarting', () {
      for (final next in TripStatus.values) {
        expect(TripStatus.cancelled.canTransitionTo(next), isFalse);
      }
    });
  });
}
