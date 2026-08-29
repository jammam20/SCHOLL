import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../common/presentation/domain_labels.dart';
import '../../common/presentation/school_directory.dart';
import '../data/incidents_repository.dart';
import 'bloc/incidents_bloc.dart';

/// The admin triage surface for driver-filed incident reports: a wide
/// table of every incident with its bus/route/driver/type/time/location/
/// status, filterable by status, with acknowledge and resolve actions and
/// a tap-to-view-on-map for any incident that carries coordinates.
///
/// Desktop-first: on a wide viewport this renders as a real
/// multi-column table; below [_tableBreakpoint] the same rows collapse to
/// stacked cards so the screen stays usable on a narrow window without
/// horizontally scrolling a 7-column table.
class IncidentsPage extends StatelessWidget {
  const IncidentsPage({
    super.key,
    required this.schoolId,
    this.readOnly = false,
  });

  final String schoolId;

  /// True for the staff (read-only) role — the table renders identically
  /// but every acknowledge/resolve control is omitted entirely rather than
  /// shown disabled, since staff have no write path at all (firestore.rules
  /// never grants `staff` a write on incidents).
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          IncidentsBloc(IncidentsRepository())..add(IncidentsStarted(schoolId)),
      child: _IncidentsView(schoolId: schoolId, readOnly: readOnly),
    );
  }
}

const _tableBreakpoint = 900.0;

class _IncidentsView extends StatefulWidget {
  const _IncidentsView({required this.schoolId, required this.readOnly});

  final String schoolId;
  final bool readOnly;

  @override
  State<_IncidentsView> createState() => _IncidentsViewState();
}

class _IncidentsViewState extends State<_IncidentsView> {
  IncidentStatus? _statusFilter;
  IncidentType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IncidentsBloc, IncidentsState>(
      listenWhen: (_, current) => current is IncidentsActionFailure,
      listener: (context, state) {
        if (state is IncidentsActionFailure) {
          AppSnackbar.error(context, state.message);
        }
      },
      builder: (context, state) {
        Widget body;

        if (state is IncidentsLoading || state is IncidentsInitial) {
          body = ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 6,
            itemBuilder: (_, _) => const AppSkeletonListTile(),
          );
        } else if (state is IncidentsFailure) {
          body = ErrorStateView(
            message: state.message,
            onRetry: () => context.read<IncidentsBloc>().add(
              IncidentsStarted(widget.schoolId),
            ),
          );
        } else {
          final snapshot = switch (state) {
            IncidentsLoaded(:final snapshot) => snapshot,
            IncidentsActionFailure(:final snapshot) => snapshot,
            _ => null,
          };
          final hasMore = switch (state) {
            IncidentsLoaded(:final hasMore) => hasMore,
            IncidentsActionFailure(:final hasMore) => hasMore,
            _ => false,
          };

          final all = (snapshot?.docs ?? const [])
              .map((doc) => SchoolIncident.fromMap(doc.id, doc.data()))
              .toList();
          final visible = all
              .where(
                (incident) =>
                    (_statusFilter == null ||
                        incident.status == _statusFilter) &&
                    (_typeFilter == null || incident.type == _typeFilter),
              )
              .toList();

          body = SchoolDirectoryBuilder(
            schoolId: widget.schoolId,
            builder: (context, directory) => _IncidentsBody(
              schoolId: widget.schoolId,
              readOnly: widget.readOnly,
              directory: directory,
              all: all,
              visible: visible,
              hasMore: hasMore,
              statusFilter: _statusFilter,
              typeFilter: _typeFilter,
              onStatusFilterChanged: (value) =>
                  setState(() => _statusFilter = value),
              onTypeFilterChanged: (value) =>
                  setState(() => _typeFilter = value),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              const S('Incidents', 'الحوادث والبلاغات').of(context),
            ),
          ),
          body: body,
        );
      },
    );
  }
}

