import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../common/presentation/domain_labels.dart';
import '../../common/presentation/school_directory.dart';
import '../data/audit_log_repository.dart';

/// The school's immutable operational audit trail, newest first — who did
/// what, to which entity, when. Read-only by construction: firestore.rules
/// forbids update and delete on `auditLog` entirely, so this screen has no
/// edit affordances at all, only filters and an expandable metadata view.
///
/// Action / entity / date-range filtering runs client-side over the one
/// (schoolId, timestamp DESC) indexed stream, so adding a filter never
/// requires a new composite index in firebase/firestore.indexes.json.
class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage> {
  static const _pageSize = 100;

  String? _actionFilter;
  String? _entityTypeFilter;
  DateTimeRange? _dateRange;
  int _limit = _pageSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Audit trail', 'سجل التدقيق').of(context)),
      ),
      body: SchoolDirectoryBuilder(
        schoolId: widget.schoolId,
        builder: (context, directory) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AuditLogRepository().watchAuditLog(
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
                    itemCount: 8,
                    itemBuilder: (_, _) => const AppSkeletonListTile(),
                  );
                }

                final all = snapshot.data!.docs
                    .map((doc) => AuditLogEntry.fromMap(doc.id, doc.data()))
                    .toList();

                if (all.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: const S(
                      'No audit entries yet',
                      'مفيش سجلات تدقيق لسه',
                    ).of(context),
                    message: const S(
                      'Every admin and driver action that changes an '
                          'incident, emergency, trip assignment or boarding '
                          'record is recorded here permanently.',
                      'كل إجراء من الأدمن أو السواق بيغيّر بلاغ أو حالة '
                          'طوارئ أو تخصيص رحلة أو ركوب طالب بيتسجل هنا '
                          'بشكل دائم.',
                    ).of(context),
                  );
                }

                final availableActions =
                    all.map((entry) => entry.action).toSet().toList()..sort();
                final availableEntityTypes =
                    all
                        .map((entry) => entry.entityType)
                        .whereType<String>()
                        .where((type) => type.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();

                final visible = all.where(_matchesFilters).toList();
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
                        SectionHeader(
                          title: const S(
                            'Recorded actions',
                            'الإجراءات المسجلة',
                          ).of(context),
                          subtitle: S(
                            'Showing ${visible.length} of ${all.length} '
                                'entries. Audit records can never be edited '
                                'or deleted.',
                            'بيتعرض ${visible.length} من ${all.length} سجل. '
                                'سجلات التدقيق مينفعش تتعدل أو تتمسح أبداً.',
                          ).of(context),
                        ),
                        _AuditFilters(
                          actions: availableActions,
                          entityTypes: availableEntityTypes,
                          actionFilter: _actionFilter,
                          entityTypeFilter: _entityTypeFilter,
                          dateRange: _dateRange,
                          onActionChanged: (value) =>
                              setState(() => _actionFilter = value),
                          onEntityTypeChanged: (value) =>
                              setState(() => _entityTypeFilter = value),
                          onDateRangeChanged: (value) =>
                              setState(() => _dateRange = value),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (visible.isEmpty)
                          EmptyStateView(
                            compact: true,
                            icon: Icons.filter_alt_off_outlined,
                            title: const S(
                              'No entries match these filters.',
                              'مفيش سجلات مطابقة للفلاتر دي.',
                            ).of(context),
                          )
                        else
                          _AuditTable(entries: visible, directory: directory),
                        if (hasMore) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Center(
                            child: AppButton.secondary(
                              label: const S(
                                'Load more',
                                'حمّل المزيد',
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

  bool _matchesFilters(AuditLogEntry entry) {
    if (_actionFilter != null && entry.action != _actionFilter) return false;
    if (_entityTypeFilter != null && entry.entityType != _entityTypeFilter) {
      return false;
    }
    final range = _dateRange;
    if (range != null) {
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      // Inclusive of the whole end day, which is what a person picking
      // "1 Jan – 3 Jan" means.
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1));
      if (entry.timestamp.isBefore(start) || !entry.timestamp.isBefore(end)) {
        return false;
      }
    }
    return true;
  }
}

class _AuditFilters extends StatelessWidget {
  const _AuditFilters({
    required this.actions,
    required this.entityTypes,
    required this.actionFilter,
    required this.entityTypeFilter,
    required this.dateRange,
    required this.onActionChanged,
    required this.onEntityTypeChanged,
    required this.onDateRangeChanged,
  });

  final List<String> actions;
  final List<String> entityTypes;
  final String? actionFilter;
  final String? entityTypeFilter;
  final DateTimeRange? dateRange;
  final ValueChanged<String?> onActionChanged;
  final ValueChanged<String?> onEntityTypeChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String?>(
            initialValue: actionFilter,
            isDense: true,
            // Production hardening: without this, the field sizes itself to
            // the *widest* item across the whole menu rather than the
            // selected value, and this hardening pass added several action
            // labels (e.g. "Boarding rejected — bus full") long enough to
            // overflow the fixed 260px SizedBox below — isExpanded makes the
            // field fill that width instead and let the selected text clip,
            // matching how the field actually renders either way.
            isExpanded: true,
            decoration: InputDecoration(
              labelText: const S('Action', 'الإجراء').of(context),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  const S('All actions', 'كل الإجراءات').of(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final action in actions)
                DropdownMenuItem<String?>(
                  value: action,
                  child: Text(
                    auditActionLabel(action, context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onActionChanged,
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            initialValue: entityTypeFilter,
            isDense: true,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: const S('Entity', 'العنصر').of(context),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  const S('All entities', 'كل العناصر').of(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final type in entityTypes)
                DropdownMenuItem<String?>(
                  value: type,
                  child: Text(type, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onEntityTypeChanged,
          ),
        ),
        AppButton.secondary(
          icon: Icons.date_range_outlined,
          label: dateRange == null
              ? const S('Any date', 'أي تاريخ').of(context)
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
            tooltip: const S('Clear dates', 'مسح التواريخ').of(context),
            icon: const Icon(Icons.close),
            onPressed: () => onDateRangeChanged(null),
          ),
      ],
    );
  }
}

class _AuditTable extends StatelessWidget {
  const _AuditTable({required this.entries, required this.directory});

  final List<AuditLogEntry> entries;
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
              if (wide) const _AuditTableHeader(),
              for (var i = 0; i < entries.length; i++)
                _AuditRow(
                  key: ValueKey(entries[i].id),
                  entry: entries[i],
                  directory: directory,
                  wide: wide,
                  isLast: i == entries.length - 1,
                ),
            ],
          ),
        );
      },
    );
  }
}

