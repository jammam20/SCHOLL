import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

/// Shared wording for everything the ETA engine can say, so the live map
/// and the home card never phrase the same result two different ways.
///
/// The point of surfacing [EtaUnavailableReason] at all: "ETA unavailable"
/// on its own reads like the app is broken. "Waiting for the bus to start
/// broadcasting" tells a parent that nothing is wrong and there's nothing
/// for them to do — which is true, and is the whole reason the shared
/// engine returns a reason instead of a bare null.
S etaUnavailableText(EtaUnavailableReason reason) => switch (reason) {
  EtaUnavailableReason.tripNotActive => const S(
    "The trip isn't running right now",
    'الرحلة مش شغالة دلوقتي',
    fr: "Le trajet n'est pas en cours en ce moment",
    es: 'El viaje no está en curso en este momento',
  ),
  EtaUnavailableReason.noGpsSignal => const S(
    'Waiting for the bus to send its location',
    'في انتظار الأتوبيس يبعت موقعه',
    fr: "En attente que le bus envoie sa position",
    es: 'Esperando a que el autobús envíe su ubicación',
  ),
  EtaUnavailableReason.staleGps => const S(
    "The bus's last location is too old to estimate from",
    'آخر موقع للأتوبيس قديم أوي عشان نحسب منه',
    fr:
        "La dernière position connue du bus est trop ancienne pour "
        'estimer',
    es:
        'La última ubicación conocida del autobús es demasiado antigua '
        'para calcular una estimación',
  ),
  EtaUnavailableReason.allStopsCompleted => const S(
    'Every stop on this trip is done',
    'كل محطات الرحلة خلصت',
    fr: 'Tous les arrêts de ce trajet sont terminés',
    es: 'Todas las paradas de este viaje están completadas',
  ),
  EtaUnavailableReason.noRemainingStops => const S(
    'No stops left to estimate for',
    'مفيش محطات متبقية نحسب لها',
    fr: 'Aucun arrêt restant à estimer',
    es: 'No quedan paradas para estimar',
  ),
};

/// A duration as a short, human "12 min" / "under 1 min".
String formatEtaDuration(BuildContext context, Duration eta) {
  final minutes = eta.inMinutes;
  if (minutes < 1) {
    return const S(
      'under 1 min',
      'أقل من دقيقة',
      fr: 'moins de 1 min',
      es: 'menos de 1 min',
    ).of(context);
  }
  if (minutes == 1) {
    return const S(
      '1 min',
      'دقيقة واحدة',
      fr: '1 min',
      es: '1 min',
    ).of(context);
  }
  return S(
    '$minutes min',
    '$minutes د',
    fr: '$minutes min',
    es: '$minutes min',
  ).of(context);
}

/// A straight-line distance as "340 m" / "1.4 km".
///
/// Rounded deliberately coarsely: this is a great-circle distance between
/// a GPS fix and a stop, not a road distance (see [computeTripEta]'s own
/// note on why this project has no road-routing dependency), so quoting it
/// to the metre would imply a precision the number doesn't have.
String formatDistanceMeters(BuildContext context, double meters) {
  if (meters < 950) {
    final rounded = (meters / 10).round() * 10;
    return S(
      '$rounded m',
      '$rounded م',
      fr: '$rounded m',
      es: '$rounded m',
    ).of(context);
  }
  final km = (meters / 100).round() / 10;
  final text = km == km.roundToDouble()
      ? '${km.round()}'
      : km.toStringAsFixed(1);
  return S(
    '$text km',
    '$text كم',
    fr: '$text km',
    es: '$text km',
  ).of(context);
}
