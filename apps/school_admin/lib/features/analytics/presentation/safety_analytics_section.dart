import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui show TextDirection;

import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../common/presentation/domain_labels.dart';
import '../../common/presentation/school_directory.dart';
import '../../deviations/data/deviations_repository.dart';
import '../../incidents/data/incidents_repository.dart';
import '../../../widgets/async_error_view.dart';
import '../data/pickup_verifications_repository.dart';

/// Safety analytics built on the incident, deviation and pickup-
/// verification records — the extension to the existing AnalyticsTab.
///
/// Every chart here renders only from records that actually exist. In
/// particular the pickup-verification chart *hides itself entirely* when
/// that collection group is empty (the driver/parent workstreams may not
/// have shipped it yet), rather than drawing an empty or invented chart.
class SafetyAnalyticsSection extends StatelessWidget {
  const SafetyAnalyticsSection({super.key, required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl2),
        SectionHeader(
          title: const S(
            'Incidents over time',
            'البلاغات عبر الوقت',
            fr: 'Signalements dans le temps',
            es: 'Incidencias a lo largo del tiempo',
          ).of(context),
          subtitle: const S(
            'Reported incidents by type, last 14 days.',
            'البلاغات حسب النوع، آخر 14 يوم.',
            fr: 'Incidents signalés par type, 14 derniers jours.',
            es: 'Incidencias reportadas por tipo, últimos 14 días.',
          ).of(context),
        ),
        _IncidentsOverTimeChart(schoolId: schoolId),
        const SizedBox(height: AppSpacing.xl2),
        SectionHeader(
          title: const S(
            'Route deviation frequency',
            'تكرار الخروج عن المسار',
            fr: 'Fréquence des écarts de trajet',
            es: 'Frecuencia de desvíos de ruta',
          ).of(context),
          subtitle: const S(
            'Closed deviation episodes per route.',
            'مرات الخروج عن المسار المنتهية لكل خط.',
            fr: 'Épisodes de déviation clôturés par itinéraire.',
            es: 'Episodios de desvío cerrados por ruta.',
          ).of(context),
        ),
        _DeviationsByRouteChart(schoolId: schoolId),
        _PickupVerificationSection(schoolId: schoolId),
      ],
    );
  }
}

