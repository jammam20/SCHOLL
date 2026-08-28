import 'package:flutter/foundation.dart';

/// Set when the driver taps a push notification (in foreground, or the app
/// was launched from terminated by tapping one) — holds the notification's
/// `type` data field (see functions/src/index.ts: sendPushNotification's
/// `data` payload) so the home page can react by switching to the right
/// tab. Cleared once consumed, so it isn't re-applied on a later rebuild.
class NotificationRouting {
  NotificationRouting._();

  static final ValueNotifier<String?> pendingTarget = ValueNotifier(null);
}
