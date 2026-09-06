import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../schools/data/schools_repository.dart';
import '../../students/presentation/child_settings_page.dart';
import '../../tracking/data/parent_tracking_repository.dart';
import '../../tracking/domain/live_bus_position.dart';
import '../../tracking/domain/parent_trip_eta.dart';
import '../../tracking/presentation/eta_text.dart';
import '../../tracking/presentation/live_trip_map.dart';
import '../../tracking/presentation/live_trip_map_page.dart';
import '../../trips/data/stop_order_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../../trips/domain/journey_stage.dart';
import '../../trips/domain/pick_active_trip.dart';
import 'child_avatar.dart';
import 'child_day_dashboard.dart';
import 'journey_stage_visuals.dart';
import 'journey_timeline.dart';

/// The width at which one child's expanded card stops being a phone column
/// and becomes a real two-pane layout: the status, details and timeline on
/// one side, the live map given the room it deserves on the other. Below
/// this the same content stacks, unchanged.
const _twoPaneBreakpoint = 760.0;

/// One child's whole situation, at one of two densities.
///
/// **Expanded** (a single child, or the one a parent focused with the
/// switcher) is the full account: the current stage in large type, the
/// route/bus/driver behind it, the stop-by-stop timeline, and — while a bus
/// is genuinely out on the road for this child — the live map as the
/// centerpiece. **Compact** (what each child gets when "All children" is
/// selected) is the same truth in four lines: stage, ETA, a progress rail,
/// and a way into the full view. Nothing is dropped in compact mode; it is
/// summarized, and the summary is always drawn from the same
/// [computeJourneyStage] the expanded view uses, so the two can never
/// disagree about where a bus is.
class ChildJourneyCard extends StatelessWidget {
  const ChildJourneyCard({
    super.key,
    required this.user,
    required this.student,
    this.expanded = true,
    this.onFocusRequested,
  });

  /// The signed-in parent. Carries the school this card reads from, and is
  /// handed on to the screens reached from here that write on the parent's
  /// behalf (child settings, contacting the school).
  final AppUser user;
  final Student student;

  /// False in the multi-child list, where four full cards would bury the
  /// one that matters.
  final bool expanded;

  /// Asks the home tab to focus this child — the action behind "Track
  /// live" and "View details" on a compact card. Null when there is
  /// nothing to focus into (a single-child parent is already there).
  final VoidCallback? onFocusRequested;

