/// Everything the UI needs to *render* a `JourneyStage` — tone, icon,
/// badge word, headline sentence — in one place, so the home card, the
/// journey timeline and the live map can never describe the same trip in
/// three different colors or three different words.
///
/// These used to be private helpers inside `child_journey_card.dart`; the
/// timeline and the map now need the same answers, and duplicating a
/// `switch` over fourteen stages three times is exactly how a "boarded"
/// stage ends up green in one widget and blue in another.
library;

import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../trips/domain/journey_stage.dart';

/// Maps a [JourneyStage] to the one semantic tone it should always render
/// with, per `design-system/MASTER.md` §2: success = arrived/completed,
/// info = active/en-route, warning = paused/delayed, emergency reserved for
/// [JourneyStage.emergency], error reserved for an actual failure
/// ([JourneyStage.cancelled]).
StatusTone stageTone(JourneyStage stage) => switch (stage) {
  JourneyStage.noActiveTrip => StatusTone.neutral,
  JourneyStage.scheduled => StatusTone.info,
  JourneyStage.delayed => StatusTone.warning,
  JourneyStage.started => StatusTone.info,
  JourneyStage.onTheWay => StatusTone.info,
  JourneyStage.approachingPickup => StatusTone.info,
  JourneyStage.arrivedAtPickup => StatusTone.success,
  JourneyStage.boarded => StatusTone.success,
  JourneyStage.continuingToSchool => StatusTone.info,
  JourneyStage.arrivedAtSchool => StatusTone.success,
  JourneyStage.droppedOff => StatusTone.success,
  JourneyStage.completed => StatusTone.success,
  JourneyStage.paused => StatusTone.warning,
  JourneyStage.emergency => StatusTone.emergency,
  JourneyStage.cancelled => StatusTone.error,
};

/// The large glanceable icon for the current stage — paired with
/// [stageTone] so color and symbol always agree, which is also what keeps
/// the status readable without relying on color alone.
IconData stageIcon(JourneyStage stage) => switch (stage) {
  JourneyStage.noActiveTrip => Icons.directions_bus_outlined,
  JourneyStage.scheduled => Icons.schedule_rounded,
  JourneyStage.delayed => Icons.watch_later_outlined,
  JourneyStage.started => Icons.directions_bus_rounded,
  JourneyStage.onTheWay => Icons.directions_bus_rounded,
  JourneyStage.approachingPickup => Icons.near_me_rounded,
  JourneyStage.arrivedAtPickup => Icons.location_on_rounded,
  JourneyStage.boarded => Icons.check_circle_rounded,
  JourneyStage.continuingToSchool => Icons.directions_bus_rounded,
  JourneyStage.arrivedAtSchool => Icons.school_rounded,
  JourneyStage.droppedOff => Icons.home_rounded,
  JourneyStage.completed => Icons.task_alt_rounded,
  JourneyStage.paused => Icons.pause_circle_rounded,
  JourneyStage.emergency => Icons.warning_amber_rounded,
  JourneyStage.cancelled => Icons.cancel_rounded,
};

