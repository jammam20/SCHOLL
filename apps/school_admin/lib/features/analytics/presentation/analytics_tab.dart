import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../buses/data/buses_repository.dart';
import '../../drivers/data/drivers_repository.dart';
import '../../routes/data/routes_repository.dart';
import '../../students/data/students_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../../../widgets/async_error_view.dart';
import 'safety_analytics_section.dart';

/// Live operational analytics for a school: trip status mix, driver
/// approval breakdown, trip volume over the last 7 days, and student load
/// per route. Every chart is built from the same collections the other
/// admin tabs already read (trips/students/drivers/routes), so nothing new
/// needs to be written to Firestore for this tab to work.
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key, required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchTrips(schoolId),
      builder: (context, tripsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: StudentsRepository().watchStudents(schoolId),
          builder: (context, studentsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DriversRepository().watchDrivers(schoolId),
              builder: (context, driversSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: BusesRepository().watchBuses(schoolId),
                  builder: (context, busesSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: RoutesRepository().watchRoutes(schoolId),
                      builder: (context, routesSnapshot) {
                        final stillLoading = [
                          tripsSnapshot,
                          studentsSnapshot,
                          driversSnapshot,
                          busesSnapshot,
                          routesSnapshot,
                        ].any((s) => !s.hasData && !s.hasError);

                        if (stillLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final hasError = [
                          tripsSnapshot,
                          studentsSnapshot,
                          driversSnapshot,
                          busesSnapshot,
                          routesSnapshot,
                        ].any((s) => s.hasError);
                        if (hasError) return const AsyncErrorView();

                        return _AnalyticsBody(
                          schoolId: schoolId,
                          trips: (tripsSnapshot.data?.docs ?? const [])
                              .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
                              .toList(),
                          activeStudentCount: (studentsSnapshot.data?.docs ?? const [])
                              .where((doc) => doc.data()['isActive'] == true)
                              .length,
                          studentRouteIds: (studentsSnapshot.data?.docs ?? const [])
                              .where((doc) => doc.data()['isActive'] == true)
                              .map((doc) => doc.data()['routeId'] as String?)
                              .whereType<String>()
                              .where((id) => id.isNotEmpty)
                              .toList(),
                          driverStatuses: (driversSnapshot.data?.docs ?? const [])
                              .map((doc) => doc.data()['status'] as String? ?? 'pending')
                              .toList(),
                          activeBusCount: (busesSnapshot.data?.docs ?? const [])
                              .where((doc) => doc.data()['isActive'] == true)
                              .length,
                          routeNames: {
                            for (final doc in routesSnapshot.data?.docs ?? const [])
                              doc.id: (doc.data()['name'] as String?) ?? doc.id,
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({
    required this.schoolId,
    required this.trips,
    required this.activeStudentCount,
    required this.studentRouteIds,
    required this.driverStatuses,
    required this.activeBusCount,
    required this.routeNames,
  });

  final String schoolId;
  final List<SchoolTrip> trips;
  final int activeStudentCount;
  final List<String> studentRouteIds;
  final List<String> driverStatuses;
  final int activeBusCount;
  final Map<String, String> routeNames;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final tripsToday = trips
        .where(
          (trip) =>
              trip.scheduledAt.year == today.year &&
              trip.scheduledAt.month == today.month &&
              trip.scheduledAt.day == today.day,
        )
        .length;
    final approvedDrivers = driverStatuses.where((s) => s == 'approved').length;
    final appColors = context.appColors;

    final statCards = [
      MetricStatCard(
        label: const S('Active students', 'الطلاب النشطين').of(context),
        value: '$activeStudentCount',
        icon: Icons.people,
        tone: appColors.info,
      ),
      MetricStatCard(
        label: const S('Active buses', 'الأتوبيسات النشطة').of(context),
        value: '$activeBusCount',
        icon: Icons.directions_bus,
        tone: appColors.success,
      ),
      MetricStatCard(
        label: const S('Approved drivers', 'السائقين المعتمدين').of(context),
        value: '$approvedDrivers',
        icon: Icons.badge,
        tone: appColors.success,
      ),
      MetricStatCard(
        label: const S('Trips today', 'رحلات النهارده').of(context),
        value: '$tripsToday',
        icon: Icons.today,
      ),
    ];

    // This tab is embedded directly in the dashboard's own scroll view (see
    // admin_home_page.dart's _DashboardTab), so it lays out as a plain
    // Column rather than owning a second, nested scrollable.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // A responsive stat-card grid: 4-across on a wide desktop/web
              // viewport, wrapping down to 2-across on narrower ones,
              // instead of a fixed 2x2 that just stretches — see
              // design-system/MASTER.md §11.
              const spacing = AppSpacing.md;
              final columns = constraints.maxWidth >= 720 ? 4 : 2;
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final card in statCards)
                    SizedBox(width: cardWidth, child: card),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl2),
          SectionHeader(
            title: const S('Trip status mix', 'توزيع حالات الرحلات').of(context),
          ),
          _TripStatusChart(trips: trips),
          const SizedBox(height: AppSpacing.xl2),
          SectionHeader(
            title: const S(
              'Trip volume, last 7 days',
              'حجم الرحلات آخر 7 أيام',
            ).of(context),
          ),
          _WeeklyVolumeChart(trips: trips),
          const SizedBox(height: AppSpacing.xl2),
          SectionHeader(
            title: const S('Students per route', 'الطلاب في كل خط').of(context),
          ),
          _StudentsPerRouteChart(routeIds: studentRouteIds, routeNames: routeNames),
          const SizedBox(height: AppSpacing.xl2),
          SectionHeader(
            title: const S(
              'Driver approval status',
              'حالة اعتماد السائقين',
            ).of(context),
          ),
          _DriverStatusChart(statuses: driverStatuses),
          // Safety analytics (incidents over time, deviation frequency by
          // route, and pickup verification when that data exists) live in
          // their own file so this tab stays about the fleet/people mix.
          SafetyAnalyticsSection(schoolId: schoolId),
        ],
      ),
    );
  }
}

const _statusColors = {
  TripStatus.scheduled: Colors.blueGrey,
  TripStatus.starting: Colors.amber,
  TripStatus.active: Colors.green,
  TripStatus.paused: Colors.orange,
  TripStatus.completed: Colors.blue,
  TripStatus.cancelled: Colors.grey,
  TripStatus.emergency: Colors.red,
};

class _TripStatusChart extends StatelessWidget {
  const _TripStatusChart({required this.trips});

  final List<SchoolTrip> trips;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return EmptyStateView(
        compact: true,
        icon: Icons.pie_chart_outline,
        title: const S('No trips scheduled yet.', 'مفيش رحلات متجدولة لسه.').of(context),
      );
    }

    final counts = <TripStatus, int>{};
    for (final trip in trips) {
      counts[trip.status] = (counts[trip.status] ?? 0) + 1;
    }

    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 32,
                sections: [
                  for (final entry in counts.entries)
                    PieChartSectionData(
                      value: entry.value.toDouble(),
                      color: _statusColors[entry.key],
                      title: '${entry.value}',
                      radius: 56,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in counts.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _statusColors[entry.key],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${entry.key.name} (${entry.value})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({required this.trips});

  final List<SchoolTrip> trips;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - index)),
    );

    final countsByDay = [
      for (final day in days)
        trips
            .where(
              (trip) =>
                  trip.scheduledAt.year == day.year &&
                  trip.scheduledAt.month == day.month &&
                  trip.scheduledAt.day == day.day,
            )
            .length,
    ];

    final maxCount = countsByDay.fold(
      0,
      (previous, current) => current > previous ? current : previous,
    );

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: (maxCount == 0 ? 1 : maxCount).toDouble() + 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      weekdayLabels[days[index].weekday - 1],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < countsByDay.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: countsByDay[i].toDouble(),
                    color: Theme.of(context).colorScheme.primary,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentsPerRouteChart extends StatelessWidget {
  const _StudentsPerRouteChart({required this.routeIds, required this.routeNames});

  final List<String> routeIds;
  final Map<String, String> routeNames;

  @override
  Widget build(BuildContext context) {
    if (routeIds.isEmpty) {
      return EmptyStateView(
        compact: true,
        icon: Icons.route_outlined,
        title: const S(
          'No students are assigned to a route yet.',
          'مفيش طلاب متحدد لهم خط لسه.',
        ).of(context),
      );
    }

    final counts = <String, int>{};
    for (final routeId in routeIds) {
      counts[routeId] = (counts[routeId] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.first.value;

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    routeNames[entry.key] ?? entry.key,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / maxCount,
                      minHeight: 14,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${entry.value}', style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
      ],
    );
  }
}

const _driverStatusColors = {
  'approved': Colors.green,
  'pending': Colors.amber,
  'suspended': Colors.orange,
  'rejected': Colors.red,
};

class _DriverStatusChart extends StatelessWidget {
  const _DriverStatusChart({required this.statuses});

  final List<String> statuses;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return EmptyStateView(
        compact: true,
        icon: Icons.badge_outlined,
        title: const S('No drivers registered yet.', 'مفيش سائقين متسجلين لسه.').of(context),
      );
    }

    final counts = <String, int>{};
    for (final status in statuses) {
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final entry in counts.entries)
          Chip(
            avatar: CircleAvatar(
              backgroundColor: _driverStatusColors[entry.key] ?? Colors.grey,
            ),
            label: Text('${entry.key} (${entry.value})'),
          ),
      ],
    );
  }
}