  String get schoolId => user.schoolId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: EdgeInsets.all(expanded ? AppSpacing.lg : AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChildAvatar(student: student, size: expanded ? 44 : 38),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style:
                            (expanded
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.titleMedium)
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!student.approved)
                        Text(
                          const S(
                            'Awaiting school approval',
                            'في انتظار موافقة المدرسة',
                          ).of(context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (student.approved && expanded)
                  IconButton(
                    tooltip: const S('Child settings', 'إعدادات الطفل').of(
                      context,
                    ),
                    icon: const Icon(Icons.tune_rounded),
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
            _body(context),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!student.approved) {
      return _InfoBanner(
        icon: Icons.hourglass_top_rounded,
        tone: StatusTone.warning,
        title: const S('Pending approval', 'في انتظار الموافقة').of(context),
        subtitle: const S(
          "Your school hasn't approved this child yet. Tracking, absences "
              'and trip alerts all switch on once they do.',
          'مدرستك لسه ما وافقتش على الطفل ده. المتابعة والغياب وتنبيهات '
              'الرحلة كلها هتشتغل أول ما توافق.',
        ).of(context),
      );
    }

    if (student.routeId == null || student.routeId!.isEmpty) {
      return _InfoBanner(
        icon: Icons.route_outlined,
        tone: StatusTone.neutral,
        title: const S('No route assigned yet', 'لسه من غير خط سير').of(
          context,
        ),
        subtitle: const S(
          'Ask your school to assign a route — that is what connects this '
              "child to a bus and to today's trip.",
          'كلّم مدرستك تحدد خط سير — ده اللي بيربط الطفل ده بالأتوبيس '
              'وبرحلة النهاردة.',
        ).of(context),
      );
    }

    return _TripSection(
      user: user,
      student: student,
      routeId: student.routeId!,
      expanded: expanded,
      onFocusRequested: onFocusRequested,
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
    final color = toneColor(context.appColors, tone);
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
          const SizedBox(width: AppSpacing.md),
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

/// Finds the latest trip on this child's route and decides which of the two
/// worlds this child is in right now: a bus actually on the road (hand off
/// to [_ActiveJourney]), or the rest of the day (hand off to
/// [ChildDayDashboard]).
///
/// `watchLatestTripForRoute` has no "today" concept of its own — it returns
/// the route's most recently scheduled candidates, which could include
/// yesterday's — so the day check happens here. `pickActiveTrip` picks the
/// right one out of those candidates (see its own doc comment: a live trip
/// always wins over a later-scheduled cancellation). A *live* status is
/// trusted regardless of the scheduled date, though: a trip that is
/// `active` right now is happening right now, whatever day its schedule
/// says.
class _TripSection extends StatelessWidget {
  const _TripSection({
    required this.user,
    required this.student,
    required this.routeId,
    required this.expanded,
    required this.onFocusRequested,
  });

  final AppUser user;
  final Student student;
  final String routeId;
  final bool expanded;
  final VoidCallback? onFocusRequested;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchLatestTripForRoute(
        schoolId: user.schoolId,
        routeId: routeId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TripSkeleton();
        }
        if (snapshot.hasError) {
          return ErrorStateView(
            compact: true,
            message: const S(
              "Couldn't load this child's trip — check your connection.",
              'معرفناش نحمّل رحلة الطفل ده — اتأكد من الاتصال.',
            ).of(context),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        final candidates = docs
            .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
            .toList();
        final trip = pickActiveTrip(candidates);

        final now = DateTime.now();
        final isTripToday =
            trip != null &&
            trip.scheduledAt.year == now.year &&
            trip.scheduledAt.month == now.month &&
            trip.scheduledAt.day == now.day;

        final isLiveStatus =
            trip != null &&
            (trip.status == TripStatus.starting ||
                trip.status == TripStatus.active ||
                trip.status == TripStatus.paused ||
                trip.status == TripStatus.emergency);

        // A child marked absent today is not being collected today. Putting
        // a "bus approaching your stop" timeline in front of their parent
        // would be actively misleading — the bus is running, it just isn't
        // stopping for them — so the absence takes over the card and the
        // day dashboard explains the rest.
        if (student.isAbsentToday) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(
                icon: Icons.event_busy_rounded,
                tone: StatusTone.warning,
                title: const S('Absent today', 'غايب النهاردة').of(context),
                subtitle: const S(
                  "The bus will skip this child's stop today. You can undo "
                      'this in child settings.',
                  'الأتوبيس هيتخطى محطة الطفل ده النهاردة. تقدر تلغي ده من '
                      'إعدادات الطفل.',
                ).of(context),
              ),
              if (expanded) ...[
                const SizedBox(height: AppSpacing.md),
                ChildDayDashboard(
                  user: user,
                  student: student,
                  trip: trip,
                  isTripToday: isTripToday,
                ),
              ] else
                _CompactFooterAction(
                  label: const S('View details', 'شوف التفاصيل').of(context),
                  onPressed: onFocusRequested,
                ),
            ],
          );
        }

        if (isLiveStatus) {
          return _ActiveJourney(
            user: user,
            trip: trip,
            student: student,
            expanded: expanded,
            onFocusRequested: onFocusRequested,
          );
        }

        if (!expanded) {
          return _CompactIdle(
            trip: trip,
            isTripToday: isTripToday,
            onFocusRequested: onFocusRequested,
          );
        }

        return ChildDayDashboard(
          user: user,
          student: student,
          trip: trip,
          isTripToday: isTripToday,
        );
      },
    );
  }
}

