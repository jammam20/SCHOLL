import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/reports_repository.dart';

/// Real, computed operational reports — attendance and trip performance —
/// built entirely from data the app already writes (absenceLog entries,
/// and each trip's scheduledAt/startedAt/completedAt/status). Nothing
/// here is a placeholder metric: on-time rate and average trip duration
/// only exist because the driver app now stamps startedAt/completedAt
/// when a trip actually starts/finishes (see TripsBloc).
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int _rangeDays = 7;

  @override
  Widget build(BuildContext context) {
    final since = DateTime.now().subtract(Duration(days: _rangeDays));

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Reports', 'التقارير').of(context)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 7,
                        label: Text(const S('7 days', '7 أيام').of(context)),
                      ),
                      ButtonSegment(
                        value: 30,
                        label: Text(const S('30 days', '30 يوم').of(context)),
                      ),
                    ],
                    selected: {_rangeDays},
                    onSelectionChanged: (value) =>
                        setState(() => _rangeDays = value.first),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ReportsRepository().watchTripsSince(
                widget.schoolId,
                since: since,
              ),
              builder: (context, tripsSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ReportsRepository().watchAttendanceRecordsSince(
                    widget.schoolId,
                    since: since,
                  ),
                  builder: (context, attendanceSnapshot) {
                    if (tripsSnapshot.hasError || attendanceSnapshot.hasError) {
                      return ErrorStateView(onRetry: () => setState(() {}));
                    }
                    if (!tripsSnapshot.hasData || !attendanceSnapshot.hasData) {
                      return const _ReportsLoadingSkeleton();
                    }

                    final trips = tripsSnapshot.data!.docs
                        .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
                        .toList();
                    // Feature: absence data integrity — one canonical
                    // record per (student, day), so this is already
                    // deduplicated; no student/day is counted twice no
                    // matter how many times it was toggled.
                    final absences = attendanceSnapshot.data!.docs
                        .map((doc) => AttendanceRecord.fromMap(doc.data()))
                        .where((record) => record.isAbsent)
                        .toList();

                    return _ReportsBody(trips: trips, absences: absences);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Matches the eventual dashboard's shape (two rows of stat cards, then a
/// few list rows) so the loading state doesn't jump/reflow once real data
/// arrives. See `design-system/MASTER.md` §9.
class _ReportsLoadingSkeleton extends StatelessWidget {
  const _ReportsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Widget statSkeleton() => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 90, height: 12),
            SizedBox(height: AppSpacing.sm),
            AppSkeleton(width: 56, height: 22),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl2,
      ),
      children: [
        Row(
          children: [
            statSkeleton(),
            const SizedBox(width: AppSpacing.md),
            statSkeleton(),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            statSkeleton(),
            const SizedBox(width: AppSpacing.md),
            statSkeleton(),
          ],
        ),
        const SizedBox(height: AppSpacing.xl3),
        const AppSkeletonListTile(),
        const AppSkeletonListTile(),
        const AppSkeletonListTile(),
      ],
    );
  }
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.trips, required this.absences});

  final List<SchoolTrip> trips;
  final List<AttendanceRecord> absences;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final completed = trips.where((t) => t.status == TripStatus.completed).toList();
    final cancelled = trips.where((t) => t.status == TripStatus.cancelled).length;
    final emergencies = trips.where((t) => t.status == TripStatus.emergency).length;
    final finished = completed.length + cancelled;
    final completionRate = finished == 0 ? null : completed.length / finished;

    final onTimeGrace = const Duration(minutes: 10);
    final withStart = completed.where((t) => t.startedAt != null).toList();
    final onTime = withStart
        .where((t) => t.startedAt!.difference(t.scheduledAt) <= onTimeGrace)
        .length;
    final onTimeRate = withStart.isEmpty ? null : onTime / withStart.length;

    final durations = completed
        .where((t) => t.startedAt != null && t.completedAt != null)
        .map((t) => t.completedAt!.difference(t.startedAt!))
        .toList();
    final avgDuration = durations.isEmpty
        ? null
        : Duration(
            seconds:
                durations.fold<int>(0, (total, d) => total + d.inSeconds) ~/
                    durations.length,
          );

    final absenceCounts = <String, int>{};
    for (final entry in absences) {
      final name = entry.studentName.isEmpty ? '—' : entry.studentName;
      absenceCounts[name] = (absenceCounts[name] ?? 0) + 1;
    }
    final topAbsent = absenceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final driverStats = <String, _DriverStats>{};
    for (final trip in trips) {
      if (trip.driverId.isEmpty) continue;
      final stats = driverStats.putIfAbsent(
        trip.driverId,
        () => _DriverStats(trip.driverName),
      );
      if (trip.status == TripStatus.completed) stats.completed++;
      if (trip.status == TripStatus.emergency) stats.emergencies++;
      if (trip.startedAt != null && trip.completedAt != null) {
        stats.durations.add(trip.completedAt!.difference(trip.startedAt!));
      }
    }
    final driverEntries = driverStats.values.toList()
      ..sort((a, b) => b.completed.compareTo(a.completed));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl2,
      ),
      children: [
        SectionHeader(
          title: const S('Trip performance', 'أداء الرحلات').of(context),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricStatCard(
                  icon: Icons.task_alt,
                  tone: colors.success,
                  label: const S('Completion rate', 'نسبة الإنجاز').of(context),
                  value: completionRate == null
                      ? '—'
                      : '${(completionRate * 100).round()}%',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricStatCard(
                  icon: Icons.schedule,
                  tone: colors.info,
                  label: const S('On-time rate', 'نسبة الالتزام بالمعاد').of(context),
                  value: onTimeRate == null ? '—' : '${(onTimeRate * 100).round()}%',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricStatCard(
                  icon: Icons.timer_outlined,
                  label: const S('Avg. trip duration', 'متوسط مدة الرحلة').of(context),
                  value: avgDuration == null ? '—' : _formatDuration(avgDuration),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricStatCard(
                  icon: Icons.warning_amber_rounded,
                  tone: colors.emergency,
                  label: const S('Emergencies', 'حالات الطوارئ').of(context),
                  value: '$emergencies',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl3),
        SectionHeader(
          title: const S('Attendance', 'الحضور والغياب').of(context),
        ),
        SizedBox(
          width: double.infinity,
          child: MetricStatCard(
            icon: Icons.event_busy,
            tone: colors.warning,
            label: const S(
              'Total absences in range',
              'إجمالي الغياب في المدة دي',
            ).of(context),
            value: '${absences.length}',
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        Text(
          const S('Most frequently absent', 'الأكتر غيابًا').of(context),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (topAbsent.isEmpty)
          EmptyStateView(
            compact: true,
            icon: Icons.event_available_outlined,
            title: const S(
              'No absences recorded in this range.',
              'مفيش غياب متسجل في المدة دي.',
            ).of(context),
          )
        else
          _RankedBars(
            entries: topAbsent
                .take(5)
                .map((e) => MapEntry(e.key, e.value))
                .toList(),
          ),
        const SizedBox(height: AppSpacing.xl3),
        SectionHeader(
          title: const S('By driver', 'حسب السواق').of(context),
        ),
        if (driverEntries.isEmpty)
          EmptyStateView(
            compact: true,
            icon: Icons.event_busy_outlined,
            title: const S(
              'No trips scheduled in this range.',
              'مفيش رحلات متجدولة في المدة دي.',
            ).of(context),
          )
        else
          ...driverEntries.map(
            (stats) => Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.badge)),
                title: Text(
                  stats.name.isEmpty
                      ? const S('Unknown driver', 'سائق غير معروف').of(context)
                      : stats.name,
                ),
                subtitle: Text(
                  S(
                    '${stats.completed} completed'
                        '${stats.emergencies > 0 ? ' · ${stats.emergencies} emergency' : ''}'
                        '${stats.avgDuration != null ? ' · avg ${_formatDuration(stats.avgDuration!)}' : ''}',
                    '${stats.completed} رحلة مكتملة'
                        '${stats.emergencies > 0 ? ' · ${stats.emergencies} طوارئ' : ''}'
                        '${stats.avgDuration != null ? ' · متوسط ${_formatDuration(stats.avgDuration!)}' : ''}',
                  ).of(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

class _DriverStats {
  _DriverStats(this.name);
  final String name;
  int completed = 0;
  int emergencies = 0;
  final List<Duration> durations = [];

  Duration? get avgDuration {
    if (durations.isEmpty) return null;
    return Duration(
      seconds: durations.fold<int>(0, (total, d) => total + d.inSeconds) ~/
          durations.length,
    );
  }
}

class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.entries});

  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    final maxValue = entries.first.value;
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    entry.key,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / maxValue,
                      minHeight: 14,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${entry.value}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
