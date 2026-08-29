import 'package:firebase_analytics/firebase_analytics.dart';

/// Product analytics for the driver app — event names and parameters only
/// ever carry opaque Firestore document ids and enum-like strings, never a
/// name, phone number, address, or raw GPS coordinate.
class AppAnalytics {
  AppAnalytics._();

  static final _analytics = FirebaseAnalytics.instance;

  static Future<void> logLoginSuccess() => _analytics.logLogin();

  static Future<void> logTripStarted({required String tripId}) =>
      _analytics.logEvent(name: 'trip_started', parameters: {'trip_id': tripId});

  static Future<void> logTripCompleted({required String tripId}) => _analytics
      .logEvent(name: 'trip_completed', parameters: {'trip_id': tripId});

  static Future<void> logStudentBoarded({required String tripId}) => _analytics
      .logEvent(name: 'student_boarded', parameters: {'trip_id': tripId});

  static Future<void> logStudentDroppedOff({required String tripId}) =>
      _analytics.logEvent(
        name: 'student_dropped_off',
        parameters: {'trip_id': tripId},
      );

  static Future<void> logEmergencyCreated({
    required String tripId,
    required String emergencyType,
  }) => _analytics.logEvent(
    name: 'emergency_created',
    parameters: {'trip_id': tripId, 'emergency_type': emergencyType},
  );

  static Future<void> logEmergencyResolved({required String tripId}) => _analytics
      .logEvent(name: 'emergency_resolved', parameters: {'trip_id': tripId});

  static Future<void> logNotificationOpened({required String type}) => _analytics
      .logEvent(name: 'notification_opened', parameters: {'type': type});
}