/// Placeholder shaped like the eventual status header — a glyph and two
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
                AppSkeleton(width: 180, height: 16),
                SizedBox(height: AppSpacing.sm),
                AppSkeleton(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The compact "nothing is moving" row for the multi-child list — one line
/// of real fact, and the way into the full view.
class _CompactIdle extends StatelessWidget {
  const _CompactIdle({
    required this.trip,
    required this.isTripToday,
    required this.onFocusRequested,
  });

  final SchoolTrip? trip;
  final bool isTripToday;
  final VoidCallback? onFocusRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final (S label, StatusTone tone) = _summary();

    return Row(
      children: [
        Icon(
          Icons.directions_bus_outlined,
          size: 20,
          color: toneColor(colors, tone),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label.of(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        if (onFocusRequested != null)
          TextButton(
            onPressed: onFocusRequested,
            child: Text(
              const S('Details', 'التفاصيل').of(context),
            ),
          ),
      ],
    );
  }

  /// The single line this row gets. A trip from a previous day is reported
  /// as "no trip today" rather than as today's, because that is what it
  /// is — `watchLatestTripForRoute` just returns the most recent one.
  (S, StatusTone) _summary() {
    final trip = this.trip;
    if (trip == null || !isTripToday) {
      return (
        const S('No trip on record today', 'مفيش رحلة مسجلة النهاردة'),
        StatusTone.neutral,
      );
    }
    switch (trip.status) {
      case TripStatus.scheduled:
        return (
          S(
            'Scheduled for ${DateFormat.jm().format(trip.scheduledAt)}',
            'متجدولة الساعة ${DateFormat.jm().format(trip.scheduledAt)}',
          ),
          StatusTone.info,
        );
      case TripStatus.cancelled:
        return (
          const S("Today's trip was cancelled", 'رحلة النهاردة اتلغت'),
          StatusTone.error,
        );
      case TripStatus.completed:
        return (
          const S("Today's trip is finished", 'رحلة النهاردة خلصت'),
          StatusTone.success,
        );
      // Live statuses never reach this widget — _TripSection routes them
      // to _ActiveJourney — but the switch stays exhaustive so a future
      // status can't silently render a blank row.
      case TripStatus.starting:
      case TripStatus.active:
      case TripStatus.paused:
      case TripStatus.emergency:
        return (
          const S('Trip in progress', 'الرحلة شغالة'),
          StatusTone.info,
        );
    }
  }
}

class _CompactFooterAction extends StatelessWidget {
  const _CompactFooterAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

/// Composes the trip's own status with the boardedStudents field and the
/// driver's live RTDB position to drive the status header, the timeline and
/// the map — all from the one [computeJourneyStage], so this card and
/// [LiveTripMap] can never disagree about where the trip is.
class _ActiveJourney extends StatelessWidget {
  const _ActiveJourney({
    required this.user,
    required this.trip,
    required this.student,
    required this.expanded,
    required this.onFocusRequested,
  });

  final AppUser user;
  final SchoolTrip trip;
  final Student student;
  final bool expanded;
  final VoidCallback? onFocusRequested;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TripStopProgress>(
      stream: StopOrderRepository().watchStopProgress(
        schoolId: user.schoolId,
        tripId: trip.id,
      ),
      builder: (context, progressSnapshot) {
        if (progressSnapshot.hasError) {
          return ErrorStateView(
            compact: true,
            message: const S(
              "Couldn't load this trip's progress — check your connection.",
              'معرفناش نحمّل تقدم الرحلة — اتأكد من الاتصال.',
            ).of(context),
          );
        }
        final progress = progressSnapshot.data ?? const TripStopProgress();
        final hasBoarded = progress.boardedStudents.contains(student.id);
        final isDroppedOff = progress.droppedOffStudents.contains(student.id);

        // Live distance only matters while the trip is actually moving —
        // every other status resolves its stage from trip.status alone.
        if (trip.status != TripStatus.active) {
          return _Body(
            user: user,
            trip: trip,
            student: student,
            hasBoarded: hasBoarded,
            distanceToPickupMeters: null,
            isDroppedOff: isDroppedOff,
            eta: null,
            expanded: expanded,
            onFocusRequested: onFocusRequested,
          );
        }

        return StreamBuilder<DatabaseEvent>(
          stream: ParentTrackingRepository().watchTripLocation(
            schoolId: user.schoolId,
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
              stream: SchoolsRepository().watchSchool(user.schoolId),
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
                if (busPosition != null &&
                    school != null &&
                    school.hasLocation) {
                  distanceToSchool = haversineMeters(
                    busPosition.latitude,
                    busPosition.longitude,
                    school.latitude!,
                    school.longitude!,
                  );
                }

                return _Body(
                  user: user,
                  trip: trip,
                  student: student,
                  hasBoarded: hasBoarded,
                  distanceToPickupMeters: distanceToPickup,
                  distanceToSchoolMeters: distanceToSchool,
                  isDroppedOff: isDroppedOff,
                  eta: computeParentTripEta(
                    tripStatus: trip.status,
                    progress: progress,
                    student: student,
                    school: school,
                    busPosition: busPosition,
                    direction: trip.direction,
                  ),
                  expanded: expanded,
                  onFocusRequested: onFocusRequested,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.user,
    required this.trip,
    required this.student,
    required this.hasBoarded,
    required this.distanceToPickupMeters,
    this.distanceToSchoolMeters,
    this.isDroppedOff = false,
    required this.eta,
    required this.expanded,
    required this.onFocusRequested,
  });

  final AppUser user;
  final SchoolTrip trip;
  final Student student;
  final bool hasBoarded;
  final double? distanceToPickupMeters;
  final double? distanceToSchoolMeters;

  // Feature: two daily trips / unified child transportation status — only
  // meaningful for a return trip (see JourneyInputs.isDroppedOff).
  final bool isDroppedOff;

  /// The shared ETA engine's answer for this child on this trip, or null
  /// while the trip isn't active (no live estimate to make).
  final ParentTripEta? eta;

  final bool expanded;
  final VoidCallback? onFocusRequested;

  @override
  Widget build(BuildContext context) {
    final stage = computeJourneyStage(
      JourneyInputs(
        tripStatus: trip.status,
        hasBoarded: hasBoarded,
        distanceToPickupMeters: distanceToPickupMeters,
        distanceToSchoolMeters: distanceToSchoolMeters,
        now: DateTime.now(),
        scheduledAt: trip.scheduledAt,
        direction: trip.direction,
        isDroppedOff: isDroppedOff,
      ),
    );

    if (!expanded) return _compact(context, stage);
    return _expanded(context, stage);
  }

  // -------------------------------------------------------------------
  // Compact — the multi-child list
  // -------------------------------------------------------------------

  Widget _compact(BuildContext context, JourneyStage stage) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final tone = stageTone(stage);
    final accent = toneColor(colors, tone);
    final etaDuration = _visibleEta(stage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StageGlyph(icon: stageIcon(stage), color: accent, size: 34),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                stageHeadline(
                  stage,
                  studentName: student.name,
                  direction: trip.direction,
                ).of(context),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.25,
                ),
              ),
            ),
            if (etaDuration != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _EtaChip(eta: etaDuration),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        JourneyProgressRail(
          stage: stage,
          hasBoarded: hasBoarded,
          direction: trip.direction,
        ),
        if (onFocusRequested != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onFocusRequested,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(
                const S('Track live', 'تابع مباشر').of(context),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------
  // Expanded — one child in full
  // -------------------------------------------------------------------

  Widget _expanded(BuildContext context, JourneyStage stage) {
    final showMap = stageIsLive(stage) && student.hasLocation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = showMap && constraints.maxWidth >= _twoPaneBreakpoint;

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusHeader(context, stage),
            const SizedBox(height: AppSpacing.md),
            _tripFacts(context),
            const SizedBox(height: AppSpacing.lg),
            JourneyTimeline(
              stage: stage,
              hasBoarded: hasBoarded,
              direction: trip.direction,
              stopNumber: eta?.stopNumber,
              totalStops: eta?.totalStops,
            ),
          ],
        );

        // A bus is out for this child but nobody has set their pickup
        // point, so there is no place to put on a map. Saying so — and
        // saying who fixes it — beats a card that just quietly has no map
        // on it while a sibling's card does.
        if (!showMap) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              if (stageIsLive(stage) && !student.hasLocation) ...[
                const SizedBox(height: AppSpacing.lg),
                _InfoBanner(
                  icon: Icons.location_off_outlined,
                  tone: StatusTone.neutral,
                  title: const S('No map yet', 'مفيش خريطة لسه').of(context),
                  subtitle: const S(
                    "Your school hasn't set a pickup point for this child, "
                        'so there is nowhere to track the bus against yet. '
                        'The steps above still update live.',
                    'المدرسة لسه ما حددتش نقطة استلام للطفل ده، فمفيش مكان '
                        'نتابع الأتوبيس بالنسبة له. الخطوات فوق لسه '
                        'بتتحدث مباشر.',
                  ).of(context),
                ),
              ],
            ],
          );
        }

        final map = LiveTripMap(
          schoolId: student.schoolId,
          tripId: trip.id,
          tripStatus: trip.status,
          student: student,
          height: twoPane ? 460 : 320,
          onOpenFullScreen: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveTripMapPage(
                schoolId: user.schoolId,
                routeId: trip.routeId,
                student: student,
              ),
            ),
          ),
        );

        if (twoPane) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: details),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 6, child: map),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // On a phone the map is the answer, so it comes first and the
            // supporting detail follows underneath it.
            map,
            const SizedBox(height: AppSpacing.lg),
            details,
          ],
        );
      },
    );
  }

  Widget _statusHeader(BuildContext context, JourneyStage stage) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final tone = stageTone(stage);
    final accent = toneColor(colors, tone);
    final etaDuration = _visibleEta(stage);
    final unavailableReason = eta?.eta.unavailableReason;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageGlyph(icon: stageIcon(stage), color: accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stageHeadline(
                  stage,
                  studentName: student.name,
                  direction: trip.direction,
                ).of(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    label: stageBadgeLabel(stage, direction: trip.direction)
                        .of(context),
                    tone: tone,
                  ),
                  if (etaDuration != null) _EtaChip(eta: etaDuration),
                ],
              ),
              // When there's no reliable ETA, say *why* rather than
              // leaving a gap where a number used to be — the shared
              // engine hands us the reason precisely so a parent isn't
              // left wondering whether the app is broken.
              if (_wantsEta(stage) &&
                  etaDuration == null &&
                  unavailableReason != null) ...[
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
    );
  }

  Widget _tripFacts(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    // Feature: two daily trips — a compact direction cue rather than a
    // separate morning/return section, folded right into the existing
    // facts line so it costs no extra vertical space.
    final facts = <String>[
      trip.direction == TripDirection.returnTrip
          ? const S('← Return home', '← رجوع للمنزل').of(context)
          : const S('→ To school', '→ للمدرسة').of(context),
      if (trip.routeName.isNotEmpty) trip.routeName,
      if (trip.busName.isNotEmpty)
        trip.busPlateNumber.isEmpty
            ? trip.busName
            : '${trip.busName} (${trip.busPlateNumber})',
      if (trip.driverName.isNotEmpty) trip.driverName,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (facts.isNotEmpty)
          Text(
            facts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        Text(
          S(
            'Scheduled ${DateFormat.jm().format(trip.scheduledAt)}'
                '${trip.startedAt != null ? ' · started ${DateFormat.jm().format(trip.startedAt!)}' : ''}',
            'متجدولة ${DateFormat.jm().format(trip.scheduledAt)}'
                '${trip.startedAt != null ? ' · بدأت ${DateFormat.jm().format(trip.startedAt!)}' : ''}',
          ).of(context),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }

  /// An ETA is only worth a number for the stages where the parent is
  /// still waiting for the bus to reach them or reach the school.
  bool _wantsEta(JourneyStage stage) =>
      stage == JourneyStage.onTheWay ||
      stage == JourneyStage.approachingPickup ||
      stage == JourneyStage.continuingToSchool;

  Duration? _visibleEta(JourneyStage stage) =>
      _wantsEta(stage) ? eta?.eta.etaToNextStop : null;
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
        ? const S('Arriving now', 'بيوصل دلوقتي').of(context)
        : S(
            'In ${eta.inMinutes} min',
            'خلال ${eta.inMinutes} د',
          ).of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: colors.info),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.info,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
