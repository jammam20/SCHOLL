import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ParentApp.initializeFirebase();

  // Crashlytics has no web implementation — only wire it up on
  // Android/iOS, where a crash actually needs reporting somewhere.
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Background/terminated-state message handling has no web implementation
  // via this API either.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  ParentApp.listenForForegroundMessages();
  ParentApp.listenForNotificationTaps();
  await ParentApp.handleInitialNotification();
  runApp(const ParentApp());
}