class _IncidentsBody extends StatelessWidget {
  const _IncidentsBody({
    required this.schoolId,
    required this.readOnly,
    required this.directory,
    required this.all,
    required this.visible,
    required this.hasMore,
    required this.statusFilter,
    required this.typeFilter,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
  });

  final String schoolId;
  final bool readOnly;
  final SchoolDirectory directory;
  final List<SchoolIncident> all;
  final List<SchoolIncident> visible;
  final bool hasMore;
  final IncidentStatus? statusFilter;
  final IncidentType? typeFilter;
  final ValueChanged<IncidentStatus?> onStatusFilterChanged;
  final ValueChanged<IncidentType?> onTypeFilterChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (all.isEmpty) {
      return EmptyStateView(
        icon: Icons.report_outlined,
        title: const S(
          'No incidents reported',
          'مفيش بلاغات',
        ).of(context),
        message: const S(
          'Incidents filed by drivers during a trip appear here for you to '
              'acknowledge and resolve.',
          'البلاغات اللي السواقين بيسجلوها أثناء الرحلة هتظهر هنا عشان '
              'تطلع عليها وتحلها.',
        ).of(context),
      );
    }

    final reported = all
        .where((incident) => incident.status == IncidentStatus.reported)
        .length;
    final acknowledged = all
        .where((incident) => incident.status == IncidentStatus.acknowledged)
        .length;
    final resolved = all
        .where((incident) => incident.status == IncidentStatus.resolved)
        .length;

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
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.md;
                final columns = constraints.maxWidth >= 720 ? 3 : 1;
                final cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final cards = [
                  MetricStatCard(
                    icon: Icons.notification_important_outlined,
                    tone: colors.warning,
                    label: const S(
                      'Awaiting acknowledgement',
                      'في انتظار الاطلاع',
                    ).of(context),
                    value: '$reported',
                  ),
                  MetricStatCard(
                    icon: Icons.visibility_outlined,
                    tone: colors.info,
                    label: const S(
                      'Acknowledged, open',
                      'تم الاطلاع، لسه مفتوحة',
                    ).of(context),
                    value: '$acknowledged',
                  ),
                  MetricStatCard(
                    icon: Icons.task_alt,
                    tone: colors.success,
                    label: const S('Resolved', 'تم حلها').of(context),
                    value: '$resolved',
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
            const SizedBox(height: AppSpacing.xl2),
            SectionHeader(
              title: const S('Incident log', 'سجل البلاغات').of(context),
              subtitle: S(
                'Showing ${visible.length} of ${all.length}',
                'بيتعرض ${visible.length} من ${all.length}',
              ).of(context),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<IncidentStatus?>(
                    initialValue: statusFilter,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: const S('Status', 'الحالة').of(context),
                    ),
                    items: [
                      DropdownMenuItem<IncidentStatus?>(
                        value: null,
                        child: Text(
                          const S('All statuses', 'كل الحالات').of(context),
                        ),
                      ),
                      for (final status in IncidentStatus.values)
                        DropdownMenuItem<IncidentStatus?>(
                          value: status,
                          child: Text(incidentStatusLabel(status, context)),
                        ),
                    ],
                    onChanged: onStatusFilterChanged,
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<IncidentType?>(
                    initialValue: typeFilter,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: const S('Type', 'النوع').of(context),
                    ),
                    items: [
                      DropdownMenuItem<IncidentType?>(
                        value: null,
                        child: Text(
                          const S('All types', 'كل الأنواع').of(context),
                        ),
                      ),
                      for (final type in IncidentType.values)
                        DropdownMenuItem<IncidentType?>(
                          value: type,
                          child: Text(incidentTypeLabel(type, context)),
                        ),
                    ],
                    onChanged: onTypeFilterChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (visible.isEmpty)
              EmptyStateView(
                compact: true,
                icon: Icons.filter_alt_off_outlined,
                title: const S(
                  'No incidents match these filters.',
                  'مفيش بلاغات مطابقة للفلاتر دي.',
                ).of(context),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= _tableBreakpoint;
                  return Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (wide) const _IncidentTableHeader(),
                        for (var i = 0; i < visible.length; i++)
                          _IncidentRow(
                            key: ValueKey(visible[i].id),
                            schoolId: schoolId,
                            incident: visible[i],
                            directory: directory,
                            readOnly: readOnly,
                            wide: wide,
                            isLast: i == visible.length - 1,
                          ),
                      ],
                    ),
                  );
                },
              ),
            if (hasMore) ...[
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: AppButton.secondary(
                  label: const S('Load more', 'حمّل المزيد').of(context),
                  icon: Icons.expand_more,
                  onPressed: () => context.read<IncidentsBloc>().add(
                    IncidentsLoadMoreRequested(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Column widths are shared between the header and every row via these
/// flex values, so the table lines up instead of each row negotiating its
/// own layout.
const _flexType = 3;
const _flexContext = 4;
const _flexTime = 2;
const _flexStatus = 2;
const _flexActions = 3;

class _IncidentTableHeader extends StatelessWidget {
  const _IncidentTableHeader();

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
          cell(_flexType, const S('Incident', 'البلاغ').of(context)),
          cell(
            _flexContext,
            const S('Bus · route · driver', 'الأتوبيس · الخط · السائق').of(
              context,
            ),
          ),
          cell(_flexTime, const S('Reported', 'وقت البلاغ').of(context)),
          cell(_flexStatus, const S('Status', 'الحالة').of(context)),
          cell(_flexActions, const S('Actions', 'إجراءات').of(context)),
        ],
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({
    super.key,
    required this.schoolId,
    required this.incident,
    required this.directory,
    required this.readOnly,
    required this.wide,
    required this.isLast,
  });

  final String schoolId;
  final SchoolIncident incident;
  final SchoolDirectory directory;
  final bool readOnly;
  final bool wide;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final tone = incidentStatusTone(incident.status);

    final typeCell = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: toneColor(colors, tone).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            incidentTypeIcon(incident.type),
            size: 18,
            color: toneColor(colors, tone),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                incidentTypeLabel(incident.type, context),
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              if (incident.notes != null && incident.notes!.isNotEmpty)
                Text(
                  incident.notes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final contextCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DirectoryMetaLine(
          icon: Icons.directions_bus_outlined,
          text: directory.busLabel(incident.busId),
        ),
        DirectoryMetaLine(
          icon: Icons.alt_route_outlined,
          text: directory.routeLabel(incident.routeId),
        ),
        DirectoryMetaLine(
          icon: Icons.badge_outlined,
          text: directory.driverLabel(incident.driverId),
        ),
      ],
    );

    final timeCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMd().format(incident.createdAt),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          DateFormat.jm().format(incident.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        if (incident.hasLocation)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: InkWell(
              onTap: () => _openMap(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 14, color: colors.info),
                  const SizedBox(width: 2),
                  Text(
                    const S('View on map', 'شوفها على الخريطة').of(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.info,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final statusCell = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            label: incidentStatusLabel(incident.status, context),
            tone: tone,
          ),
          if (incident.resolutionNotes != null &&
              incident.resolutionNotes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                incident.resolutionNotes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );

    final actionsCell = readOnly
        ? Text(
            const S('View only', 'للعرض فقط').of(context),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
          )
        : Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (incident.status == IncidentStatus.reported)
                AppButton.secondary(
                  icon: Icons.visibility_outlined,
                  label: const S('Acknowledge', 'اطّلعت').of(context),
                  onPressed: () => context.read<IncidentsBloc>().add(
                    IncidentAcknowledged(
                      schoolId: schoolId,
                      incidentId: incident.id,
                    ),
                  ),
                ),
              if (incident.status != IncidentStatus.resolved)
                AppButton.primary(
                  icon: Icons.task_alt,
                  label: const S('Resolve', 'حل').of(context),
                  onPressed: () => _promptResolve(context),
                ),
            ],
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
            typeCell,
            const SizedBox(height: AppSpacing.sm),
            contextCell,
            const SizedBox(height: AppSpacing.sm),
            timeCell,
            const SizedBox(height: AppSpacing.sm),
            statusCell,
            const SizedBox(height: AppSpacing.sm),
            actionsCell,
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
          Expanded(flex: _flexType, child: typeCell),
          Expanded(flex: _flexContext, child: contextCell),
          Expanded(flex: _flexTime, child: timeCell),
          Expanded(flex: _flexStatus, child: statusCell),
          Expanded(flex: _flexActions, child: actionsCell),
        ],
      ),
    );
  }

  void _openMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IncidentMapPage(incident: incident)),
    );
  }

  Future<void> _promptResolve(BuildContext context) async {
    final bloc = context.read<IncidentsBloc>();
    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ResolveIncidentDialog(incident: incident),
    );
    if (notes == null || notes.trim().isEmpty) return;

    bloc.add(
      IncidentResolved(
        schoolId: schoolId,
        incidentId: incident.id,
        resolutionNotes: notes,
      ),
    );
  }
}

