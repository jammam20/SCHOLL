import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/notifications/data/push_notifications_repository.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../firebase_options.dart';
import 'analytics.dart';
import 'app_settings.dart';
import 'language_sync.dart';
import 'notification_routing.dart';
import 'theme.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Must be a top-level (or static) function — the plugin runs it on a
/// separate isolate when a data/notification message arrives while the app
/// is fully backgrounded or terminated. There's nothing to route here (no
/// UI exists in that isolate); this exists so a data-only message isn't
/// silently dropped and so the OS still shows its own notification for one
/// that also carries a `notification` payload (which every message this app
/// sends does — see functions/src/index.ts).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  static Future<void> initializeFirebase() =>
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  /// Shows a snackbar for push notifications that arrive while the app is in
  /// the foreground (FCM only auto-displays a system notification when the
  /// app is backgrounded/terminated). Call once, after Firebase init.
  static void listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            [
              notification.title,
              notification.body,
            ].whereType<String>().join(' — '),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  /// Routes a tap on a notification (app was backgrounded, not terminated)
  /// to the right tab — see NotificationRouting.
  static void listenForNotificationTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);
  }

  /// The app was launched *by* tapping a notification (was fully
  /// terminated) — checked once at startup, after Firebase init.
  static Future<void> handleInitialNotification() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) _routeFromMessage(message);
  }

  static void _routeFromMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == null) return;
    NotificationRouting.pendingTarget.value = type;
    AppAnalytics.logNotificationOpened(type: type);
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AuthCubit(FirebaseAuthRepository())..start(),
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, themeMode, _) => ValueListenableBuilder<Locale>(
        valueListenable: AppSettings.locale,
        builder: (context, locale, _) => MaterialApp(
          scaffoldMessengerKey: _scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Jammam School Operations',
          supportedLocales: supportedLocales,
          locale: locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: themeMode,
          theme: buildAppTheme(
            brand: AppBrand.admin,
            brightness: Brightness.light,
            locale: locale,
          ),
          darkTheme: buildAppTheme(
            brand: AppBrand.admin,
            brightness: Brightness.dark,
            locale: locale,
          ),
          home: OnboardingGate(
            child: BlocListener<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthSignedIn) {
                  PushNotificationsRepository().register();
                  // Carries a language chosen on the login or onboarding screen —
                  // where there was no uid to attach it to — up to the server, so
                  // push notifications arrive in it.
                  LanguageSync.syncCurrent();
                }
              },
              child: const LoginPage(),
            ),
          ),
        ),
      ),
    ),
  );
}
