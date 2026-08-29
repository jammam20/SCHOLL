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
  ),
  EtaUnavailableReason.noGpsSignal => const S(
    'Waiting for the bus to send its location',
    'في انتظار الأتوبيس يبعت موقعه',
  ),
  EtaUnavailableReason.staleGps => const S(
    "The bus's last location is too old to estimate from",
    'آخر موقع للأتوبيس قديم أوي عشان نحسب منه',
  ),
  EtaUnavailableReason.allStopsCompleted => const S(
    'Every stop on this trip is done',
    'كل محطات الرحلة خلصت',
  ),
  EtaUnavailableReason.noRemainingStops => const S(
    'No stops left to estimate for',
    'مفيش محطات متبقية نحسب لها',
  ),
};

/// A duration as a short, human "12 min" / "under 1 min".
String formatEtaDuration(BuildContext context, Duration eta) {
  final minutes = eta.inMinutes;
  if (minutes < 1) {
    return const S('under 1 min', 'أقل من دقيقة').of(context);
  }
  if (minutes == 1) return const S('1 min', 'دقيقة واحدة').of(context);
  return S('$minutes min', '$minutes د').of(context);
}