/// The short dot+label tag shown via [StatusBadge] — a compact system-wide
/// status word, distinct from the fuller reassuring sentence in
/// [stageHeadline].
///
/// [direction] only changes the wording for the handful of stages the two
/// trip directions actually share (started/onTheWay/approachingPickup/
/// arrivedAtPickup — see returnJourneyPath's doc comment for why they're
/// shared); every other stage reads identically either way. Defaults to
/// outbound so existing call sites that haven't been threaded a real
/// direction yet keep their exact previous wording.
S stageBadgeLabel(JourneyStage stage, {TripDirection direction = TripDirection.outbound}) {
  final isReturn = direction == TripDirection.returnTrip;
  return switch (stage) {
    JourneyStage.noActiveTrip => const S(
      'Idle',
      'مفيش رحلة',
      fr: 'Inactif',
      es: 'Inactivo',
    ),
    JourneyStage.scheduled => const S(
      'Scheduled',
      'مجدولة',
      fr: 'Prévu',
      es: 'Programado',
    ),
    JourneyStage.delayed => const S(
      'Delayed',
      'متأخرة',
      fr: 'En retard',
      es: 'Con retraso',
    ),
    JourneyStage.started => isReturn
        ? const S(
            'Leaving school',
            'طالع من المدرسة',
            fr: "Départ de l'école",
            es: 'Saliendo de la escuela',
          )
        : const S('Starting', 'بدأت', fr: 'Départ', es: 'Saliendo'),
    JourneyStage.onTheWay => isReturn
        ? const S(
            'On the way home',
            'في الطريق للبيت',
            fr: 'En route vers la maison',
            es: 'En camino a casa',
          )
        : const S(
            'En route',
            'في الطريق',
            fr: 'En route',
            es: 'En camino',
          ),
    JourneyStage.approachingPickup => isReturn
        ? const S(
            'Approaching home',
            'قريب من البيت',
            fr: 'En approche de la maison',
            es: 'Llegando a casa',
          )
        : const S(
            'Approaching',
            'قريب من محطتك',
            fr: 'En approche',
            es: 'Llegando',
          ),
    JourneyStage.arrivedAtPickup => isReturn
        ? const S(
            'Near home',
            'وصل قريب من البيت',
            fr: 'Près de la maison',
            es: 'Cerca de casa',
          )
        : const S(
            'Arrived at stop',
            'وصل المحطة',
            fr: "Arrivé à l'arrêt",
            es: 'Llegó a la parada',
          ),
    JourneyStage.boarded => const S(
      'Boarded',
      'ركب الأتوبيس',
      fr: 'À bord',
      es: 'A bordo',
    ),
    JourneyStage.continuingToSchool => const S(
      'En route to school',
      'متجه للمدرسة',
      fr: "En route vers l'école",
      es: 'Camino a la escuela',
    ),
    JourneyStage.arrivedAtSchool => const S(
      'At school',
      'في المدرسة',
      fr: "À l'école",
      es: 'En la escuela',
    ),
    JourneyStage.droppedOff => const S(
      'Dropped off',
      'اتسلّم للبيت',
      fr: 'Déposé(e)',
      es: 'Entregado/a',
    ),
    JourneyStage.completed => const S(
      'Completed',
      'اكتملت',
      fr: 'Terminé',
      es: 'Completado',
    ),
    JourneyStage.paused => const S(
      'Paused',
      'متوقفة مؤقتًا',
      fr: 'En pause',
      es: 'En pausa',
    ),
    JourneyStage.emergency => const S(
      'Emergency',
      'طوارئ',
      fr: 'Urgence',
      es: 'Emergencia',
    ),
    JourneyStage.cancelled => const S(
      'Cancelled',
      'ملغاة',
      fr: 'Annulé',
      es: 'Cancelado',
    ),
  };
}

