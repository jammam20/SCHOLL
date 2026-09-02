import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../analytics/presentation/analytics_tab.dart';
import '../../audit/presentation/audit_trail_page.dart';
import '../../buses/data/buses_repository.dart';
import '../../common/presentation/domain_labels.dart';
import '../../deviations/data/deviations_repository.dart';
import '../../drivers/data/drivers_repository.dart';
import '../../emergencies/data/emergencies_repository.dart';
import '../../incidents/data/incidents_repository.dart';
import '../../parents/data/parents_repository.dart';
import '../../search/presentation/global_search_page.dart';
import '../../students/data/students_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../../../widgets/async_error_view.dart';

/// Where an alert in the feed sends the admin when tapped. Tab jumps go
/// through the same index-based mechanism `NotificationRouting` already
/// uses in admin_home_page.dart, rather than a second navigation concept.
enum DashboardJumpTarget { liveOps, incidents, deviations, people, operations }

/// The operations control centre: live fleet, student and route counts
/// across the top, a single ranked alert feed underneath, and the existing
/// analytics charts below that.
///
/// Every number here is counted from data the app already writes. Where a
/// figure genuinely can't be derived it shows "—" rather than a zero that
/// would read as "nothing wrong".
class ControlCenterTab extends StatelessWidget {
  const ControlCenterTab({
    super.key,
    required this.user,
    required this.onJump,
    this.readOnly = false,
  });

  final AppUser user;

  /// Switches the host page to the tab that owns the tapped alert.
  final void Function(DashboardJumpTarget target) onJump;

