import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../common/presentation/domain_labels.dart';
import '../../drivers/data/drivers_repository.dart';
import '../../../widgets/async_error_view.dart';
import '../data/vehicles_repository.dart';
import 'bloc/vehicle_detail_bloc.dart';

/// One vehicle: its editable profile (model/year/capacity/assigned driver,
/// and the three document expiry dates) alongside its maintenance log.
///
/// Laid out as two columns on a wide viewport — profile on the left,
/// maintenance on the right — because an admin working through a vehicle's
/// paperwork wants both visible at once, not one scrolled past the other.
class VehicleDetailPage extends StatelessWidget {
  const VehicleDetailPage({
    super.key,
    required this.schoolId,
    required this.busId,
  });

  final String schoolId;
  final String busId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VehicleDetailBloc(VehiclesRepository())
        ..add(VehicleDetailStarted(schoolId: schoolId, busId: busId)),
      child: _VehicleDetailView(schoolId: schoolId, busId: busId),
    );
  }
}

class _VehicleDetailView extends StatelessWidget {
  const _VehicleDetailView({required this.schoolId, required this.busId});

  final String schoolId;
  final String busId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VehicleDetailBloc, VehicleDetailState>(
      listenWhen: (_, current) =>
          current is VehicleDetailLoaded &&
          (current.actionError != null || current.completedAction != null),
      listener: (context, state) {
        if (state is! VehicleDetailLoaded) return;
        if (state.actionError != null) {
          AppSnackbar.error(context, state.actionError!);
          return;
        }
        final action = state.completedAction;
        if (action == null) return;
        AppSnackbar.success(context, switch (action) {
          VehicleDetailAction.profileSaved => const S(
            'Vehicle profile saved.',
            'تم حفظ بيانات المركبة.',
          ).of(context),
          VehicleDetailAction.maintenanceAdded => const S(
            'Maintenance item added.',
            'تمت إضافة بند الصيانة.',
          ).of(context),
          VehicleDetailAction.maintenanceCompleted => const S(
            'Marked complete.',
            'تم تسجيله كمنجز.',
          ).of(context),
          VehicleDetailAction.maintenanceDeleted => const S(
            'Record deleted.',
            'تم مسح السجل.',
          ).of(context),
        });
      },
      builder: (context, state) {
        final title = state is VehicleDetailLoaded
            ? state.bus.name
            : const S('Vehicle', 'المركبة').of(context);

        Widget body;
        if (state is VehicleDetailLoading || state is VehicleDetailInitial) {
          body = ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.xl),
            itemCount: 6,
            itemBuilder: (_, _) => const AppSkeletonListTile(),
          );
        } else if (state is VehicleDetailFailure) {
          body = state.notFound
              ? EmptyStateView(
                  icon: Icons.no_transfer_outlined,
                  title: const S(
                    'This bus no longer exists.',
                    'الأتوبيس ده مبقاش موجود.',
                  ).of(context),
                  message: const S(
                    'It may have been removed while this page was open.',
                    'يمكن يكون اتشال والصفحة دي مفتوحة.',
                  ).of(context),
                )
              : ErrorStateView(
                  message: state.message,
                  onRetry: () => context.read<VehicleDetailBloc>().add(
                    VehicleDetailStarted(schoolId: schoolId, busId: busId),
                  ),
                );
        } else {
          final loaded = state as VehicleDetailLoaded;
          body = _VehicleDetailBody(
            schoolId: schoolId,
            bus: loaded.bus,
            maintenance: loaded.maintenance,
          );
        }

        return Scaffold(appBar: AppBar(title: Text(title)), body: body);
      },
    );
  }
}

class _VehicleDetailBody extends StatelessWidget {
  const _VehicleDetailBody({
    required this.schoolId,
    required this.bus,
    required this.maintenance,
  });

  final String schoolId;
  final SchoolBus bus;
  final List<MaintenanceRecord> maintenance;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final open = maintenance.where((record) => !record.isCompleted).toList();
    final completed = maintenance.where((record) => record.isCompleted).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    final profile = _VehicleProfileCard(schoolId: schoolId, bus: bus);
    final log = _MaintenanceLogCard(
      schoolId: schoolId,
      bus: bus,
      open: open,
      completed: completed,
      now: now,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DocumentSummary(bus: bus, now: now, openItems: open),
              const SizedBox(height: AppSpacing.xl2),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        profile,
                        const SizedBox(height: AppSpacing.xl2),
                        log,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: profile),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(flex: 5, child: log),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three document expiries plus the count of maintenance items that
/// need doing, as the page's at-a-glance header.
class _DocumentSummary extends StatelessWidget {
  const _DocumentSummary({
    required this.bus,
    required this.now,
    required this.openItems,
  });

