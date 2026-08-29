import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/async_error_view.dart';
import '../../schools/data/schools_repository.dart';
import '../../students/presentation/child_settings_page.dart';
import '../../tracking/data/parent_tracking_repository.dart';
import '../../tracking/domain/live_bus_position.dart';
import '../../tracking/domain/parent_trip_eta.dart';
import '../../tracking/presentation/eta_text.dart';
import '../../tracking/presentation/live_trip_map.dart';
import '../../trips/data/stop_order_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../../trips/domain/journey_stage.dart';
import 'journey_timeline.dart';

const _avatarColors = [
  Color(0xFF155EEF),
  Color(0xFF0E9384),
  Color(0xFF7A5AF8),
  Color(0xFFE04F16),
  Color(0xFFC11574),
];

/// One child's whole status at a glance: name, whether they're approved/
/// absent/on a route at all, and — when a trip exists for their route today
/// — exactly where that trip stands (via [JourneyTimeline]) plus the
/// existing live map. Replaces the old flat "name + raw trip status chip"
/// card; every fact shown here already existed somewhere in the app, this
/// just puts it in one place instead of behind a settings tap or a status
/// string like "active" that meant nothing to a parent.
///
/// Visual priority, top to bottom: the *current situation* (is the bus
/// coming, has my child boarded, are they at school) is the first and
/// biggest thing on the card — everything else (route/bus/driver details,
/// the step-by-step timeline, the live map) is supporting detail underneath
/// it, per the product brief's "understand extremely quickly" requirement.
class ChildJourneyCard extends StatelessWidget {
  const ChildJourneyCard({super.key, required this.user, required this.student});

  /// The signed-in parent. Carries the school this card reads from, and is
  /// handed on to the screens reached from here that write on the parent's
  /// behalf (child settings, contacting the school).
  final AppUser user;
  final Student student;

  String get schoolId => user.schoolId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final avatarColor =
        _avatarColors[student.id.hashCode.abs() % _avatarColors.length];
    final initial = student.name.isEmpty ? '?' : student.name[0].toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    student.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (student.approved)
                  IconButton(
                    tooltip: const S('Settings', 'الإعدادات').of(context),
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChildSettingsPage(user: user, student: student),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!student.approved)
              _InfoBanner(
                icon: Icons.hourglass_top,
                tone: StatusTone.warning,
                title: const S('Pending approval', 'في انتظار الموافقة').of(context),
                subtitle: const S(
                  "Your school hasn't approved this child yet.",
                  'مدرستك لسه ما وافقتش على الطفل ده.',
                ).of(context),
              )
            else if (student.isAbsentToday)
              _InfoBanner(
                icon: Icons.event_busy,
                tone: StatusTone.warning,
                title: const S('Absent today', 'غايب النهاردة').of(context),
                subtitle: const S(
                  "The bus will skip this child's stop today.",
                  'الأتوبيس هيتخطى محطة الطفل ده النهاردة.',
                ).of(context),
              )
            else if (student.routeId == null || student.routeId!.isEmpty)
              _InfoBanner(
                icon: Icons.route_outlined,
                tone: StatusTone.neutral,
                title: const S('No route assigned yet', 'لسه من غير خط سير').of(
                  context,
                ),
                subtitle: const S(
                  'Ask your school to assign a route for this child.',
                  'كلّم مدرستك عشان تحدد خط سير للطفل ده.',
                ).of(context),
              )
            else
              _TripSection(
                schoolId: schoolId,
                routeId: student.routeId!,
                student: student,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final StatusTone tone;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context.appColors, tone);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(label: title, tone: tone),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Finds today's trip on this child's route (if any) and hands off to
/// [_ActiveJourney] — or shows a clear "nothing to track right now" state,
/// including when the only trip on record is a stale one from a previous
/// day (watchLatestTripForRoute has no "today" concept of its own, it just
/// returns the most recently scheduled trip, so a finished trip from
/// yesterday would otherwise read as today's without this check).
class _TripSection extends StatelessWidget {
  const _TripSection({
    required this.schoolId,
    required this.routeId,
    required this.student,
  });

  final String schoolId;
  final String routeId;
  final Student student;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchLatestTripForRoute(
        schoolId: schoolId,
        routeId: routeId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TripSkeleton();
        }
        if (snapshot.hasError) return const AsyncErrorView(compact: true);

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const _NoActiveTrip();

