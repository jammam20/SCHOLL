import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

import '../../features/trips/domain/trip_operation_exception.dart';
import '../domain/driver_tracking_status.dart';

/// The driver-facing text for a failed trip action, in the app's language.
///
/// Every `TripOperationError` is covered. It used to translate only
/// `busCapacityExceeded` and return null for the rest, which meant each
/// call site silently fell through to the raw English
/// `TripOperationException.message` thrown by the repositories — so a
/// driver running the app in Arabic still got "This trip could not be
/// found." Returning a non-null string for every code is what closes that.
///
/// Kept as the single mapping point rather than translating the throw
/// sites: the repositories throw from inside Firestore transactions and
/// have no BuildContext, so the code travels up as a typed enum and only
/// becomes words here.
String tripOperationErrorMessage(
  TripOperationError code,
  BuildContext context,
) => switch (code) {
  TripOperationError.busCapacityExceeded => const S(
    'Bus capacity reached.',
    'تم الوصول للسعة القصوى للأتوبيس.',
    fr: "Capacité du bus atteinte.",
    es: 'Se alcanzó la capacidad del autobús.',
  ).of(context),
  TripOperationError.unauthorized => const S(
    'You are not the driver assigned to this trip.',
    'إنت مش السواق المكلف بالرحلة دي.',
    fr: "Vous n'êtes pas le chauffeur affecté à ce trajet.",
    es: 'No eres el conductor asignado a este viaje.',
  ).of(context),
  TripOperationError.tripNotFound => const S(
    'This trip could not be found.',
    'الرحلة دي مش موجودة.',
    fr: 'Ce trajet est introuvable.',
    es: 'No se encontró este viaje.',
  ).of(context),
  TripOperationError.studentNotOnTrip => const S(
    "This student isn't on this trip's stop order.",
    'الطالب ده مش ضمن محطات الرحلة دي.',
    fr: "Cet élève ne figure pas dans les arrêts de ce trajet.",
    es: 'Este alumno no está en las paradas de este viaje.',
  ).of(context),
  TripOperationError.studentAbsent => const S(
    'This student is marked absent today and cannot be boarded.',
    'الطالب ده مسجل غايب النهاردة ومينفعش يركب.',
    fr: "Cet élève est noté absent aujourd'hui et ne peut pas monter.",
    es: 'Este alumno está marcado como ausente hoy y no puede subir.',
  ).of(context),
  TripOperationError.studentNotBoarded => const S(
    "This student hasn't been picked up on this trip yet.",
    'الطالب ده لسه ما اتحملش في الرحلة دي.',
    fr: "Cet élève n'a pas encore été pris en charge sur ce trajet.",
    es: 'Este alumno aún no ha sido recogido en este viaje.',
  ).of(context),
  TripOperationError.tripNotActive => const S(
    'This can only be done while the trip is active.',
    'ده ينفع بس والرحلة شغالة.',
    fr: 'Possible uniquement pendant que le trajet est en cours.',
    es: 'Esto solo se puede hacer mientras el viaje está en curso.',
  ).of(context),
  TripOperationError.invalidTransition => const S(
    "This trip can't move to that status from where it is now.",
    'الرحلة مينفعش تتنقل للحالة دي من وضعها الحالي.',
    fr: "Ce trajet ne peut pas passer à ce statut depuis son état actuel.",
    es: 'Este viaje no puede pasar a ese estado desde su estado actual.',
  ).of(context),
  TripOperationError.invalidStopOrder => const S(
    "That order doesn't match who's actually on this trip.",
    'الترتيب ده مش مطابق للطلاب اللي فعلاً في الرحلة.',
    fr: "Cet ordre ne correspond pas aux élèves réellement sur ce trajet.",
    es: 'Ese orden no coincide con quiénes van realmente en este viaje.',
  ).of(context),
  TripOperationError.emergencyAlreadyActive => const S(
    'An active emergency already exists for this trip.',
    'في حالة طوارئ نشطة بالفعل للرحلة دي.',
    fr: "Une urgence est déjà en cours pour ce trajet.",
    es: 'Ya existe una emergencia activa para este viaje.',
  ).of(context),
  TripOperationError.emergencyNotFound => const S(
    'This emergency could not be found.',
    'حالة الطوارئ دي مش موجودة.',
    fr: 'Cette urgence est introuvable.',
    es: 'No se encontró esta emergencia.',
  ).of(context),
  TripOperationError.emergencyAlreadyResolved => const S(
    'This emergency has already been resolved.',
    'حالة الطوارئ دي اتقفلت خلاص.',
    fr: 'Cette urgence a déjà été résolue.',
    es: 'Esta emergencia ya fue resuelta.',
  ).of(context),
  TripOperationError.locationUnavailable => const S(
    'Your current location is unavailable.',
    'موقعك الحالي مش متاح.',
    fr: 'Votre position actuelle est indisponible.',
    es: 'Tu ubicación actual no está disponible.',
  ).of(context),
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
      fr: "L'autorisation de localisation est nécessaire pour partager votre position en direct.",
      es: 'Se necesita permiso de ubicación para compartir tu ubicación en directo.',
    ).of(context),
    tone: DriverTrackingTone.error,
  ),
  DriverTrackingStatus.permissionPermanentlyDenied => (
    message: const S(
      'Location permission is required. Enable it from your device settings.',
      'محتاجين إذن الموقع. فعّله من إعدادات الجهاز.',
      fr: "L'autorisation de localisation est nécessaire. Activez-la dans les réglages de votre appareil.",
      es: 'Se necesita permiso de ubicación. Actívalo en los ajustes de tu dispositivo.',
    ).of(context),
    tone: DriverTrackingTone.error,
  ),
  DriverTrackingStatus.locationServiceDisabled => (
    message: const S(
      'Location services are disabled on this device.',
      'خدمة الموقع متوقفة على الجهاز ده.',
      fr: 'La localisation est désactivée sur cet appareil.',
      es: 'La ubicación está desactivada en este dispositivo.',
    ).of(context),
    tone: DriverTrackingTone.error,
  ),
  DriverTrackingStatus.gpsError => (
    message: const S(
      'GPS signal lost.',
      'إشارة تحديد الموقع اتقطعت.',
      fr: 'Signal GPS perdu.',
      es: 'Señal GPS perdida.',
    ).of(context),
    tone: DriverTrackingTone.error,
  ),
  DriverTrackingStatus.staleLocation => (
    message: const S(
      "Your location hasn't updated in a while — check your GPS signal.",
      'موقعك مش بيتحدث من شوية — راجع إشارة تحديد الموقع.',
      fr: "Votre position n'a pas été actualisée depuis un moment — vérifiez votre signal GPS.",
      es: 'Tu ubicación no se actualiza desde hace un rato — revisa la señal GPS.',
    ).of(context),
    tone: DriverTrackingTone.warning,
  ),
  DriverTrackingStatus.networkError => (
    message: const S(
      'Connection lost — reconnecting…',
      'الاتصال انقطع — جاري إعادة الاتصال…',
      fr: 'Connexion perdue — reconnexion…',
      es: 'Conexión perdida — reconectando…',
    ).of(context),
    tone: DriverTrackingTone.warning,
  ),
  DriverTrackingStatus.reconnecting => (
    message: const S(
      'Connection lost — reconnecting…',
      'الاتصال انقطع — جاري إعادة الاتصال…',
      fr: 'Connexion perdue — reconnexion…',
      es: 'Conexión perdida — reconectando…',
    ).of(context),
    tone: DriverTrackingTone.warning,
  ),
  DriverTrackingStatus.firebaseWriteError => (
    message: const S(
      "Couldn't update your location — retrying…",
      'تعذر تحديث موقعك — جاري المحاولة تاني…',
      fr: "Impossible d'actualiser votre position — nouvelle tentative…",
      es: 'No se pudo actualizar tu ubicación — reintentando…',
    ).of(context),
    tone: DriverTrackingTone.warning,
  ),
  DriverTrackingStatus.recovered => (
    message: const S(
      'Location updates recovered.',
      'رجعت تحديثات الموقع تاني.',
      fr: 'Les mises à jour de position ont repris.',
      es: 'Se restablecieron las actualizaciones de ubicación.',
    ).of(context),
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
