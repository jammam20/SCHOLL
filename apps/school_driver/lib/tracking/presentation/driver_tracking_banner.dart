import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

import '../../features/trips/domain/trip_operation_exception.dart';
import '../domain/driver_tracking_status.dart';

/// Localizes the one trip-action error this production-hardening pass adds
/// (bus capacity) without retrofitting l10n onto the app's whole pre-
/// existing, English-only `TripOperationException.message` convention —
/// see `TripsLoaded.actionErrorCode`'s own doc comment. Returns `null` for
/// every other code, so a call site falls back to the plain-English
/// `actionError` exactly as it always has.
String? tripOperationErrorMessage(TripOperationError? code, BuildContext context) =>
    switch (code) {
      TripOperationError.busCapacityExceeded => const S(
        'Bus capacity reached.',
        'تم الوصول للسعة القصوى للأتوبيس.',
      ).of(context),
      _ => null,
    };

/// How to present one [DriverTrackingStatus] transition to the driver —
/// Production hardening: GPS failure handling, requirement D ("the driver
/// UI must clearly communicate important failures") and E/F (never claim
/// success unless it actually happened). Returns `null` for the states that
/// should stay silent: `starting`/`stopped` are routine, and `tracking`
/// itself is deliberately never announced (requirement E — there is no
/// "tracking started successfully" toast, only ever a failure or a
/// recovery-from-failure).
({String message, DriverTrackingTone tone})? driverTrackingStatusPresentation(
  DriverTrackingStatus status,
  BuildContext context,
) => switch (status) {
  DriverTrackingStatus.permissionDenied => (
    message: const S(
      'Location permission is required to share your live location.',
      'محتاجين إذن الموقع عشان نقدر نشارك موقعك الحي.',
    ).of(context),
    tone: DriverTrackingTone.error,
  ),
  DriverTrackingStatus.permissionPermanentlyDenied => (
    message: const S(
      'Location permission is required. Enable it from your device settings.',
      'محتاجين إذن الموقع. فعّله من إعدادات الجهاز.',
    ).of(context),
    tone: DriverTrackingTone.error,
  ),
  DriverTrackingStatus.locationServiceDisabled => (
    message: const S(
      'Location services are disabled on this device.',
      'خدمة الموقع متوقفة على الجهاز ده.',
    ).of(context),
    tone: DriverTrackingTone.error,
  ),
  DriverTrackingStatus.gpsError => (
    message: const S('GPS signal lost.', 'إشارة تحديد الموقع اتقطعت.').of(context),
    tone: DriverTrackingTone.error,
  ),
  DriverTrackingStatus.staleLocation => (
    message: const S(
      "Your location hasn't updated in a while — check your GPS signal.",
      'موقعك مش بيتحدث من شوية — راجع إشارة تحديد الموقع.',
    ).of(context),
    tone: DriverTrackingTone.warning,
  ),
  DriverTrackingStatus.networkError => (
    message: const S(
      'Connection lost — reconnecting…',
      'الاتصال انقطع — جاري إعادة الاتصال…',
    ).of(context),
    tone: DriverTrackingTone.warning,
  ),
  DriverTrackingStatus.reconnecting => (
    message: const S(
      'Connection lost — reconnecting…',
      'الاتصال انقطع — جاري إعادة الاتصال…',
    ).of(context),
    tone: DriverTrackingTone.warning,
  ),
  DriverTrackingStatus.firebaseWriteError => (
    message: const S(
      "Couldn't update your location — retrying…",
      'تعذر تحديث موقعك — جاري المحاولة تاني…',
    ).of(context),
    tone: DriverTrackingTone.warning,
  ),
  DriverTrackingStatus.recovered => (
    message: const S('Location updates recovered.', 'رجعت تحديثات الموقع تاني.').of(context),
    tone: DriverTrackingTone.success,
  ),
  DriverTrackingStatus.tracking ||
  DriverTrackingStatus.starting ||
  DriverTrackingStatus.stopped => null,
};

/// Maps directly onto `AppSnackbar`'s per-outcome static methods
/// (success/error/warning) — kept as its own tiny enum rather than a direct
/// `void Function(BuildContext, String)` so a widget test can assert on
/// *which* tone was chosen without needing to mock `ScaffoldMessenger`.
enum DriverTrackingTone { success, error, warning }
