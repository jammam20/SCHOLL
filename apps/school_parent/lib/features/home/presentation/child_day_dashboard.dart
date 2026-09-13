import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../messages/presentation/contact_school_page.dart';
import '../../students/presentation/child_settings_page.dart';

/// What a parent sees for one child when there is **no bus on the road for
/// them right now** — the state this app is in for most of the day.
///
/// Everything here is a fact already stored against this child or their
/// route: the pickup point an admin set, the absences the parent scheduled
/// themselves, and today's trip document if one exists (its scheduled
/// time, or the time it finished). Deliberately absent: any predicted
/// "next pickup at 07:15 tomorrow". This system stores one trip per route
/// per day and no recurring schedule, so a next-pickup time would be a
/// guess dressed as a fact — and a parent who plans their morning around
/// an invented number is exactly the harm worth avoiding. When there's
/// nothing to say, it says "No trip on record today" plainly.
class ChildDayDashboard extends StatelessWidget {
  const ChildDayDashboard({
    super.key,
    required this.user,
    required this.student,
    required this.trip,
    required this.isTripToday,
  });

  final AppUser user;
  final Student student;

  /// The most recent trip document on this child's route, or null when the
  /// route has never run one. May be from a previous day — [isTripToday]
  /// says which.
  final SchoolTrip? trip;
  final bool isTripToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TodayPanel(trip: trip, isTripToday: isTripToday),
        if (student.isAbsentToday || _upcomingAbsences.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _AbsencePanel(
            absentToday: student.isAbsentToday,
            upcoming: _upcomingAbsences,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _PickupPointPanel(student: student),
        if (trip != null) ...[
          const SizedBox(height: AppSpacing.md),
          _RoutePanel(trip: trip!, isTripToday: isTripToday),
        ],
        const SizedBox(height: AppSpacing.lg),
        _QuickActions(user: user, student: student),
      ],
    );
  }

  /// Scheduled absence dates from today onwards, sorted. Past entries are
  /// pruned on write (StudentsRepository.setScheduledAbsences) but a list
  /// written before that pruning existed could still hold one, and a stale
  /// date presented as upcoming would be simply wrong.
  List<String> get _upcomingAbsences {
    final today = todayIsoDate();
    return student.scheduledAbsenceDates
        .where((date) => date.compareTo(today) > 0)
        .toSet()
        .toList()
      ..sort();
  }
}

