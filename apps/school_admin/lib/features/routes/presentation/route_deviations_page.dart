import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../common/presentation/domain_labels.dart';
import '../../common/presentation/school_directory.dart';
import '../../deviations/data/deviations_repository.dart';

/// Historical route deviations — every closed episode in
/// `schools/{schoolId}/routeDeviations`, filterable by route, bus and date
/// range.
///
/// Read-only throughout: these records are written only by the
/// `onDriverLocationWritten` Cloud Function, and firestore.rules forbids
/// client writes outright, so there is nothing here to edit.
class RouteDeviationsPage extends StatefulWidget {
  const RouteDeviationsPage({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<RouteDeviationsPage> createState() => _RouteDeviationsPageState();
}

class _RouteDeviationsPageState extends State<RouteDeviationsPage> {
  static const _pageSize = 200;

  String? _routeFilter;
  String? _busFilter;
  DateTimeRange? _dateRange;
  int _limit = _pageSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S(
            'Route deviations',
            'الخروج عن المسار',
            fr: "Écarts d'itinéraire",
            es: 'Desvíos de ruta',
          ).of(context),
        ),
      ),
      body: SchoolDirectoryBuilder(
        schoolId: widget.schoolId,
        builder: (context, directory) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DeviationsRepository().watchDeviationHistory(
                widget.schoolId,
                limit: _limit,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorStateView(onRetry: () => setState(() {}));
                }
                if (!snapshot.hasData) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: 6,
                    itemBuilder: (_, _) => const AppSkeletonListTile(),
                  );
                }

                final all = snapshot.data!.docs
                    .map((doc) => DeviationRecord.fromMap(doc.id, doc.data()))
                    .toList();

                if (all.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.route_outlined,
                    title: const S(
                      'No route deviations recorded',
                      'مفيش خروج عن المسار متسجل',
                      fr: "Aucun écart d'itinéraire enregistré",
                      es: 'Sin desvíos de ruta registrados',
                    ).of(context),
                    message: const S(
                      'A record appears here each time a bus goes further '
                          'from its expected path than its route’s tolerance '
                          'allows, and then returns to it.',
                      'بيتسجل هنا كل مرة أتوبيس يبعد عن مساره المتوقع أكتر '
                          'من حد السماح بتاع الخط وبعدين يرجع تاني.',
                      fr:
                          "Un enregistrement apparaît ici chaque fois qu'un "
                          "bus s'éloigne de son trajet prévu au-delà de la "
                          "tolérance de son itinéraire, puis y revient.",
                      es:
                          'Aparece un registro aquí cada vez que un autobús '
                          'se aleja de su ruta prevista más de lo que '
                          'permite la tolerancia de la ruta, y luego '
                          'regresa a ella.',
                    ).of(context),
                  );
                }

                final visible = all.where(_matches).toList();
                final hasMore = all.length >= _limit;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.xl3,
                      ),
                      children: [
                        _DeviationSummary(records: visible),
                        const SizedBox(height: AppSpacing.xl2),
                        SectionHeader(
                          title: const S(
                            'Deviation history',
                            'سجل الخروج عن المسار',
                            fr: "Historique des écarts",
                            es: 'Historial de desvíos',
                          ).of(context),
                          subtitle: S(
                            'Showing ${visible.length} of ${all.length}',
                            'بيتعرض ${visible.length} من ${all.length}',
                            fr: '${visible.length} sur ${all.length} affichés',
                            es: 'Mostrando ${visible.length} de ${all.length}',
                          ).of(context),
                        ),
                        _DeviationFilters(
                          directory: directory,
                          routeIds: all
                              .map((record) => record.routeId)
                              .whereType<String>()
                              .toSet()
                              .toList(),
                          busIds: all
                              .map((record) => record.busId)
                              .where((id) => id.isNotEmpty)
                              .toSet()
                              .toList(),
                          routeFilter: _routeFilter,
                          busFilter: _busFilter,
                          dateRange: _dateRange,
                          onRouteChanged: (value) =>
                              setState(() => _routeFilter = value),
                          onBusChanged: (value) =>
                              setState(() => _busFilter = value),
                          onDateRangeChanged: (value) =>
                              setState(() => _dateRange = value),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (visible.isEmpty)
                          EmptyStateView(
                            compact: true,
                            icon: Icons.filter_alt_off_outlined,
                            title: const S(
                              'No deviations match these filters.',
                              'مفيش سجلات مطابقة للفلاتر دي.',
                              fr: 'Aucun écart ne correspond à ces filtres.',
                              es: 'Ningún desvío coincide con estos filtros.',
                            ).of(context),
                          )
                        else
                          _DeviationTable(
                            records: visible,
                            directory: directory,
                          ),
                        if (hasMore) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Center(
                            child: AppButton.secondary(
                              label: const S(
                                'Load more',
                                'حمّل المزيد',
                                fr: 'Charger plus',
                                es: 'Cargar más',
                              ).of(context),
                              icon: Icons.expand_more,
                              onPressed: () =>
                                  setState(() => _limit += _pageSize),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  bool _matches(DeviationRecord record) {
    if (_routeFilter != null && record.routeId != _routeFilter) return false;
    if (_busFilter != null && record.busId != _busFilter) return false;
    final range = _dateRange;
    if (range != null) {
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1));
      if (record.startedAt.isBefore(start) || !record.startedAt.isBefore(end)) {
        return false;
      }
    }
    return true;
  }
}

class _DeviationSummary extends StatelessWidget {
  const _DeviationSummary({required this.records});

  final List<DeviationRecord> records;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final durations = records
        .where((record) => record.endedAt != null)
        .map((record) => record.endedAt!.difference(record.startedAt))
        .toList();
    final averageDuration = durations.isEmpty
        ? null
        : Duration(
            seconds:
                durations.fold<int>(0, (total, d) => total + d.inSeconds) ~/
                durations.length,
          );
    final worst = records.isEmpty
        ? null
        : records
              .map((record) => record.maxDeviationMeters)
              .reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cards = [
          MetricStatCard(
            icon: Icons.alt_route,
            tone: colors.warning,
            label: const S(
              'Episodes',
              'عدد المرات',
              fr: 'Épisodes',
              es: 'Episodios',
            ).of(context),
            value: '${records.length}',
          ),
          MetricStatCard(
            icon: Icons.straighten,
            tone: colors.info,
            label: const S(
              'Furthest off route',
              'أبعد مسافة عن المسار',
              fr: "Plus grand écart de l'itinéraire",
              es: 'Mayor desvío de la ruta',
            ).of(context),
            value: worst == null ? '—' : '${worst.round()} m',
          ),
          MetricStatCard(
            icon: Icons.timer_outlined,
            label: const S(
              'Average episode length',
              'متوسط مدة الخروج',
              fr: 'Durée moyenne des épisodes',
              es: 'Duración media de episodios',
            ).of(context),
            value: averageDuration == null
                ? '—'
                : '${averageDuration.inMinutes} min',
          ),
        ];
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

class _DeviationFilters extends StatelessWidget {
  const _DeviationFilters({
    required this.directory,
    required this.routeIds,
    required this.busIds,
    required this.routeFilter,
    required this.busFilter,
    required this.dateRange,
    required this.onRouteChanged,
    required this.onBusChanged,
    required this.onDateRangeChanged,
  });

  final SchoolDirectory directory;
  final List<String> routeIds;
  final List<String> busIds;
  final String? routeFilter;
  final String? busFilter;
  final DateTimeRange? dateRange;
  final ValueChanged<String?> onRouteChanged;
  final ValueChanged<String?> onBusChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String?>(
            initialValue: routeFilter,
            isDense: true,
            decoration: InputDecoration(
              labelText: const S(
                'Route',
                'الخط',
                fr: 'Itinéraire',
                es: 'Ruta',
              ).of(context),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  const S(
                    'All routes',
                    'كل الخطوط',
                    fr: 'Tous les itinéraires',
                    es: 'Todas las rutas',
                  ).of(context),
                ),
              ),
              for (final id in routeIds)
                DropdownMenuItem<String?>(
                  value: id,
                  child: Text(directory.routeLabel(id)),
                ),
            ],
            onChanged: onRouteChanged,
          ),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String?>(
            initialValue: busFilter,
            isDense: true,
            decoration: InputDecoration(
              labelText: const S(
                'Bus',
                'الأتوبيس',
                fr: 'Bus',
                es: 'Autobús',
              ).of(context),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  const S(
                    'All buses',
                    'كل الأتوبيسات',
                    fr: 'Tous les bus',
                    es: 'Todos los autobuses',
                  ).of(context),
                ),
              ),
              for (final id in busIds)
                DropdownMenuItem<String?>(
                  value: id,
                  child: Text(directory.busLabel(id)),
                ),
            ],
            onChanged: onBusChanged,
          ),
        ),
        AppButton.secondary(
          icon: Icons.date_range_outlined,
          label: dateRange == null
              ? const S(
                  'Any date',
                  'أي تاريخ',
                  fr: 'Toute date',
                  es: 'Cualquier fecha',
                ).of(context)
              : '${DateFormat.yMMMd().format(dateRange!.start)} — '
                    '${DateFormat.yMMMd().format(dateRange!.end)}',
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 2),
              lastDate: now,
              initialDateRange: dateRange,
            );
            if (picked != null) onDateRangeChanged(picked);
          },
        ),
        if (dateRange != null)
          IconButton(
            tooltip: const S(
              'Clear dates',
              'مسح التواريخ',
              fr: 'Effacer les dates',
              es: 'Borrar fechas',
            ).of(context),
            icon: const Icon(Icons.close),
            onPressed: () => onDateRangeChanged(null),
          ),
      ],
    );
  }
}

