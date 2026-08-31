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
  JourneyStage.completed => Icons.task_alt_rounded,
  JourneyStage.paused => Icons.pause_circle_rounded,
  JourneyStage.emergency => Icons.warning_amber_rounded,
  JourneyStage.cancelled => Icons.cancel_rounded,
};

/// The short dot+label tag shown via [StatusBadge] — a compact system-wide
/// status word, distinct from the fuller reassuring sentence in
/// [stageHeadline].
S stageBadgeLabel(JourneyStage stage) => switch (stage) {
  JourneyStage.noActiveTrip => const S('Idle', 'مفيش رحلة'),
  JourneyStage.scheduled => const S('Scheduled', 'مجدولة'),
  JourneyStage.delayed => const S('Delayed', 'متأخرة'),
  JourneyStage.started => const S('Starting', 'بدأت'),
  JourneyStage.onTheWay => const S('En route', 'في الطريق'),
  JourneyStage.approachingPickup => const S('Approaching', 'قريب من محطتك'),
  JourneyStage.arrivedAtPickup => const S('Arrived at stop', 'وصل المحطة'),
  JourneyStage.boarded => const S('Boarded', 'ركب الأتوبيس'),
  JourneyStage.continuingToSchool => const S(
    'En route to school',
    'متجه للمدرسة',
  ),
  JourneyStage.arrivedAtSchool => const S('At school', 'في المدرسة'),
  JourneyStage.completed => const S('Completed', 'اكتملت'),
  JourneyStage.paused => const S('Paused', 'متوقفة مؤقتًا'),
  JourneyStage.emergency => const S('Emergency', 'طوارئ'),
  JourneyStage.cancelled => const S('Cancelled', 'ملغاة'),
};

/// The full sentence a parent reads first — written as the answer to the
/// question they opened the app to ask, not as a status string.
S stageHeadline(JourneyStage stage, {required String studentName}) =>
    switch (stage) {
      JourneyStage.noActiveTrip => const S(
        'No active trip',
        'مفيش رحلة شغالة',
      ),
      JourneyStage.scheduled => const S('Trip scheduled', 'الرحلة متجدولة'),
      JourneyStage.delayed => const S(
        'Running late to start',
        'متأخرة عن معادها',
      ),
      JourneyStage.started => const S('Trip starting…', 'الرحلة بتبدأ…'),
      JourneyStage.onTheWay => const S(
        'Bus is on the way',
        'الأتوبيس في الطريق',
      ),
      JourneyStage.approachingPickup => const S(
        'Bus is approaching your stop',
        'الأتوبيس قرّب من محطتك',
      ),
      JourneyStage.arrivedAtPickup => const S(
        'Bus has arrived at your stop',
        'الأتوبيس وصل محطتك',
      ),
      JourneyStage.boarded => S(
        '$studentName boarded the bus',
        '$studentName ركب الأتوبيس',
      ),
      JourneyStage.continuingToSchool => S(
        '$studentName is on the bus to school',
        '$studentName في الأتوبيس متجه للمدرسة',
      ),
      JourneyStage.arrivedAtSchool => const S(
        'Bus arrived at school',
        'الأتوبيس وصل المدرسة',
      ),
      JourneyStage.completed => const S('Trip completed', 'الرحلة خلصت'),
      JourneyStage.paused => const S(
        'Trip paused',
        'الرحلة متوقفة مؤقتًا',
      ),
      JourneyStage.emergency => const S(
        'Emergency reported on this trip',
        'اتبلّغ عن طوارئ في الرحلة دي',
      ),
      JourneyStage.cancelled => const S('Trip cancelled', 'الرحلة اتلغت'),
    };

/// Resolves a [StatusTone] to its concrete token color.
Color toneColor(AppColorTokens colors, StatusTone tone) => switch (tone) {
  StatusTone.success => colors.success,
  StatusTone.warning => colors.warning,
  StatusTone.error => colors.error,
  StatusTone.info => colors.info,
  StatusTone.emergency => colors.emergency,
  StatusTone.neutral => colors.textMuted,
};

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