const _flexWhen = 3;
const _flexActor = 3;
const _flexAction = 3;
const _flexEntity = 4;

class _AuditTableHeader extends StatelessWidget {
  const _AuditTableHeader();

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
          cell(_flexWhen, const S('When', 'الوقت').of(context)),
          cell(_flexActor, const S('Actor', 'المستخدم').of(context)),
          cell(_flexAction, const S('Action', 'الإجراء').of(context)),
          cell(_flexEntity, const S('Entity', 'العنصر').of(context)),
        ],
      ),
    );
  }
}

class _AuditRow extends StatefulWidget {
  const _AuditRow({
    super.key,
    required this.entry,
    required this.directory,
    required this.wide,
    required this.isLast,
  });

  final AuditLogEntry entry;
  final SchoolDirectory directory;
  final bool wide;
  final bool isLast;

  @override
  State<_AuditRow> createState() => _AuditRowState();
}

class _AuditRowState extends State<_AuditRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final hasDetail = entry.metadata.isNotEmpty;

    final whenCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMd().format(entry.timestamp),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          DateFormat.jms().format(entry.timestamp),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );

    final actorCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.directory.driverLabel(entry.actorUid),
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        Text(
          entry.actorRole,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );

    final actionCell = Align(
      alignment: AlignmentDirectional.centerStart,
      child: StatusBadge(
        label: auditActionLabel(entry.action, context),
        tone: auditActionTone(entry.action),
      ),
    );

    final entityCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.entityType != null)
          DirectoryMetaLine(
            icon: Icons.data_object_outlined,
            text: '${entry.entityType}'
                '${entry.entityId == null ? '' : ' · ${entry.entityId}'}',
          ),
        if (entry.busId != null)
          DirectoryMetaLine(
            icon: Icons.directions_bus_outlined,
            text: widget.directory.busLabel(entry.busId),
          ),
        if (entry.driverId != null)
          DirectoryMetaLine(
            icon: Icons.badge_outlined,
            text: widget.directory.driverLabel(entry.driverId),
          ),
        if (entry.tripId != null)
          DirectoryMetaLine(
            icon: Icons.route_outlined,
            text: S('Trip ${entry.tripId}', 'رحلة ${entry.tripId}').of(context),
          ),
        if (hasDetail)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(
                _expanded
                    ? const S('Hide details', 'إخفاء التفاصيل').of(context)
                    : const S('Details', 'التفاصيل').of(context),
              ),
            ),
          ),
        if (_expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in entry.metadata.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${item.key}: ${item.value}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    final divider = widget.isLast
        ? null
        : Border(bottom: BorderSide(color: colors.border));

    if (!widget.wide) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(border: divider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            actionCell,
            const SizedBox(height: AppSpacing.sm),
            whenCell,
            const SizedBox(height: AppSpacing.sm),
            actorCell,
            const SizedBox(height: AppSpacing.sm),
            entityCell,
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
          Expanded(flex: _flexActor, child: actorCell),
          Expanded(flex: _flexAction, child: actionCell),
          Expanded(flex: _flexEntity, child: entityCell),
        ],
      ),
    );
  }
}