class _DeviationTable extends StatelessWidget {
  const _DeviationTable({required this.records, required this.directory});

  final List<DeviationRecord> records;
  final SchoolDirectory directory;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (wide) const _DeviationTableHeader(),
              for (var i = 0; i < records.length; i++)
                _DeviationRow(
                  key: ValueKey(records[i].id),
                  record: records[i],
                  directory: directory,
                  wide: wide,
                  isLast: i == records.length - 1,
                ),
            ],
          ),
        );
      },
    );
  }
}

const _flexWhen = 3;
const _flexContext = 4;
const _flexDistance = 2;
const _flexDuration = 2;

class _DeviationTableHeader extends StatelessWidget {
  const _DeviationTableHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: colors.textSecondary);

    Widget cell(int flex, String text) =>
        Expanded(flex: flex, child: Text(text.toUpperCase(), style: style));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          cell(
            _flexWhen,
            const S(
              'Started',
              'بدأ',
              fr: 'Commencé',
              es: 'Iniciado',
            ).of(context),
          ),
          cell(
            _flexContext,
            const S(
              'Route · bus · driver',
              'الخط · الأتوبيس · السائق',
              fr: 'Itinéraire · bus · chauffeur',
              es: 'Ruta · autobús · conductor',
            ).of(context),
          ),
          cell(
            _flexDistance,
            const S(
              'Max distance',
              'أقصى مسافة',
              fr: 'Distance max',
              es: 'Distancia máxima',
            ).of(context),
          ),
          cell(
            _flexDuration,
            const S(
              'Duration',
              'المدة',
              fr: 'Durée',
              es: 'Duración',
            ).of(context),
          ),
        ],
      ),
    );
  }
}