  /// Staff see the same read-only picture with no management shortcuts.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final schoolId = user.schoolId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          readOnly
              ? const S('Today', 'النهارده').of(context)
              : const S('Control centre', 'مركز التحكم').of(context),
        ),
        actions: [
          if (!readOnly)
            IconButton(
              tooltip: const S('Audit trail', 'سجل التدقيق').of(context),
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuditTrailPage(schoolId: schoolId),
                ),
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    0,
                  ),
                  child: SectionHeader(
                    title: S(
                      'Welcome back, ${user.name}',
                      'أهلاً بيك تاني، ${user.name}',
                    ).of(context),
                    subtitle: const S(
                      "Here's a snapshot of your school today.",
                      'لمحة سريعة عن مدرستك النهارده.',
                    ).of(context),
                  ),
                ),
              ),
            ),
          ),
          if (!readOnly)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: _QuickActionsRow(schoolId: schoolId, onJump: onJump),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: _LiveOperationsSection(
                  schoolId: schoolId,
                  onJump: onJump,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: AnalyticsTab(schoolId: schoolId),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feature: dashboard quick actions. Compact, real-data shortcuts to the
/// screens an admin reaches for most — never fake counts, and the pending-
/// requests badge is the exact same "awaiting approval" set the People
/// tab's own PendingApprovalCard rows show, just counted here for the
/// dashboard.
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.schoolId, required this.onJump});

  final String schoolId;
  final void Function(DashboardJumpTarget target) onJump;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: const S('Quick actions', 'إجراءات سريعة').of(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _QuickActionChip(
              icon: Icons.search,
              label: const S('Search', 'بحث').of(context),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GlobalSearchPage(schoolId: schoolId),
                ),
              ),
            ),
            _QuickActionChip(
              icon: Icons.map_outlined,
              label: const S('Live map', 'الخريطة المباشرة').of(context),
              onTap: () => onJump(DashboardJumpTarget.liveOps),
            ),
            _PendingRequestsChip(schoolId: schoolId, onJump: onJump),
            _QuickActionChip(
              icon: Icons.groups_outlined,
              label: const S('Add student / driver / parent', 'إضافة طالب / سائق / ولي أمر')
                  .of(context),
              onTap: () => onJump(DashboardJumpTarget.people),
            ),
            _QuickActionChip(
              icon: Icons.directions_bus_outlined,
              label: const S('Add bus / route', 'إضافة أتوبيس / خط').of(context),
              onTap: () => onJump(DashboardJumpTarget.operations),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: colors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.warning,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Real pending count — every student awaiting approval plus every driver/
/// parent with `status == 'pending'`, from the same repositories (and the
/// same 200-row ceiling) the People tab's own lists already use.
class _PendingRequestsChip extends StatelessWidget {
  const _PendingRequestsChip({required this.schoolId, required this.onJump});

  final String schoolId;
  final void Function(DashboardJumpTarget target) onJump;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: StudentsRepository().watchStudents(schoolId, limit: 300),
      builder: (context, studentsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: DriversRepository().watchDrivers(schoolId, limit: 200),
          builder: (context, driversSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ParentsRepository().watchParents(schoolId, limit: 200),
              builder: (context, parentsSnapshot) {
                final pendingStudents = (studentsSnapshot.data?.docs ?? const [])
                    .where((doc) => doc.data()['approved'] == false)
                    .length;
                final pendingDrivers = (driversSnapshot.data?.docs ?? const [])
                    .where((doc) => doc.data()['status'] == 'pending')
                    .length;
                final pendingParents = (parentsSnapshot.data?.docs ?? const [])
                    .where((doc) => doc.data()['status'] == 'pending')
                    .length;
                final total = pendingStudents + pendingDrivers + pendingParents;

                return _QuickActionChip(
                  icon: Icons.pending_actions_outlined,
                  label: const S('Pending requests', 'الطلبات المعلّقة')
                      .of(context),
                  badge: total,
                  onTap: () => onJump(DashboardJumpTarget.people),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// The live counts + alert feed. One place, so the numbers and the alerts
/// are always computed from the same snapshot of the same streams.
class _LiveOperationsSection extends StatelessWidget {
  const _LiveOperationsSection({required this.schoolId, required this.onJump});

  final String schoolId;
  final void Function(DashboardJumpTarget target) onJump;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchTrips(schoolId),
      builder: (context, tripsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: StudentsRepository().watchStudents(schoolId, limit: 300),
          builder: (context, studentsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: BusesRepository().watchBuses(schoolId),
              builder: (context, busesSnapshot) {
                if (tripsSnapshot.hasError ||
                    studentsSnapshot.hasError ||
                    busesSnapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: AsyncErrorView(),
                  );
                }
                if (!tripsSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        AppSkeletonListTile(),
                        AppSkeletonListTile(),
                        AppSkeletonListTile(),
                      ],
                    ),
                  );
                }

                final trips = tripsSnapshot.data!.docs
                    .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
                    .toList();
                final tripDocs = {
                  for (final doc in tripsSnapshot.data!.docs)
                    doc.id: doc.data(),
                };
                final students = (studentsSnapshot.data?.docs ?? const [])
                    .map((doc) => Student.fromMap(doc.id, doc.data()))
                    .toList();
                final buses = (busesSnapshot.data?.docs ?? const [])
                    .map((doc) => SchoolBus.fromMap(doc.id, doc.data()))
                    .toList();

                final snapshot = _OperationsSnapshot.from(
                  trips: trips,
                  tripDocs: tripDocs,
                  students: students,
                  buses: buses,
                );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FleetCounts(snapshot: snapshot),
                      const SizedBox(height: AppSpacing.xl2),
                      _StudentCounts(snapshot: snapshot),
                      const SizedBox(height: AppSpacing.xl2),
                      _AlertFeed(schoolId: schoolId, onJump: onJump),
                    ],
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

/// Today's operational picture, derived purely from records already read.
class _OperationsSnapshot {
  const _OperationsSnapshot({
    required this.totalBuses,
    required this.activeBuses,
    required this.busesOnRoad,
    required this.busesInEmergency,
    required this.notStarted,
    required this.likelyDelayed,
    required this.completedToday,
    required this.expectedStudents,
    required this.boardedStudents,
    required this.droppedOffStudents,
    required this.absentStudents,
    required this.onTimeRate,
    required this.busesWithExpiringDocs,
  });

  /// A scheduled trip is treated as "likely delayed" once it is more than
  /// this far past its scheduled time without having started. It is a
  /// heuristic, and is labelled as one in the UI — the system records no
  /// authoritative "this trip is late" flag.
  static const delayGrace = Duration(minutes: 10);

  factory _OperationsSnapshot.from({
    required List<SchoolTrip> trips,
    required Map<String, Map<String, dynamic>> tripDocs,
    required List<Student> students,
    required List<SchoolBus> buses,
  }) {
    final now = DateTime.now();
    bool isToday(DateTime date) =>
        date.year == now.year && date.month == now.month && date.day == now.day;

    final todaysTrips = trips
        .where((trip) => isToday(trip.scheduledAt))
        .toList();

    final onRoad = todaysTrips
        .where(
          (trip) =>
              trip.status == TripStatus.active ||
              trip.status == TripStatus.starting ||
              trip.status == TripStatus.paused ||
              trip.status == TripStatus.emergency,
        )
        .toList();

    final notStarted = todaysTrips
        .where((trip) => trip.status == TripStatus.scheduled)
        .toList();

    final delayed = notStarted
        .where((trip) => now.difference(trip.scheduledAt) > delayGrace)
        .length;

    final completed = todaysTrips
        .where((trip) => trip.status == TripStatus.completed)
        .toList();

    // Boarding counts come from the live trip documents' own arrays, which
    // is the only place this state exists.
    final boarded = <String>{};
    final droppedOff = <String>{};
    for (final trip in [...onRoad, ...completed]) {
      final data = tripDocs[trip.id];
      if (data == null) continue;
      boarded.addAll(
        List<String>.from(data['boardedStudents'] as List? ?? const []),
      );
      droppedOff.addAll(
        List<String>.from(data['droppedOffStudents'] as List? ?? const []),
      );
    }

    final activeStudents = students
        .where((student) => student.isActive && student.approved)
        .toList();
    final absent = activeStudents.where((s) => s.isAbsentToday).length;

    // "Expected" = active, approved, assigned to a route, and not marked
    // absent today. A student with no route rides no trip, so counting
    // them as expected would overstate every boarding figure.
    final expected = activeStudents
        .where(
          (student) =>
              !student.isAbsentToday &&
              student.routeId != null &&
              student.routeId!.isNotEmpty,
        )
        .length;

    final startedToday = completed
        .where((trip) => trip.startedAt != null)
        .toList();
    final onTime = startedToday
        .where(
          (trip) =>
              trip.startedAt!.difference(trip.scheduledAt) <=
              const Duration(minutes: 10),
        )
        .length;

    return _OperationsSnapshot(
      totalBuses: buses.length,
      activeBuses: buses.where((bus) => bus.isActive).length,
      busesOnRoad: onRoad.length,
      busesInEmergency: onRoad
          .where((trip) => trip.status == TripStatus.emergency)
          .length,
      notStarted: notStarted.length,
      likelyDelayed: delayed,
      completedToday: completed.length,
      expectedStudents: expected,
      boardedStudents: boarded.length,
      droppedOffStudents: droppedOff.length,
      absentStudents: absent,
      onTimeRate: startedToday.isEmpty ? null : onTime / startedToday.length,
      busesWithExpiringDocs: buses
          .where((bus) => bus.hasExpiringDocuments(now))
          .length,
    );
  }

  final int totalBuses;
  final int activeBuses;
  final int busesOnRoad;
  final int busesInEmergency;
  final int notStarted;
  final int likelyDelayed;
  final int completedToday;
  final int expectedStudents;
  final int boardedStudents;
  final int droppedOffStudents;
  final int absentStudents;

  /// Null when no trip has both started and completed today — genuinely
  /// unknown, not 0%.
  final double? onTimeRate;
  final int busesWithExpiringDocs;

  /// Expected students who are neither boarded nor already dropped off.
  int get pendingStudents {
    final handled = boardedStudents;
    final pending = expectedStudents - handled;
    return pending < 0 ? 0 : pending;
  }
}

class _FleetCounts extends StatelessWidget {
  const _FleetCounts({required this.snapshot});

  final _OperationsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final cards = [
      MetricStatCard(
        icon: Icons.directions_bus_filled,
        tone: colors.info,
        label: const S('Buses on the road', 'أتوبيسات على الطريق').of(context),
        value: '${snapshot.busesOnRoad}',
      ),
      MetricStatCard(
        icon: Icons.warning_amber_rounded,
        tone: snapshot.busesInEmergency > 0
            ? colors.emergency
            : colors.success,
        label: const S('In emergency', 'في حالة طوارئ').of(context),
        value: '${snapshot.busesInEmergency}',
      ),
      MetricStatCard(
        icon: Icons.running_with_errors_outlined,
        tone: snapshot.likelyDelayed > 0 ? colors.warning : colors.success,
        label: const S(
          'Likely delayed (heuristic)',
          'غالباً متأخرة (تقديري)',
        ).of(context),
        value: '${snapshot.likelyDelayed}',
      ),
      MetricStatCard(
        icon: Icons.schedule_outlined,
        label: const S('Not started yet', 'لسه مبدأتش').of(context),
        value: '${snapshot.notStarted}',
      ),
      MetricStatCard(
        icon: Icons.task_alt,
        tone: colors.success,
        label: const S('Completed today', 'اكتملت النهارده').of(context),
        value: '${snapshot.completedToday}',
      ),
      MetricStatCard(
        icon: Icons.timelapse,
        tone: colors.info,
        label: const S(
          'On-time rate today',
          'الالتزام بالمعاد النهارده',
        ).of(context),
        value: snapshot.onTimeRate == null
            ? '—'
            : '${(snapshot.onTimeRate! * 100).round()}%',
      ),
      MetricStatCard(
        icon: Icons.fact_check_outlined,
        tone: snapshot.busesWithExpiringDocs > 0
            ? colors.warning
            : colors.success,
        label: const S(
          'Vehicles with expiring docs',
          'مركبات أوراقها قربت تنتهي',
        ).of(context),
        value: '${snapshot.busesWithExpiringDocs}',
      ),
      MetricStatCard(
        icon: Icons.garage_outlined,
        label: const S('Active fleet', 'الأسطول النشط').of(context),
        value: '${snapshot.activeBuses} / ${snapshot.totalBuses}',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: const S('Fleet right now', 'الأسطول دلوقتي').of(context),
        ),
        _StatGrid(cards: cards),
      ],
    );
  }
}

class _StudentCounts extends StatelessWidget {
  const _StudentCounts({required this.snapshot});

  final _OperationsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final cards = [
      MetricStatCard(
        icon: Icons.groups,
        label: const S('Expected today', 'المتوقعين النهارده').of(context),
        value: '${snapshot.expectedStudents}',
      ),
      MetricStatCard(
        icon: Icons.how_to_reg,
        tone: colors.success,
        label: const S('Boarded', 'ركبوا').of(context),
        value: '${snapshot.boardedStudents}',
      ),
      MetricStatCard(
        icon: Icons.logout,
        tone: colors.info,
        label: const S('Dropped off', 'نزلوا').of(context),
        value: '${snapshot.droppedOffStudents}',
      ),
      MetricStatCard(
        icon: Icons.hourglass_bottom,
        tone: colors.warning,
        label: const S('Still pending', 'لسه في الانتظار').of(context),
        value: '${snapshot.pendingStudents}',
      ),
      MetricStatCard(
        icon: Icons.event_busy,
        tone: colors.textMuted,
        label: const S('Absent today', 'غايبين النهارده').of(context),
        value: '${snapshot.absentStudents}',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: const S('Students today', 'الطلاب النهارده').of(context),
          subtitle: const S(
            'Counted from today’s trips’ own boarding records.',
            'محسوبة من سجلات ركوب رحلات النهارده نفسها.',
          ).of(context),
        ),
        _StatGrid(cards: cards),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final columns = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 720
            ? 3
            : 2;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

/// One ranked feed of everything currently demanding attention: active
/// emergencies first, then live deviations, then open incidents. Each row
/// jumps to the surface that owns it.
class _AlertFeed extends StatelessWidget {
  const _AlertFeed({required this.schoolId, required this.onJump});

  final String schoolId;
  final void Function(DashboardJumpTarget target) onJump;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: EmergenciesRepository().watchActiveEmergencies(schoolId),
      builder: (context, emergenciesSnapshot) {
        return StreamBuilder<List<SchoolIncident>>(
          stream: IncidentsRepository().watchOpenIncidents(schoolId),
          builder: (context, incidentsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DeviationsRepository().watchDeviationHistory(
                schoolId,
                limit: 50,
              ),
              builder: (context, deviationsSnapshot) {
                final emergencies = (emergenciesSnapshot.data?.docs ?? const [])
                    .map((doc) => SchoolEmergency.fromMap(doc.id, doc.data()))
                    .toList();
                final incidents = incidentsSnapshot.data ?? const [];
                // Recent closed deviation episodes — the *live* ones are
                // surfaced on the map itself (which subscribes per trip);
                // here the feed shows what happened recently so a pattern
                // is visible from the dashboard.
                final now = DateTime.now();
                final recentDeviations =
                    (deviationsSnapshot.data?.docs ?? const [])
                        .map(
                          (doc) =>
                              DeviationRecord.fromMap(doc.id, doc.data()),
                        )
                        .where(
                          (record) =>
                              now.difference(record.startedAt) <
                              const Duration(hours: 24),
                        )
                        .toList();

                final hasAny =
                    emergencies.isNotEmpty ||
                    incidents.isNotEmpty ||
                    recentDeviations.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: const S('Alerts', 'التنبيهات').of(context),
                      subtitle: hasAny
                          ? const S(
                              'Tap an alert to open it.',
                              'دوس على التنبيه عشان تفتحه.',
                            ).of(context)
                          : null,
                    ),
                    if (!hasAny)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: colors.success,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                const S(
                                  'Nothing needs attention right now.',
                                  'مفيش حاجة محتاجة انتباه دلوقتي.',
                                ).of(context),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: colors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final emergency in emergencies)
                              _AlertRow(
                                icon: Icons.sos_outlined,
                                tone: StatusTone.emergency,
                                title: emergencyTypeLabel(
                                  emergency.type,
                                  context,
                                ),
                                subtitle: S(
                                  'SOS raised at '
                                      '${DateFormat.jm().format(emergency.createdAt)}'
                                      '${emergency.driverNote == null ? '' : ' · ${emergency.driverNote}'}',
                                  'استغاثة الساعة '
                                      '${DateFormat.jm().format(emergency.createdAt)}'
                                      '${emergency.driverNote == null ? '' : ' · ${emergency.driverNote}'}',
                                ).of(context),
                                onTap: () =>
                                    onJump(DashboardJumpTarget.liveOps),
                              ),
                            for (final incident in incidents)
                              _AlertRow(
                                icon: incidentTypeIcon(incident.type),
                                tone: incidentStatusTone(incident.status),
                                title: incidentTypeLabel(
                                  incident.type,
                                  context,
                                ),
                                subtitle: S(
                                  '${incidentStatusLabel(incident.status, context)}'
                                      ' · '
                                      '${DateFormat.MMMd().add_jm().format(incident.createdAt)}',
                                  '${incidentStatusLabel(incident.status, context)}'
                                      ' · '
                                      '${DateFormat.MMMd().add_jm().format(incident.createdAt)}',
                                ).of(context),
                                onTap: () =>
                                    onJump(DashboardJumpTarget.incidents),
                              ),
                            for (final deviation in recentDeviations)
                              _AlertRow(
                                icon: Icons.alt_route,
                                tone: StatusTone.warning,
                                title: const S(
                                  'Route deviation',
                                  'خروج عن المسار',
                                ).of(context),
                                subtitle: S(
                                  'Up to ${deviation.maxDeviationMeters.round()} m '
                                      'off path · '
                                      '${DateFormat.MMMd().add_jm().format(deviation.startedAt)}',
                                  'لحد ${deviation.maxDeviationMeters.round()} متر '
                                      'عن المسار · '
                                      '${DateFormat.MMMd().add_jm().format(deviation.startedAt)}',
                                ).of(context),
                                onTap: () =>
                                    onJump(DashboardJumpTarget.deviations),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final StatusTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = toneColor(colors, tone);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