/// A stacked-by-type daily count of reported incidents.
class _IncidentsOverTimeChart extends StatelessWidget {
  const _IncidentsOverTimeChart({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: IncidentsRepository().watchIncidents(schoolId, limit: 300),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AsyncErrorView(compact: true);
        if (!snapshot.hasData) {
          return const SizedBox(height: 180, child: AppSkeleton(height: 180));
        }

        final incidents = snapshot.data!.docs
            .map((doc) => SchoolIncident.fromMap(doc.id, doc.data()))
            .toList();

        if (incidents.isEmpty) {
          return EmptyStateView(
            compact: true,
            icon: Icons.report_outlined,
            title: const S(
              'No incidents reported yet.',
              'مفيش بلاغات لسه.',
              fr: 'Aucun incident signalé pour le moment.',
              es: 'Aún no se han reportado incidencias.',
            ).of(context),
          );
        }

        final today = DateTime.now();
        final days = List.generate(
          14,
          (index) => DateTime(
            today.year,
            today.month,
            today.day,
          ).subtract(Duration(days: 13 - index)),
        );

        final countsByDay = [
          for (final day in days)
            incidents
                .where(
                  (incident) =>
                      incident.createdAt.year == day.year &&
                      incident.createdAt.month == day.month &&
                      incident.createdAt.day == day.day,
                )
                .length,
        ];
        final maxCount = countsByDay.fold(
          0,
          (previous, current) => current > previous ? current : previous,
        );

        // Type mix over the same window, shown as chips beside the chart —
        // a stacked bar with seven categories would be unreadable at this
        // size, and the mix is what the "by type" requirement is after.
        final windowStart = days.first;
        final byType = <IncidentType, int>{};
        for (final incident in incidents) {
          if (incident.createdAt.isBefore(windowStart)) continue;
          byType[incident.type] = (byType[incident.type] ?? 0) + 1;
        }
        final typeEntries = byType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
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
                          // Every other day, so 14 labels don't collide.
                          if (index.isOdd) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat.Md().format(days[index]),
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
                            color: colors.warning,
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (typeEntries.isEmpty)
              Text(
                const S(
                  'No incidents in the last 14 days.',
                  'مفيش بلاغات في آخر 14 يوم.',
                  fr: 'Aucun incident au cours des 14 derniers jours.',
                  es: 'No hay incidencias en los últimos 14 días.',
                ).of(context),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final entry in typeEntries)
                    Chip(
                      avatar: Icon(
                        incidentTypeIcon(entry.key),
                        size: 16,
                        color: colors.warning,
                      ),
                      label: Text(
                        '${incidentTypeLabel(entry.key, context)} '
                        '(${entry.value})',
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _DeviationsByRouteChart extends StatelessWidget {
  const _DeviationsByRouteChart({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return SchoolDirectoryBuilder(
      schoolId: schoolId,
      builder: (context, directory) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: DeviationsRepository().watchDeviationHistory(
              schoolId,
              limit: 300,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const AsyncErrorView(compact: true);
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 120,
                  child: AppSkeleton(height: 120),
                );
              }

              final records = snapshot.data!.docs
                  .map((doc) => DeviationRecord.fromMap(doc.id, doc.data()))
                  .toList();

              if (records.isEmpty) {
                return EmptyStateView(
                  compact: true,
                  icon: Icons.route_outlined,
                  title: const S(
                    'No route deviations recorded yet.',
                    'مفيش خروج عن المسار متسجل لسه.',
                    fr: 'Aucun écart de trajet enregistré pour le moment.',
                    es: 'Aún no se han registrado desvíos de ruta.',
                  ).of(context),
                );
              }

              final counts = <String, int>{};
              for (final record in records) {
                final key = record.routeId ?? '';
                counts[key] = (counts[key] ?? 0) + 1;
              }
              final entries = counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final maxCount = entries.first.value;

              return Column(
                children: [
                  for (final entry in entries.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: Text(
                              entry.key.isEmpty
                                  ? const S(
                                      'No route',
                                      'من غير خط',
                                      fr: 'Aucun itinéraire',
                                      es: 'Sin ruta',
                                    ).of(context)
                                  : directory.routeLabel(entry.key),
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
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Directionality(
                            textDirection: ui.TextDirection.ltr,
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
            },
          ),
    );
  }
}

/// Pickup verification success/failure rate.
///
/// Renders **nothing at all** until the `pickupVerifications` collection
/// group actually contains records for this school — that data is produced
/// by the driver/parent secure-pickup workstream, and showing an empty
/// "0% success" chart before it ships would misrepresent an absent feature
/// as a failing one.
class _PickupVerificationSection extends StatelessWidget {
  const _PickupVerificationSection({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PickupVerificationsRepository().watchVerifications(schoolId),
      builder: (context, snapshot) {
        // A missing collection, a permission error, or simply no records
        // yet: in every one of those cases there is nothing honest to show.
        if (snapshot.hasError) return const SizedBox.shrink();
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final verifications = docs
            .map((doc) => PickupVerification.fromMap(doc.id, doc.data()))
            .toList();

        final verified = verifications
            .where((v) => v.status == PickupVerificationStatus.verified)
            .length;
        final failed = verifications
            .where((v) => v.status == PickupVerificationStatus.failed)
            .length;
        final pending = verifications
            .where((v) => v.status == PickupVerificationStatus.pending)
            .length;
        final decided = verified + failed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl2),
            SectionHeader(
              title: const S(
                'Pickup verification',
                'تأكيد الاستلام',
                fr: 'Vérification de la prise en charge',
                es: 'Verificación de recogida',
              ).of(context),
              subtitle: S(
                '${verifications.length} recorded attempt(s).',
                '${verifications.length} محاولة متسجلة.',
                fr: '${verifications.length} tentative(s) enregistrée(s).',
                es: '${verifications.length} intento(s) registrado(s).',
              ).of(context),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.md;
                final columns = constraints.maxWidth >= 720 ? 3 : 1;
                final cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final cards = [
                  MetricStatCard(
                    icon: Icons.verified_outlined,
                    tone: colors.success,
                    label: const S(
                      'Success rate',
                      'نسبة النجاح',
                      fr: 'Taux de réussite',
                      es: 'Tasa de éxito',
                    ).of(context),
                    value: decided == 0
                        ? '—'
                        : '${(verified / decided * 100).round()}%',
                  ),
                  MetricStatCard(
                    icon: Icons.cancel_outlined,
                    tone: failed > 0 ? colors.error : colors.success,
                    label: const S(
                      'Failed',
                      'فشلت',
                      fr: 'Échoués',
                      es: 'Fallidos',
                    ).of(context),
                    value: '$failed',
                  ),
                  MetricStatCard(
                    icon: Icons.hourglass_bottom,
                    tone: colors.textMuted,
                    label: const S(
                      'Pending',
                      'معلقة',
                      fr: 'En attente',
                      es: 'Pendientes',
                    ).of(context),
                    value: '$pending',
                  ),
                ];
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final card in cards)
                      SizedBox(width: cardWidth, child: card),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