class _DeviationRow extends StatelessWidget {
  const _DeviationRow({
    super.key,
    required this.record,
    required this.directory,
    required this.wide,
    required this.isLast,
  });

  final DeviationRecord record;
  final SchoolDirectory directory;
  final bool wide;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final duration = record.endedAt?.difference(record.startedAt);

    final whenCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMd().format(record.startedAt),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          DateFormat.jm().format(record.startedAt),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 4),
        StatusBadge(
          label: deviationStatusLabel(record.status, context),
          tone: deviationStatusTone(record.status),
        ),
      ],
    );

    final contextCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DirectoryMetaLine(
          icon: Icons.alt_route_outlined,
          text: directory.routeLabel(record.routeId),
        ),
        DirectoryMetaLine(
          icon: Icons.directions_bus_outlined,
          text: directory.busLabel(record.busId),
        ),
        DirectoryMetaLine(
          icon: Icons.badge_outlined,
          text: directory.driverLabel(record.driverId),
        ),
      ],
    );

    final distanceCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${record.maxDeviationMeters.round()} m',
          style: theme.textTheme.titleSmall?.copyWith(color: colors.warning),
        ),
        Text(
          const S(
            'furthest off path',
            'أبعد نقطة',
            fr: "point le plus éloigné",
            es: 'punto más alejado',
          ).of(context),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );

    final durationCell = Text(
      duration == null
          ? const S(
              'Ongoing',
              'مستمر',
              fr: 'En cours',
              es: 'En curso',
            ).of(context)
          : duration.inMinutes < 1
          ? const S(
              '<1 min',
              'أقل من دقيقة',
              fr: '<1 min',
              es: '<1 min',
            ).of(context)
          : '${duration.inMinutes} min',
      style: theme.textTheme.bodySmall,
    );

    final divider = isLast
        ? null
        : Border(bottom: BorderSide(color: colors.border));

    if (!wide) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(border: divider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            whenCell,
            const SizedBox(height: AppSpacing.sm),
            contextCell,
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: distanceCell),
                Expanded(child: durationCell),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(border: divider),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: _flexWhen, child: whenCell),
          Expanded(flex: _flexContext, child: contextCell),
          Expanded(flex: _flexDistance, child: distanceCell),
          Expanded(flex: _flexDuration, child: durationCell),
        ],
      ),
    );
  }
}