        final trip = SchoolTrip.fromMap(docs.first.id, docs.first.data());
        final now = DateTime.now();
        final isSameDay =
            trip.scheduledAt.year == now.year &&
            trip.scheduledAt.month == now.month &&
            trip.scheduledAt.day == now.day;
        final isTerminal =
            trip.status == TripStatus.completed || trip.status == TripStatus.cancelled;

        // A finished/cancelled trip from a different day isn't "today's
        // journey" — surface it as no active trip rather than an oddly
        // dated timeline.
        if (!isSameDay && isTerminal) {
          return const _NoActiveTrip();
        }

        return _ActiveJourney(schoolId: schoolId, trip: trip, student: student);
      },
    );
  }
}

/// Placeholder shaped like the eventual [_Body] — a status icon and two
/// lines of text — so the card doesn't jump/reflow once the trip document
/// arrives. See `design-system/MASTER.md` §9.
class _TripSkeleton extends StatelessWidget {
  const _TripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(width: 44, height: 44, borderRadius: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeleton(width: 160, height: 16),
                SizedBox(height: AppSpacing.sm),
                AppSkeleton(width: 220, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveTrip extends StatelessWidget {
  const _NoActiveTrip();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(Icons.directions_bus_outlined, color: colors.textMuted, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            const S(
              'No active trip right now',
              'مفيش رحلة شغالة دلوقتي',
            ).of(context),
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Composes the trip's own status with the boardedStudents field and (only
/// while the trip is actually [TripStatus.active]) the driver's live RTDB
/// position, to drive both the status header and [JourneyTimeline] — the
/// same [computeJourneyStage] a live map or a future screen could reuse,
/// so this card and LiveTripMap never disagree about where the trip is.
class _ActiveJourney extends StatelessWidget {
  const _ActiveJourney({
    required this.schoolId,
    required this.trip,
    required this.student,
  });

  final String schoolId;
  final SchoolTrip trip;
  final Student student;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TripStopProgress>(
      stream: StopOrderRepository().watchStopProgress(
        schoolId: schoolId,
        tripId: trip.id,
      ),
      builder: (context, progressSnapshot) {
        if (progressSnapshot.hasError) {
          return const AsyncErrorView(compact: true);
        }
        final progress = progressSnapshot.data ?? const TripStopProgress();
        final hasBoarded = progress.boardedStudents.contains(student.id);

        // Live distance only matters while the trip is actively moving —
        // every other status resolves its stage from trip.status alone.
        if (trip.status != TripStatus.active) {
          return _Body(
            trip: trip,
            student: student,
            hasBoarded: hasBoarded,
            distanceToPickupMeters: null,
            eta: null,
          );
        }

        return StreamBuilder<DatabaseEvent>(
          stream: ParentTrackingRepository().watchTripLocation(
            schoolId: schoolId,
            tripId: trip.id,
          ),
          builder: (context, locationSnapshot) {
            // A failed RTDB read leaves us in exactly the situation of a
            // bus that hasn't broadcast yet: no position to reason from.
            // The ETA engine names that case (noGpsSignal) instead of the
            // card silently dropping the estimate.
            final busPosition = locationSnapshot.hasError
                ? null
                : LiveBusPosition.fromRtdbValue(
                    locationSnapshot.data?.snapshot.value,
                  );

            return StreamBuilder<School?>(
              stream: SchoolsRepository().watchSchool(schoolId),
              builder: (context, schoolSnapshot) {
                final school = schoolSnapshot.data;

                double? distanceToPickup;
                double? distanceToSchool;
                if (busPosition != null && student.hasLocation) {
                  distanceToPickup = haversineMeters(
                    busPosition.latitude,
                    busPosition.longitude,
                    student.latitude!,
                    student.longitude!,
                  );
                }
                if (busPosition != null && school != null && school.hasLocation) {
                  distanceToSchool = haversineMeters(
                    busPosition.latitude,
                    busPosition.longitude,
                    school.latitude!,
                    school.longitude!,
                  );
                }

                return _Body(
                  trip: trip,
                  student: student,
                  hasBoarded: hasBoarded,
                  distanceToPickupMeters: distanceToPickup,
                  distanceToSchoolMeters: distanceToSchool,
                  eta: computeParentTripEta(
                    tripStatus: trip.status,
                    progress: progress,
                    student: student,
                    school: school,
                    busPosition: busPosition,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Maps a [JourneyStage] to the one semantic tone it should always render
/// with, per `design-system/MASTER.md` §2: success = arrived/completed,
/// info = active/en-route, warning = paused/delayed, emergency reserved for
/// [JourneyStage.emergency], error reserved for an actual failure
/// ([JourneyStage.cancelled]).
StatusTone _stageTone(JourneyStage stage) => switch (stage) {
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
/// [_stageTone] so color and symbol always agree.
IconData _stageIcon(JourneyStage stage) => switch (stage) {
  JourneyStage.noActiveTrip => Icons.directions_bus_outlined,
  JourneyStage.scheduled => Icons.schedule,
  JourneyStage.delayed => Icons.watch_later_outlined,
  JourneyStage.started => Icons.directions_bus,
  JourneyStage.onTheWay => Icons.directions_bus,
  JourneyStage.approachingPickup => Icons.near_me,
  JourneyStage.arrivedAtPickup => Icons.location_on,
  JourneyStage.boarded => Icons.check_circle,
  JourneyStage.continuingToSchool => Icons.directions_bus,
  JourneyStage.arrivedAtSchool => Icons.school,
  JourneyStage.completed => Icons.check_circle,
  JourneyStage.paused => Icons.pause_circle,
  JourneyStage.emergency => Icons.warning_amber_rounded,
  JourneyStage.cancelled => Icons.cancel,
};

/// The short dot+label tag shown via [StatusBadge] — a compact system-wide
/// status word, distinct from the fuller reassuring sentence in
/// [_stageHeadline].
S _stageBadgeLabel(JourneyStage stage) => switch (stage) {
  JourneyStage.noActiveTrip => const S('Idle', 'مفيش رحلة'),
  JourneyStage.scheduled => const S('Scheduled', 'مجدولة'),
  JourneyStage.delayed => const S('Delayed', 'متأخرة'),
  JourneyStage.started => const S('Starting', 'بدأت'),
  JourneyStage.onTheWay => const S('En route', 'في الطريق'),
  JourneyStage.approachingPickup => const S('Approaching', 'قريب من محطتك'),
  JourneyStage.arrivedAtPickup => const S('Arrived at stop', 'وصل المحطة'),
  JourneyStage.boarded => const S('Boarded', 'ركب الأتوبيس'),
  JourneyStage.continuingToSchool => const S('En route to school', 'متجه للمدرسة'),
  JourneyStage.arrivedAtSchool => const S('At school', 'في المدرسة'),
  JourneyStage.completed => const S('Completed', 'اكتملت'),
  JourneyStage.paused => const S('Paused', 'متوقفة مؤقتًا'),
  JourneyStage.emergency => const S('Emergency', 'طوارئ'),
  JourneyStage.cancelled => const S('Cancelled', 'ملغاة'),
};

Color _toneColor(AppColorTokens colors, StatusTone tone) => switch (tone) {
  StatusTone.success => colors.success,
  StatusTone.warning => colors.warning,
  StatusTone.error => colors.error,
  StatusTone.info => colors.info,
  StatusTone.emergency => colors.emergency,
  StatusTone.neutral => colors.textMuted,
};

class _Body extends StatelessWidget {
  const _Body({
    required this.trip,
    required this.student,
    required this.hasBoarded,
    required this.distanceToPickupMeters,
    this.distanceToSchoolMeters,
    required this.eta,
  });

  final SchoolTrip trip;
  final Student student;
  final bool hasBoarded;
  final double? distanceToPickupMeters;
  final double? distanceToSchoolMeters;

  /// The shared ETA engine's answer for this child on this trip, or null
  /// while the trip isn't active (no live estimate to make).
  final ParentTripEta? eta;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final stage = computeJourneyStage(
      JourneyInputs(
        tripStatus: trip.status,
        hasBoarded: hasBoarded,
        distanceToPickupMeters: distanceToPickupMeters,
        distanceToSchoolMeters: distanceToSchoolMeters,
        now: DateTime.now(),
        scheduledAt: trip.scheduledAt,
      ),
    );

    final tone = _stageTone(stage);
    final toneColor = _toneColor(colors, tone);

    final showMap =
        trip.status == TripStatus.active ||
        trip.status == TripStatus.starting ||
        trip.status == TripStatus.paused ||
        trip.status == TripStatus.emergency;

    // An ETA is only meaningful for the stages where the parent is still
    // waiting for the bus to reach them.
    final showEta =
        stage == JourneyStage.onTheWay ||
        stage == JourneyStage.approachingPickup;
    final etaDuration = eta?.eta.etaToNextStop;
    final unavailableReason = eta?.eta.unavailableReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The current situation — the single most important fact on this
        // card — leads with a large tone-colored icon, then the reassuring
        // sentence, then a compact system-wide status tag, so a parent gets
        // the answer before they've had to read anything.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_stageIcon(stage), color: toneColor, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _stageHeadline(stage).of(context),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (showEta && etaDuration != null)
                        _EtaChip(eta: etaDuration),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  StatusBadge(label: _stageBadgeLabel(stage).of(context), tone: tone),
                  // When there's no reliable ETA, say *why* rather than
                  // leaving a gap where a number used to be — the shared
                  // engine hands us the reason precisely so a parent isn't
                  // left wondering whether the app is broken.
                  if (showEta && etaDuration == null && unavailableReason != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      etaUnavailableText(unavailableReason).of(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          S(
            '${trip.routeName.isEmpty ? 'Route' : trip.routeName} · '
                '${trip.busName} (${trip.busPlateNumber}) · ${trip.driverName}',
            '${trip.routeName.isEmpty ? 'الخط' : trip.routeName} · '
                '${trip.busName} (${trip.busPlateNumber}) · ${trip.driverName}',
          ).of(context),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        Text(
          DateFormat.jm().format(trip.scheduledAt),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        // Real route progress from the trip's own stop order — where this
        // child sits in today's run, not a guess.
        if (eta != null && eta!.hasStopPosition && !hasBoarded)
          Text(
            S(
              'Your stop is ${eta!.stopNumber} of ${eta!.totalStops} on '
                  "today's route",
              'محطتك رقم ${eta!.stopNumber} من ${eta!.totalStops} في خط '
                  'النهاردة',
            ).of(context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        JourneyTimeline(stage: stage, hasBoarded: hasBoarded),
        if (showMap) ...[
          const SizedBox(height: AppSpacing.xs),
          LiveTripMap(
            schoolId: student.schoolId,
            tripId: trip.id,
            tripStatus: trip.status,
            student: student,
          ),
        ],
      ],
    );
  }

  S _stageHeadline(JourneyStage stage) => switch (stage) {
    JourneyStage.noActiveTrip => const S('No active trip', 'مفيش رحلة شغالة'),
    JourneyStage.scheduled => const S('Trip scheduled', 'الرحلة متجدولة'),
    JourneyStage.delayed => const S(
      'Running late to start',
      'متأخرة عن معادها',
    ),
    JourneyStage.started => const S('Trip starting…', 'الرحلة بتبدأ…'),
    JourneyStage.onTheWay => const S('Bus is on the way', 'الأتوبيس في الطريق'),
    JourneyStage.approachingPickup => const S(
      'Bus is approaching your stop',
      'الأتوبيس قرّب من محطتك',
    ),
    JourneyStage.arrivedAtPickup => const S(
      'Bus has arrived at your stop',
      'الأتوبيس وصل محطتك',
    ),
    JourneyStage.boarded => S(
      '${student.name} boarded the bus',
      '${student.name} ركب الأتوبيس',
    ),
    JourneyStage.continuingToSchool => S(
      '${student.name} is on the bus to school',
      '${student.name} في الأتوبيس متجه للمدرسة',
    ),
    JourneyStage.arrivedAtSchool => const S(
      'Bus arrived at school',
      'الأتوبيس وصل المدرسة',
    ),
    JourneyStage.completed => const S('Trip completed', 'الرحلة خلصت'),
    JourneyStage.paused => const S('Trip paused', 'الرحلة متوقفة مؤقتًا'),
    JourneyStage.emergency => const S(
      'Emergency reported on this trip',
      'اتبلّغ عن طوارئ في الرحلة دي',
    ),
    JourneyStage.cancelled => const S('Trip cancelled', 'الرحلة اتلغت'),
  };
}

/// Only ever rendered when the ETA engine actually produced a duration —
/// the "no ETA, and here's why" case is a separate line under the status
/// badge, not a chip pretending to hold a number.
class _EtaChip extends StatelessWidget {
  const _EtaChip({required this.eta});

  final Duration eta;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = eta.inMinutes < 1
        ? const S('Arriving soon', 'هيوصل قريب').of(context)
        : S(
            'Arriving in ${eta.inMinutes} min',
            'هيوصل خلال ${eta.inMinutes} د',
          ).of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.info.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.info,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
