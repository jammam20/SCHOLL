import 'package:firebase_analytics/firebase_analytics.dart';

/// Product analytics for the parent app — event names and parameters only
/// ever carry opaque Firestore document ids and enum-like strings, never a
/// name, phone number, address, or raw GPS coordinate.
class AppAnalytics {
  AppAnalytics._();

  static final _analytics = FirebaseAnalytics.instance;

  static Future<void> logLoginSuccess() => _analytics.logLogin();

  static Future<void> logChildAdded() => _analytics.logEvent(name: 'child_added');

  static Future<void> logTrackingOpened({required String tripId}) => _analytics
      .logEvent(name: 'tracking_opened', parameters: {'trip_id': tripId});

  static Future<void> logNotificationOpened({required String type}) => _analytics
      .logEvent(name: 'notification_opened', parameters: {'type': type});
}
