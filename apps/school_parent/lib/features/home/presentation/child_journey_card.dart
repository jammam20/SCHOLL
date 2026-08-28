import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/async_error_view.dart';
import '../../schools/data/schools_repository.dart';
import '../../students/presentation/child_settings_page.dart';
import '../../tracking/data/parent_tracking_repository.dart';
import '../../tracking/domain/eta_calculator.dart';
import '../../tracking/domain/live_bus_position.dart';
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
class ChildJourneyCard extends StatelessWidget {
  const ChildJourneyCard({super.key, required this.schoolId, required this.student});

  final String schoolId;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final avatarColor =
        _avatarColors[student.id.hashCode.abs() % _avatarColors.length];
    final initial = student.name.isEmpty ? '?' : student.name[0].toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    student.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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
                            ChildSettingsPage(schoolId: schoolId, student: student),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!student.approved)
              _InfoBanner(
                icon: Icons.hourglass_top,
                color: Colors.amber,
                title: const S('Pending approval', 'في انتظار الموافقة').of(context),
                subtitle: const S(
                  "Your school hasn't approved this child yet.",
                  'مدرستك لسه ما وافقتش على الطفل ده.',
                ).of(context),
              )
            else if (student.isAbsentToday)
              _InfoBanner(
                icon: Icons.event_busy,
                color: colors.error,
                title: const S('Absent today', 'غايب النهاردة').of(context),
                subtitle: const S(
                  "The bus will skip this child's stop today.",
                  'الأتوبيس هيتخطى محطة الطفل ده النهاردة.',
                ).of(context),
              )
            else if (student.routeId == null || student.routeId!.isEmpty)
              _InfoBanner(
                icon: Icons.route_outlined,
                color: colors.outline,
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
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
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

class _NoActiveTrip extends StatelessWidget {
  const _NoActiveTrip();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.directions_bus_outlined, color: colors.outline, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            const S(
              'No active trip right now',
              'مفيش رحلة شغالة دلوقتي',
            ).of(context),
            style: TextStyle(color: colors.onSurfaceVariant),
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
    return StreamBuilder<Set<String>>(
      stream: StopOrderRepository().watchBoardedStudents(
        schoolId: schoolId,
        tripId: trip.id,
      ),
      builder: (context, boardedSnapshot) {
        if (boardedSnapshot.hasError) return const AsyncErrorView(compact: true);
        final hasBoarded = boardedSnapshot.data?.contains(student.id) ?? false;

        // Live distance only matters while the trip is actively moving —
        // every other status resolves its stage from trip.status alone.
        if (trip.status != TripStatus.active) {
          return _Body(
            trip: trip,
            student: student,
            hasBoarded: hasBoarded,
            distanceToPickupMeters: null,
            etaToPickup: null,
          );
        }

        return StreamBuilder<DatabaseEvent>(
          stream: ParentTrackingRepository().watchTripLocation(
            schoolId: schoolId,
            tripId: trip.id,
          ),
          builder: (context, locationSnapshot) {
            if (locationSnapshot.hasError) {
              return _Body(
                trip: trip,
                student: student,
                hasBoarded: hasBoarded,
                distanceToPickupMeters: null,
                etaToPickup: null,
              );
            }

            final busPosition = LiveBusPosition.fromRtdbValue(
              locationSnapshot.data?.snapshot.value,
            );

            return StreamBuilder<School?>(
              stream: SchoolsRepository().watchSchool(schoolId),
              builder: (context, schoolSnapshot) {
                final school = schoolSnapshot.data;

                double? distanceToPickup;
                double? distanceToSchool;
                Duration? etaToPickup;
                if (busPosition != null && student.hasLocation) {
                  distanceToPickup = haversineMeters(
                    busPosition.latitude,
                    busPosition.longitude,
                    student.latitude!,
                    student.longitude!,
                  );
                  etaToPickup = estimateEta(
                    distanceMeters: distanceToPickup,
                    reportedSpeedMetersPerSecond: busPosition.speedMetersPerSecond,
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
                  etaToPickup: etaToPickup,
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
    required this.trip,
    required this.student,
    required this.hasBoarded,
    required this.distanceToPickupMeters,
    this.distanceToSchoolMeters,
    required this.etaToPickup,
  });

  final SchoolTrip trip;
  final Student student;
  final bool hasBoarded;
  final double? distanceToPickupMeters;
  final double? distanceToSchoolMeters;
  final Duration? etaToPickup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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

    final showMap =
        trip.status == TripStatus.active ||
        trip.status == TripStatus.starting ||
        trip.status == TripStatus.paused ||
        trip.status == TripStatus.emergency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _stageHeadline(stage).of(context),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (stage == JourneyStage.onTheWay ||
                stage == JourneyStage.approachingPickup)
              _EtaChip(eta: etaToPickup),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          S(
            '${trip.routeName.isEmpty ? 'Route' : trip.routeName} · '
                '${trip.busName} (${trip.busPlateNumber}) · ${trip.driverName}',
            '${trip.routeName.isEmpty ? 'الخط' : trip.routeName} · '
                '${trip.busName} (${trip.busPlateNumber}) · ${trip.driverName}',
          ).of(context),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        Text(
          DateFormat.jm().format(trip.scheduledAt),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        JourneyTimeline(stage: stage, hasBoarded: hasBoarded),
        if (showMap) ...[
          const SizedBox(height: 4),
          LiveTripMap(
            schoolId: student.schoolId,
            tripId: trip.id,
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

class _EtaChip extends StatelessWidget {
  const _EtaChip({required this.eta});

  final Duration? eta;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = eta == null
        ? const S('ETA unavailable', 'الوقت المتوقع مش متاح').of(context)
        : eta!.inMinutes < 1
        ? const S('Arriving soon', 'هيوصل قريب').of(context)
        : S(
            'Arriving in ${eta!.inMinutes} min',
            'هيوصل خلال ${eta!.inMinutes} د',
          ).of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