/// The panel shell every tile on this dashboard shares — a titled, bordered
/// block rather than a Card, so the dashboard reads as one surface with
/// sections instead of a stack of floating boxes.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.trip, required this.isTripToday});

  final SchoolTrip? trip;
  final bool isTripToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final (headline, detail, tone) = _resolve(context);

    return _Panel(
      icon: Icons.today_rounded,
      iconColor: colors.textMuted,
      title: const S(
        'Today',
        'النهاردة',
        fr: "Aujourd'hui",
        es: 'Hoy',
      ).of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (tone != null)
                StatusBadge(
                  label: _toneLabel(tone).of(context),
                  tone: tone,
                ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  S _toneLabel(StatusTone tone) => switch (tone) {
    StatusTone.success => const S(
      'Finished',
      'خلصت',
      fr: 'Terminé',
      es: 'Finalizado',
    ),
    StatusTone.info => const S(
      'Scheduled',
      'مجدولة',
      fr: 'Prévu',
      es: 'Programado',
    ),
    StatusTone.error => const S(
      'Cancelled',
      'ملغاة',
      fr: 'Annulé',
      es: 'Cancelado',
    ),
    StatusTone.warning => const S(
      'Delayed',
      'متأخرة',
      fr: 'En retard',
      es: 'Con retraso',
    ),
    StatusTone.emergency => const S(
      'Emergency',
      'طوارئ',
      fr: 'Urgence',
      es: 'Emergencia',
    ),
    StatusTone.neutral => const S(
      'No trip',
      'مفيش رحلة',
      fr: 'Aucun trajet',
      es: 'Sin viaje',
    ),
  };

  (String, String?, StatusTone?) _resolve(BuildContext context) {
    final trip = this.trip;
    if (trip == null) {
      return (
        const S(
          'No trip on record today',
          'مفيش رحلة مسجلة النهاردة',
          fr: "Aucun trajet enregistré aujourd'hui",
          es: 'No hay ningún viaje registrado hoy',
        ).of(context),
        const S(
          "This child's route hasn't had a trip created for it yet.",
          'خط سير الطفل ده لسه ما اتعملتلوش رحلة.',
          fr: "L'itinéraire de cet enfant n'a pas encore de trajet créé.",
          es: 'La ruta de este niño/a aún no tiene ningún viaje creado.',
        ).of(context),
        null,
      );
    }

    if (!isTripToday) {
      return (
        const S(
          'No trip on record today',
          'مفيش رحلة مسجلة النهاردة',
          fr: "Aucun trajet enregistré aujourd'hui",
          es: 'No hay ningún viaje registrado hoy',
        ).of(context),
        S(
          'The last trip on this route ran on '
              '${DateFormat.MMMEd().format(trip.scheduledAt)}.',
          'آخر رحلة على الخط ده كانت يوم '
              '${DateFormat.MMMEd().format(trip.scheduledAt)}.',
          fr: 'Le dernier trajet sur cet itinéraire a eu lieu le '
              '${DateFormat.MMMEd().format(trip.scheduledAt)}.',
          es: 'El último viaje de esta ruta fue el '
              '${DateFormat.MMMEd().format(trip.scheduledAt)}.',
        ).of(context),
        null,
      );
    }

    switch (trip.status) {
      case TripStatus.scheduled:
        final scheduled = DateFormat.jm().format(trip.scheduledAt);
        final late = DateTime.now().difference(trip.scheduledAt) >
            const Duration(minutes: 10);
        return (
          S(
            "Today's trip is scheduled for $scheduled",
            'رحلة النهاردة متجدولة الساعة $scheduled',
            fr: "Le trajet d'aujourd'hui est prévu à $scheduled",
            es: 'El viaje de hoy está programado para las $scheduled',
          ).of(context),
          late
              ? const S(
                  "It hasn't started yet — you'll see it here the moment "
                      'the driver begins.',
                  'لسه ما بدأتش — هتشوفها هنا أول ما السواق يبدأ.',
                  fr:
                      "Il n'a pas encore commencé — vous le verrez ici dès "
                      'que le chauffeur démarre.',
                  es: 'Aún no ha comenzado. Lo verás aquí en cuanto el '
                      'conductor empiece.',
                ).of(context)
              : const S(
                  "You'll see the bus here live as soon as the driver "
                      'starts.',
                  'هتشوف الأتوبيس هنا مباشر أول ما السواق يبدأ.',
                  fr: 'Vous verrez le bus ici en direct dès que le '
                      'chauffeur démarre.',
                  es: 'Verás el autobús aquí en directo en cuanto el '
                      'conductor salga.',
                ).of(context),
          late ? StatusTone.warning : StatusTone.info,
        );
      case TripStatus.completed:
        final finishedAt = trip.completedAt;
        return (
          const S(
            "Today's trip is finished",
            'رحلة النهاردة خلصت',
            fr: "Le trajet d'aujourd'hui est terminé",
            es: 'El viaje de hoy ha terminado',
          ).of(context),
          finishedAt == null
              ? null
              : S(
                  'Completed at ${DateFormat.jm().format(finishedAt)}.',
                  'اكتملت الساعة ${DateFormat.jm().format(finishedAt)}.',
                  fr: 'Terminé à ${DateFormat.jm().format(finishedAt)}.',
                  es: 'Completado a las '
                      '${DateFormat.jm().format(finishedAt)}.',
                ).of(context),
          StatusTone.success,
        );
      case TripStatus.cancelled:
        final reason = trip.cancelReason;
        return (
          const S(
            "Today's trip was cancelled",
            'رحلة النهاردة اتلغت',
            fr: "Le trajet d'aujourd'hui a été annulé",
            es: 'El viaje de hoy fue cancelado',
          ).of(context),
          reason == null || reason.isEmpty
              ? const S(
                  'Your school cancelled it. Contact them if you need '
                      'more detail.',
                  'المدرسة لغتها. كلّمهم لو محتاج تفاصيل أكتر.',
                  fr:
                      "Votre école l'a annulé. Contactez-la si vous avez "
                      'besoin de plus de détails.',
                  es: 'Tu escuela lo canceló. Contáctala si necesitas más '
                      'información.',
                ).of(context)
              : reason,
          StatusTone.error,
        );
      // A trip in any of these states is live, and the card shows the map
      // instead of this dashboard — handled here only so the switch is
      // exhaustive and can never fall through to a blank panel.
      case TripStatus.starting:
      case TripStatus.active:
      case TripStatus.paused:
      case TripStatus.emergency:
        return (
          const S(
            'Trip in progress',
            'الرحلة شغالة',
            fr: 'Trajet en cours',
            es: 'Viaje en curso',
          ).of(context),
          null,
          trip.status == TripStatus.emergency
              ? StatusTone.emergency
              : StatusTone.info,
        );
    }
  }
}

class _AbsencePanel extends StatelessWidget {
  const _AbsencePanel({required this.absentToday, required this.upcoming});

  final bool absentToday;
  final List<String> upcoming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return _Panel(
      icon: Icons.event_busy_rounded,
      iconColor: colors.warning,
      title: const S(
        'Absence',
        'الغياب',
        fr: 'Absence',
        es: 'Ausencia',
      ).of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (absentToday)
            Text(
              const S(
                "Marked absent today — the bus will skip this child's stop.",
                'متعلّم غايب النهاردة — الأتوبيس هيتخطى محطته.',
                fr:
                    "Marqué(e) absent(e) aujourd'hui — le bus sautera "
                    "l'arrêt de cet enfant.",
                es: 'Marcado como ausente hoy: el autobús se saltará la '
                    'parada de este niño/a.',
              ).of(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (upcoming.isNotEmpty) ...[
            if (absentToday) const SizedBox(height: AppSpacing.sm),
            Text(
              const S(
                'Scheduled ahead',
                'مجدول قدام',
                fr: "Programmé à l'avance",
                es: 'Programado con antelación',
              ).of(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final date in upcoming)
                  StatusBadge(
                    label: _formatIsoDate(date),
                    tone: StatusTone.warning,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Absence dates are stored as plain 'yyyy-MM-dd' strings; an unparseable
  /// one is shown as-is rather than swallowed, so a bad record is visible
  /// instead of silently missing from the list.
  String _formatIsoDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    return parsed == null ? iso : DateFormat.MMMEd().format(parsed);
  }
}

/// The child's assigned pickup point, shown on a small static map — the one
/// place a parent can check that the school put their stop where they think
/// it is. Non-interactive on purpose: it's a reference, not a tracker.
class _PickupPointPanel extends StatelessWidget {
  const _PickupPointPanel({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    if (!student.hasLocation) {
      return _Panel(
        icon: Icons.location_off_outlined,
        iconColor: colors.textMuted,
        title: const S(
          'Pickup point',
          'نقطة الاستلام',
          fr: 'Point de ramassage',
          es: 'Punto de recogida',
        ).of(context),
        child: Text(
          const S(
            "Your school hasn't set a pickup point for this child yet. "
                'Live tracking turns on once they do.',
            'المدرسة لسه ما حددتش نقطة استلام للطفل ده. المتابعة المباشرة '
                'هتشتغل أول ما تتحدد.',
            fr:
                "Votre école n'a pas encore défini de point de ramassage "
                "pour cet enfant. Le suivi en direct s'activera dès que ce "
                'sera fait.',
            es: 'Tu escuela aún no ha definido un punto de recogida para '
                'este niño/a. El seguimiento en vivo se activará en '
                'cuanto lo haga.',
          ).of(context),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      );
    }

    final point = LatLng(student.latitude!, student.longitude!);

    return _Panel(
      icon: Icons.place_rounded,
      iconColor: Theme.of(context).colorScheme.primary,
      title: const S(
        'Pickup point',
        'نقطة الاستلام',
        fr: 'Point de ramassage',
        es: 'Punto de recogida',
      ).of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student.pickupPointId != null
                ? const S(
                    'Your school assigned a shared pickup point for this '
                        'child.',
                    'المدرسة حددت نقطة استلام مشتركة للطفل ده.',
                    fr: 'Votre école a assigné un point de ramassage '
                        'partagé pour cet enfant.',
                    es: 'Tu escuela asignó un punto de recogida compartido '
                        'para este niño/a.',
                  ).of(context)
                : const S(
                    'Door-to-door pickup, set by your school.',
                    'استلام من باب البيت، محدد من المدرسة.',
                    fr: 'Ramassage porte-à-porte, défini par votre école.',
                    es: 'Recogida puerta a puerta, definida por tu '
                        'escuela.',
                  ).of(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              height: 130,
              child: IgnorePointer(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: point,
                    zoom: 15.5,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: point,
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('pickup-zone'),
                      center: point,
                      // The same radius the journey stage machine treats
                      // as "the bus has arrived at your stop".
                      radius: 100,
                      fillColor: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.10),
                      strokeColor: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  liteModeEnabled: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({required this.trip, required this.isTripToday});

  final SchoolTrip trip;
  final bool isTripToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return _Panel(
      icon: Icons.route_rounded,
      iconColor: colors.textMuted,
      title: isTripToday
          ? const S(
              "Today's route",
              'خط النهاردة',
              fr: 'Itinéraire du jour',
              es: 'Ruta de hoy',
            ).of(context)
          : const S(
              'Most recent route',
              'آخر خط سير',
              fr: 'Itinéraire le plus récent',
              es: 'Ruta más reciente',
            ).of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip.routeName.isNotEmpty)
            _DetailRow(
              icon: Icons.alt_route_rounded,
              label: const S(
                'Route',
                'الخط',
                fr: 'Itinéraire',
                es: 'Ruta',
              ).of(context),
              value: trip.routeName,
            ),
          if (trip.busName.isNotEmpty)
            _DetailRow(
              icon: Icons.directions_bus_rounded,
              label: const S(
                'Bus',
                'الأتوبيس',
                fr: 'Bus',
                es: 'Autobús',
              ).of(context),
              value: trip.busPlateNumber.isEmpty
                  ? trip.busName
                  : '${trip.busName} · ${trip.busPlateNumber}',
            ),
          if (trip.driverName.isNotEmpty)
            _DetailRow(
              icon: Icons.badge_outlined,
              label: const S(
                'Driver',
                'السواق',
                fr: 'Chauffeur',
                es: 'Conductor',
              ).of(context),
              value: trip.driverName,
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: colors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two things a parent actually does from here. Both open screens that
/// already exist and already work — nothing here is a placeholder.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.user, required this.student});

  final AppUser user;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final messageButton = AppButton.secondary(
      label: const S(
        'Message school',
        'راسل المدرسة',
        fr: "Écrire à l'école",
        es: 'Mensaje a la escuela',
      ).of(context),
      icon: Icons.chat_bubble_outline_rounded,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ContactSchoolPage(user: user)),
      ),
    );

    if (!student.approved) return messageButton;

    final settingsButton = AppButton.secondary(
      label: const S(
        'Child settings',
        'إعدادات الطفل',
        fr: "Paramètres de l'enfant",
        es: 'Ajustes del niño/a',
      ).of(context),
      icon: Icons.tune_rounded,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChildSettingsPage(user: user, student: student),
        ),
      ),
    );

    // Side by side, each button gets roughly half the card's width minus the
    // gap — on a 375px phone that's too narrow for "Message school" /
    // "Child settings" at default text scale, so the label silently
    // truncated to "Message …" on every phone-width screen. Below
    // `_stackBreakpoint`, stack them full-width instead so neither label
    // ever has less room than it needs.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              messageButton,
              const SizedBox(height: AppSpacing.sm),
              settingsButton,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: messageButton),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: settingsButton),
          ],
        );
      },
    );
  }
}

/// Below this available width, [_QuickActions] stacks its two buttons
/// instead of splitting the row in half — chosen from the two English
/// labels ("Message school" / "Child settings"), the longer of the pair,
/// at the app's default text scale.
const _stackBreakpoint = 360.0;
