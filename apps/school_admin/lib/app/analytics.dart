import 'package:firebase_analytics/firebase_analytics.dart';

/// Product analytics for the admin app — event names and parameters only
/// ever carry opaque Firestore document ids and enum-like strings, never a
/// name, phone number, address, or raw GPS coordinate.
class AppAnalytics {
  AppAnalytics._();

  static final _analytics = FirebaseAnalytics.instance;

  static Future<void> logLoginSuccess() => _analytics.logLogin();

  static Future<void> logEmergencyResolved({required String tripId}) => _analytics
      .logEvent(name: 'emergency_resolved', parameters: {'trip_id': tripId});

  static Future<void> logNotificationOpened({required String type}) => _analytics
      .logEvent(name: 'notification_opened', parameters: {'type': type});
}
