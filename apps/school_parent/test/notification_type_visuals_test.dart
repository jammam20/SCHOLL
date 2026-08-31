import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_parent/features/notifications/presentation/notification_type_visuals.dart';
import 'package:school_shared/school_shared.dart';

/// The notification inbox renders whatever the Cloud Functions wrote, and the
/// event types are a server contract rather than a design decision — see
/// `writeNotificationRecords` in `functions/src/index.ts`. These tests exist
/// so a type added on the server can't quietly render as an unlabelled,
/// tone-less row in a parent's inbox: adding one there without giving it a
/// presentation here fails the first test below.
void main() {
  group('notification type visuals', () {
    test('every server-written type has its own icon, tone and label', () {
      final fallbackIcon = notificationTypeIcon('__unknown__');
      final fallbackLabel = notificationTypeLabel('__unknown__');

      for (final type in kServerNotificationTypes) {
        expect(
          notificationTypeIcon(type),
          isNot(fallbackIcon),
          reason: '$type falls through to the generic bell icon',
        );
        expect(
          notificationTypeTone(type),
          isNot(StatusTone.neutral),
          reason: '$type has no severity of its own',
        );
        expect(
          notificationTypeLabel(type).en,
          isNot(fallbackLabel.en),
          reason: '$type has no English label of its own',
        );
        expect(
          notificationTypeLabel(type).ar,
          isNot(fallbackLabel.ar),
          reason: '$type has no Arabic label of its own',
        );
      }
    });

    test('an emergency is the only type rendered at emergency severity', () {
      final emergencyTypes = kServerNotificationTypes.where(
        (type) => notificationTypeTone(type) == StatusTone.emergency,
      );
      expect(emergencyTypes, ['emergency']);
    });

    test('boarding and drop-off read as reassuring, not alarming', () {
      expect(notificationTypeTone('student_boarded'), StatusTone.success);
      expect(notificationTypeTone('student_dropped_off'), StatusTone.success);
    });

    test('a bus change and a route deviation read as cautions', () {
      expect(notificationTypeTone('bus_changed'), StatusTone.warning);
      expect(notificationTypeTone('route_deviation'), StatusTone.warning);
    });

    test('an unknown type still renders rather than disappearing', () {
      // A parent was pushed this notification; an app older than the server
      // that wrote it must still show the row, just without a specific tone.
      expect(notificationTypeIcon('a_type_added_later'), isA<IconData>());
      expect(notificationTypeTone('a_type_added_later'), StatusTone.neutral);
      expect(notificationTypeLabel('a_type_added_later').en, isNotEmpty);
      expect(notificationTypeLabel('a_type_added_later').ar, isNotEmpty);
    });

    test('every type is labelled in both languages', () {
      for (final type in kServerNotificationTypes) {
        final label = notificationTypeLabel(type);
        expect(label.en, isNotEmpty, reason: '$type has no English label');
        expect(label.ar, isNotEmpty, reason: '$type has no Arabic label');
        expect(
          label.ar,
          isNot(label.en),
          reason: '$type is not actually translated',
        );
      }
    });
  });
}