class _ResolveIncidentDialog extends StatefulWidget {
  const _ResolveIncidentDialog({required this.incident});

  final SchoolIncident incident;

  @override
  State<_ResolveIncidentDialog> createState() => _ResolveIncidentDialogState();
}

class _ResolveIncidentDialogState extends State<_ResolveIncidentDialog> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(const S('Resolve incident', 'حل البلاغ').of(context)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              incidentTypeLabel(widget.incident.type, context),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (widget.incident.notes != null &&
                widget.incident.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.incident.notes!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _notes,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: const S(
                  'Resolution notes',
                  'ملاحظات الحل',
                ).of(context),
                hintText: const S(
                  'What was done about this?',
                  'اتعمل إيه بخصوص ده؟',
                ).of(context),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton.secondary(
          label: const S('Cancel', 'إلغاء').of(context),
          onPressed: () => Navigator.pop(context),
        ),
        AppButton.primary(
          label: const S('Resolve', 'حل').of(context),
          onPressed: () => Navigator.pop(context, _notes.text),
        ),
      ],
    );
  }
}

/// Where an incident was reported from, on a map — reachable from the
/// incidents table and from the live-ops map's incident list.
class IncidentMapPage extends StatelessWidget {
  const IncidentMapPage({super.key, required this.incident});