  final SchoolBus bus;
  final DateTime now;
  final List<MaintenanceRecord> openItems;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overdue = openItems.where((item) => item.isOverdue(now)).length;
    final dueSoon = openItems.where((item) => item.isDueSoon(now)).length;

    String expiryValue(DateTime? expiry) => expiry == null
        ? '—'
        : DateFormat.yMMMd().format(expiry);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cards = [
          MetricStatCard(
            icon: Icons.shield_outlined,
            tone: toneColor(colors, dueDateTone(bus.insuranceExpiry, now)),
            label: const S('Insurance expiry', 'انتهاء التأمين').of(context),
            value: expiryValue(bus.insuranceExpiry),
          ),
          MetricStatCard(
            icon: Icons.description_outlined,
            tone: toneColor(colors, dueDateTone(bus.registrationExpiry, now)),
            label: const S(
              'Registration expiry',
              'انتهاء رخصة التسيير',
            ).of(context),
            value: expiryValue(bus.registrationExpiry),
          ),
          MetricStatCard(
            icon: Icons.fact_check_outlined,
            tone: toneColor(colors, dueDateTone(bus.inspectionExpiry, now)),
            label: const S('Inspection expiry', 'انتهاء الفحص').of(context),
            value: expiryValue(bus.inspectionExpiry),
          ),
          MetricStatCard(
            icon: Icons.build_outlined,
            tone: overdue > 0
                ? colors.error
                : dueSoon > 0
                ? colors.warning
                : colors.success,
            label: const S(
              'Open maintenance items',
              'بنود صيانة مفتوحة',
            ).of(context),
            value: overdue > 0
                ? S(
                    '${openItems.length} ($overdue overdue)',
                    '${openItems.length} ($overdue متأخر)',
                  ).of(context)
                : '${openItems.length}',
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

class _VehicleProfileCard extends StatefulWidget {
  const _VehicleProfileCard({required this.schoolId, required this.bus});

  final String schoolId;
  final SchoolBus bus;

  @override
  State<_VehicleProfileCard> createState() => _VehicleProfileCardState();
}

class _VehicleProfileCardState extends State<_VehicleProfileCard> {
  late final TextEditingController _model = TextEditingController(
    text: widget.bus.model ?? '',
  );
  late final TextEditingController _year = TextEditingController(
    text: widget.bus.year?.toString() ?? '',
  );
  late final TextEditingController _capacity = TextEditingController(
    text: widget.bus.capacity?.toString() ?? '',
  );

  late DateTime? _insuranceExpiry = widget.bus.insuranceExpiry;
  late DateTime? _registrationExpiry = widget.bus.registrationExpiry;
  late DateTime? _inspectionExpiry = widget.bus.inspectionExpiry;
  late String? _driverId = widget.bus.currentDriverId;

  void _save() {
    context.read<VehicleDetailBloc>().add(
      VehicleProfileSaved(
        schoolId: widget.schoolId,
        busId: widget.bus.id,
        update: VehicleProfileUpdate(
          model: FieldEdit(
            _model.text.trim().isEmpty ? null : _model.text.trim(),
          ),
          year: FieldEdit(int.tryParse(_year.text.trim())),
          capacity: FieldEdit(int.tryParse(_capacity.text.trim())),
          currentDriverId: FieldEdit(_driverId),
          insuranceExpiry: FieldEdit(_insuranceExpiry),
          registrationExpiry: FieldEdit(_registrationExpiry),
          inspectionExpiry: FieldEdit(_inspectionExpiry),
        ),
      ),
    );
    // Success/failure is confirmed by the bloc once the write actually
    // lands (see VehicleDetailAction) — this never claims success itself.
  }

  @override
  void dispose() {
    _model.dispose();
    _year.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: const S('Vehicle profile', 'بيانات المركبة').of(context),
            subtitle: S(
              '${widget.bus.name} · ${widget.bus.plateNumber}',
              '${widget.bus.name} · ${widget.bus.plateNumber}',
            ).of(context),
          ),
          TextField(
            controller: _model,
            decoration: InputDecoration(
              labelText: const S('Model', 'الموديل').of(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: const S('Year', 'سنة الصنع').of(context),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: const S('Capacity', 'السعة').of(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: DriversRepository().watchDrivers(
              widget.schoolId,
              limit: 200,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const AsyncErrorView(compact: true);
              }
              final drivers = (snapshot.data?.docs ?? const [])
                  .where((doc) => doc.data()['status'] == 'approved')
                  .toList();
              // A driver id that isn't in the approved list (suspended
              // since assignment, say) would break DropdownButtonFormField's
              // "value must match exactly one item" contract, so it's
              // treated as "no driver" for the dropdown's purposes.
              final knownDriver = drivers.any((doc) => doc.id == _driverId);
              return DropdownButtonFormField<String?>(
                initialValue: knownDriver ? _driverId : null,
                decoration: InputDecoration(
                  labelText: const S(
                    'Assigned driver',
                    'السائق المخصص',
                  ).of(context),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      const S('No assigned driver', 'من غير سائق').of(context),
                    ),
                  ),
                  for (final doc in drivers)
                    DropdownMenuItem<String?>(
                      value: doc.id,
                      child: Text(
                        doc.data()['displayName']?.toString() ?? doc.id,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _driverId = value),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          _DateField(
            label: const S('Insurance expiry', 'انتهاء التأمين').of(context),
            value: _insuranceExpiry,
            onChanged: (value) => setState(() => _insuranceExpiry = value),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: const S(
              'Registration expiry',
              'انتهاء رخصة التسيير',
            ).of(context),
            value: _registrationExpiry,
            onChanged: (value) => setState(() => _registrationExpiry = value),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: const S('Inspection expiry', 'انتهاء الفحص').of(context),
            value: _inspectionExpiry,
            onChanged: (value) => setState(() => _inspectionExpiry = value),
          ),
          if (widget.bus.lastMaintenanceAt != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.history, size: 16, color: colors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  S(
                    'Last maintenance '
                        '${DateFormat.yMMMd().format(widget.bus.lastMaintenanceAt!)}',
                    'آخر صيانة '
                        '${DateFormat.yMMMd().format(widget.bus.lastMaintenanceAt!)}',
                  ).of(context),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            icon: Icons.save_outlined,
            label: const S('Save profile', 'حفظ البيانات').of(context),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// A tap-to-pick date with an explicit clear affordance — a document
/// expiry an admin sets by mistake has to be removable, not just
/// changeable, which is why [VehicleProfileUpdate] distinguishes "clear"
/// from "leave alone".
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now.add(const Duration(days: 365)),
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 15),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.event_outlined)
              : IconButton(
                  tooltip: const S('Clear', 'مسح').of(context),
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          value == null
              ? const S('Not set', 'مش متحدد').of(context)
              : DateFormat.yMMMd().format(value!),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: value == null ? colors.textMuted : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MaintenanceLogCard extends StatelessWidget {
  const _MaintenanceLogCard({
    required this.schoolId,
    required this.bus,
    required this.open,
    required this.completed,
    required this.now,
  });

  final String schoolId;
  final SchoolBus bus;
  final List<MaintenanceRecord> open;
  final List<MaintenanceRecord> completed;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: const S('Maintenance log', 'سجل الصيانة').of(context),
            trailing: AppButton.secondary(
              icon: Icons.add,
              label: const S('Add item', 'إضافة بند').of(context),
              onPressed: () => _addItem(context),
            ),
          ),
          if (open.isEmpty && completed.isEmpty)
            EmptyStateView(
              compact: true,
              icon: Icons.build_outlined,
              title: const S(
                'Nothing scheduled yet.',
                'مفيش حاجة متجدولة لسه.',
              ).of(context),
              message: const S(
                'Add an oil change, tire, brake, inspection, insurance or '
                    'registration item with its due date.',
                'ضيف بند تغيير زيت أو كاوتش أو فرامل أو فحص أو تأمين أو '
                    'رخصة تسيير بتاريخ استحقاقه.',
              ).of(context),
            )
          else ...[
            if (open.isNotEmpty) ...[
              Text(
                const S('Due', 'مستحق').of(context).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final record in open)
                _MaintenanceTile(
                  key: ValueKey(record.id),
                  schoolId: schoolId,
                  busId: bus.id,
                  record: record,
                  now: now,
                ),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                const S('Completed', 'مكتمل').of(context).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final record in completed.take(10))
                _MaintenanceTile(
                  key: ValueKey(record.id),
                  schoolId: schoolId,
                  busId: bus.id,
                  record: record,
                  now: now,
                ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final bloc = context.read<VehicleDetailBloc>();
    final result = await showDialog<_MaintenanceDraft>(
      context: context,
      builder: (dialogContext) => const _MaintenanceDialog(),
    );
    if (result == null) return;

    bloc.add(
      MaintenanceRecordAdded(
        schoolId: schoolId,
        busId: bus.id,
        itemType: result.itemType,
        dueAt: result.dueAt,
        description: result.description,
        notes: result.notes,
      ),
    );
  }
}

class _MaintenanceTile extends StatelessWidget {
  const _MaintenanceTile({
    super.key,
    required this.schoolId,
    required this.busId,
    required this.record,
    required this.now,
  });

  final String schoolId;
  final String busId;
  final MaintenanceRecord record;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    final tone = record.isCompleted
        ? StatusTone.success
        : record.isOverdue(now)
        ? StatusTone.error
        : record.isDueSoon(now)
        ? StatusTone.warning
        : StatusTone.neutral;
    final accent = toneColor(colors, tone);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: tone == StatusTone.error
              ? accent.withValues(alpha: 0.45)
              : colors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(maintenanceItemIcon(record.itemType), size: 20, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maintenanceItemLabel(record.itemType, context),
                  style: theme.textTheme.titleSmall,
                ),
                if (record.description.isNotEmpty)
                  Text(
                    record.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                if (record.isCompleted)
                  StatusBadge(
                    label: S(
                      'Completed ${DateFormat.yMMMd().format(record.completedAt!)}',
                      'اكتمل ${DateFormat.yMMMd().format(record.completedAt!)}',
                    ).of(context),
                    tone: StatusTone.success,
                  )
                else
                  Row(
                    children: [
                      StatusBadge(
                        label: relativeDueLabel(record.dueAt, now, context),
                        tone: tone,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        DateFormat.yMMMd().format(record.dueAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                if (record.notes != null && record.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      record.notes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!record.isCompleted)
            AppButton.secondary(
              label: const S('Complete', 'تم').of(context),
              onPressed: () => _complete(context),
            )
          else
            IconButton(
              tooltip: const S('Delete record', 'حذف السجل').of(context),
              icon: Icon(Icons.delete_outline, color: colors.textMuted),
              onPressed: () => _delete(context),
            ),
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context) async {
    final bloc = context.read<VehicleDetailBloc>();
    final result = await showDialog<_CompletionDraft>(
      context: context,
      builder: (dialogContext) => _CompleteMaintenanceDialog(record: record),
    );
    if (result == null) return;

    bloc.add(
      MaintenanceRecordCompleted(
        schoolId: schoolId,
        busId: busId,
        recordId: record.id,
        itemType: record.itemType,
        nextDueAt: result.nextDueAt,
        notes: result.notes,
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<VehicleDetailBloc>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S(
        'Delete this record?',
        'تمسح السجل ده؟',
      ).of(context),
      message: const S(
        'This removes the completed maintenance record from this vehicle’s '
            'history. This cannot be undone.',
        'ده هيشيل سجل الصيانة المكتمل من تاريخ المركبة دي. الإجراء ده '
            'مينفعش يتراجع فيه.',
      ).of(context),
      confirmLabel: const S('Delete', 'مسح').of(context),
      destructive: true,
    );
    if (confirmed != true) return;

    bloc.add(
      MaintenanceRecordDeleted(
        schoolId: schoolId,
        busId: busId,
        recordId: record.id,
      ),
    );
  }
}

class _MaintenanceDraft {
  const _MaintenanceDraft({
    required this.itemType,
    required this.dueAt,
    required this.description,
    this.notes,
  });

  final MaintenanceItemType itemType;
  final DateTime dueAt;
  final String description;
  final String? notes;
}

class _MaintenanceDialog extends StatefulWidget {
  const _MaintenanceDialog();

  @override
  State<_MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<_MaintenanceDialog> {
  MaintenanceItemType _itemType = MaintenanceItemType.oilChange;
  DateTime _dueAt = DateTime.now().add(const Duration(days: 30));
  final _description = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        const S('Add maintenance item', 'إضافة بند صيانة').of(context),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<MaintenanceItemType>(
                initialValue: _itemType,
                decoration: InputDecoration(
                  labelText: const S('Item', 'البند').of(context),
                ),
                items: [
                  for (final type in MaintenanceItemType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(maintenanceItemLabel(type, context)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _itemType = value ?? _itemType),
              ),
              const SizedBox(height: AppSpacing.md),
              _DateField(
                label: const S('Due date', 'تاريخ الاستحقاق').of(context),
                value: _dueAt,
                onChanged: (value) {
                  if (value != null) setState(() => _dueAt = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: const S('Description', 'الوصف').of(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: const S('Notes', 'ملاحظات').of(context),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton.secondary(
          label: const S('Cancel', 'إلغاء').of(context),
          onPressed: () => Navigator.pop(context),
        ),
        AppButton.primary(
          label: const S('Add', 'إضافة').of(context),
          onPressed: () => Navigator.pop(
            context,
            _MaintenanceDraft(
              itemType: _itemType,
              dueAt: _dueAt,
              description: _description.text,
              notes: _notes.text.trim().isEmpty ? null : _notes.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompletionDraft {
  const _CompletionDraft({this.nextDueAt, this.notes});
  final DateTime? nextDueAt;
  final String? notes;
}

class _CompleteMaintenanceDialog extends StatefulWidget {
  const _CompleteMaintenanceDialog({required this.record});

  final MaintenanceRecord record;

  @override
  State<_CompleteMaintenanceDialog> createState() =>
      _CompleteMaintenanceDialogState();
}

class _CompleteMaintenanceDialogState
    extends State<_CompleteMaintenanceDialog> {
  DateTime? _nextDueAt = DateTime.now().add(const Duration(days: 180));
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Only these three item types have a matching expiry field on the bus
  /// document, so only for them does the next-due date also refresh the
  /// vehicle-level warning indicator — the dialog says so rather than
  /// leaving the admin to guess.
  bool get _updatesVehicleDocument =>
      widget.record.itemType == MaintenanceItemType.insurance ||
      widget.record.itemType == MaintenanceItemType.registration ||
      widget.record.itemType == MaintenanceItemType.inspection;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        S(
          'Complete ${maintenanceItemLabel(widget.record.itemType, context)}',
          'إنهاء ${maintenanceItemLabel(widget.record.itemType, context)}',
        ).of(context),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _updatesVehicleDocument
                    ? const S(
                        'Set the new expiry date. It updates this vehicle’s '
                            'document status and schedules the next item.',
                        'حدد تاريخ الانتهاء الجديد. ده هيحدّث حالة أوراق '
                            'المركبة ويجدول البند اللي بعده.',
                      ).of(context)
                    : const S(
                        'Set when this is next due to schedule the following '
                            'item, or clear it to just close this one.',
                        'حدد إمتى البند ده مستحق تاني عشان يتجدول، أو امسح '
                            'التاريخ عشان تقفل البند ده بس.',
                      ).of(context),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _DateField(
                label: _updatesVehicleDocument
                    ? const S('New expiry date', 'تاريخ الانتهاء الجديد').of(
                        context,
                      )
                    : const S('Next due date', 'الاستحقاق الجاي').of(context),
                value: _nextDueAt,
                onChanged: (value) => setState(() => _nextDueAt = value),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: const S('Notes', 'ملاحظات').of(context),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton.secondary(
          label: const S('Cancel', 'إلغاء').of(context),
          onPressed: () => Navigator.pop(context),
        ),
        AppButton.primary(
          label: const S('Mark complete', 'تم الإنجاز').of(context),
          onPressed: () => Navigator.pop(
            context,
            _CompletionDraft(
              nextDueAt: _nextDueAt,
              notes: _notes.text.trim().isEmpty ? null : _notes.text,
            ),
          ),
        ),
      ],
    );
  }
}