/// The full sentence a parent reads first — written as the answer to the
/// question they opened the app to ask, not as a status string. See
/// [stageBadgeLabel] for why only some stages vary by [direction].
S stageHeadline(
  JourneyStage stage, {
  required String studentName,
  TripDirection direction = TripDirection.outbound,
}) {
  final isReturn = direction == TripDirection.returnTrip;
  return switch (stage) {
    JourneyStage.noActiveTrip => const S(
      'No active trip',
      'مفيش رحلة شغالة',
      fr: 'Aucun trajet en cours',
      es: 'No hay ningún viaje en curso',
    ),
    JourneyStage.scheduled => isReturn
        ? const S(
            'Return trip scheduled',
            'رحلة العودة متجدولة',
            fr: 'Trajet retour prévu',
            es: 'Viaje de regreso programado',
          )
        : const S(
            'Trip scheduled',
            'الرحلة متجدولة',
            fr: 'Trajet prévu',
            es: 'Viaje programado',
          ),
    JourneyStage.delayed => const S(
      'Running late to start',
      'متأخرة عن معادها',
      fr: 'Retard au démarrage',
      es: 'Retraso en la salida',
    ),
    JourneyStage.started => isReturn
        ? S(
            '$studentName is boarding for the ride home',
            '$studentName بيركب عشان يرجع البيت',
            fr: '$studentName monte pour rentrer à la maison',
            es: '$studentName está subiendo para volver a casa',
          )
        : const S(
            'Trip starting…',
            'الرحلة بتبدأ…',
            fr: 'Le trajet démarre…',
            es: 'El viaje está comenzando…',
          ),
    JourneyStage.onTheWay => isReturn
        ? S(
            '$studentName is on the bus home',
            '$studentName في الأتوبيس رايح البيت',
            fr: '$studentName est dans le bus pour rentrer à la maison',
            es: '$studentName va en el autobús de regreso a casa',
          )
        : const S(
            'Bus is on the way',
            'الأتوبيس في الطريق',
            fr: 'Le bus est en route',
            es: 'El autobús está en camino',
          ),
    JourneyStage.approachingPickup => isReturn
        ? const S(
            'Bus is approaching home',
            'الأتوبيس قرّب من البيت',
            fr: 'Le bus est en approche de la maison',
            es: 'El autobús está llegando a casa',
          )
        : const S(
            'Bus is approaching your stop',
            'الأتوبيس قرّب من محطتك',
            fr: 'Le bus est en approche de votre arrêt',
            es: 'El autobús está llegando a tu parada',
          ),
    JourneyStage.arrivedAtPickup => isReturn
        ? const S(
            'Bus has arrived near home',
            'الأتوبيس وصل قريب من البيت',
            fr: 'Le bus est arrivé près de la maison',
            es: 'El autobús llegó cerca de casa',
          )
        : const S(
            'Bus has arrived at your stop',
            'الأتوبيس وصل محطتك',
            fr: 'Le bus est arrivé à votre arrêt',
            es: 'El autobús llegó a tu parada',
          ),
    JourneyStage.boarded => S(
      '$studentName boarded the bus',
      '$studentName ركب الأتوبيس',
      fr: '$studentName est monté(e) dans le bus',
      es: '$studentName subió al autobús',
    ),
    JourneyStage.continuingToSchool => S(
      '$studentName is on the bus to school',
      '$studentName في الأتوبيس متجه للمدرسة',
      fr: "$studentName est dans le bus vers l'école",
      es: '$studentName va en el autobús a la escuela',
    ),
    JourneyStage.arrivedAtSchool => const S(
      'Bus arrived at school',
      'الأتوبيس وصل المدرسة',
      fr: "Le bus est arrivé à l'école",
      es: 'El autobús llegó a la escuela',
    ),
    JourneyStage.droppedOff => S(
      '$studentName was dropped off at home',
      '$studentName اتسلّم في البيت',
      fr: '$studentName a été déposé(e) à la maison',
      es: '$studentName fue dejado/a en casa',
    ),
    JourneyStage.completed => isReturn
        ? const S(
            'Return trip completed',
            'رحلة العودة خلصت',
            fr: 'Trajet retour terminé',
            es: 'Viaje de regreso completado',
          )
        : const S(
            'Trip completed',
            'الرحلة خلصت',
            fr: 'Trajet terminé',
            es: 'Viaje completado',
          ),
    JourneyStage.paused => const S(
      'Trip paused',
      'الرحلة متوقفة مؤقتًا',
      fr: 'Trajet en pause',
      es: 'Viaje en pausa',
    ),
    JourneyStage.emergency => const S(
      'Emergency reported on this trip',
      'اتبلّغ عن طوارئ في الرحلة دي',
      fr: 'Une urgence a été signalée sur ce trajet',
      es: 'Se informó una emergencia en este viaje',
    ),
    JourneyStage.cancelled => const S(
      'Trip cancelled',
      'الرحلة اتلغت',
      fr: 'Trajet annulé',
      es: 'Viaje cancelado',
    ),
  };
}

/// True for the stages where a bus is actually out on the road for this
/// child right now — i.e. where a live map is worth putting on screen and
/// a "Track live" affordance is honest rather than decorative.
bool stageIsLive(JourneyStage stage) => switch (stage) {
  JourneyStage.started ||
  JourneyStage.onTheWay ||
  JourneyStage.approachingPickup ||
  JourneyStage.arrivedAtPickup ||
  JourneyStage.boarded ||
  JourneyStage.continuingToSchool ||
  JourneyStage.arrivedAtSchool ||
  JourneyStage.paused ||
  JourneyStage.emergency => true,
  // Not "live" — the trip may still be active for other students, but
  // this child's own journey is already over, same as arrivedAtSchool.
  JourneyStage.droppedOff ||
  JourneyStage.noActiveTrip ||
  JourneyStage.scheduled ||
  JourneyStage.delayed ||
  JourneyStage.completed ||
  JourneyStage.cancelled => false,
};

/// A tone-tinted round icon badge — the single "what's happening" glyph
/// used by the home card hero, the compact multi-child rows and the live
/// map's floating status card, so the same stage always presents the same
/// shape at three different sizes.
class StageGlyph extends StatelessWidget {
  const StageGlyph({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}
