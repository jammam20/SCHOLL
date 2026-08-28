import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this device for push notifications once signed in, and keeps
/// the registration fresh across token rotations. Notification *sending* is
/// handled server-side (see functions/src/index.ts: onTripStatusChanged,
/// onDriverLocationWritten) — this is just the client-side registration
/// half, mirrored in every app (school_admin, school_driver, school_parent).
class PushNotificationsRepository {
  PushNotificationsRepository({
    FirebaseMessaging? messaging,
    FirebaseFunctions? functions,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFunctions _functions;

  bool _registered = false;

  Future<void> register() async {
    if (_registered) return;
    _registered = true;

    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await _sendToken(token);
    }
    _messaging.onTokenRefresh.listen(_sendToken);
  }

  Future<void> _sendToken(String token) async {
    try {
      await _functions.httpsCallable('registerFcmToken').call<void>({
        'token': token,
      });
    } catch (_) {
      // Best-effort: a failed registration just means this device won't
      // receive push notifications until the next successful attempt (next
      // sign-in, or the next token refresh).
    }
  }
}