  final SchoolIncident incident;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(incident.latitude ?? 0, incident.longitude ?? 0);

    return Scaffold(
      appBar: AppBar(title: Text(incidentTypeLabel(incident.type, context))),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: position, zoom: 15),
            markers: {
              Marker(
                markerId: MarkerId(incident.id),
                position: position,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
                infoWindow: InfoWindow(
                  title: incidentTypeLabel(incident.type, context),
                  snippet: DateFormat.yMMMd().add_jm().format(
                    incident.createdAt,
                  ),
                ),
              ),
            },
            zoomControlsEnabled: false,
          ),
          PositionedDirectional(
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: _IncidentSummaryCard(incident: incident),
          ),
        ],
      ),
    );
  }
}

class _IncidentSummaryCard extends StatelessWidget {
  const _IncidentSummaryCard({required this.incident});

  final SchoolIncident incident;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level2(colors.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StatusBadge(
                label: incidentStatusLabel(incident.status, context),
                tone: incidentStatusTone(incident.status),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                DateFormat.yMMMd().add_jm().format(incident.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          if (incident.notes != null && incident.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(incident.notes!, style: theme.textTheme.bodyMedium),
          ],
          if (incident.resolutionNotes != null &&
              incident.resolutionNotes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              S(
                'Resolution: ${incident.resolutionNotes}',
                'الحل: ${incident.resolutionNotes}',
              ).of(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
