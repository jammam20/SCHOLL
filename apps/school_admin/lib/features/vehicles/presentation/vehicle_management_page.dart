import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../buses/data/buses_repository.dart';
import '../../buses/presentation/bloc/buses_bloc.dart';
import '../../common/presentation/domain_labels.dart';
import '../data/vehicles_repository.dart';
import 'bloc/vehicles_bloc.dart';
import 'vehicle_detail_page.dart';

/// The fleet, with each vehicle's document status front and centre.
///
/// This replaces the old inline `_BusesTab`: it does everything that tab
/// did (list every bus, add a bus, activate/deactivate) *plus* the vehicle
/// profile and maintenance work, so keeping both would have meant two
/// competing places to manage the same records. The activate/deactivate
/// switch and the add-bus dialog still go through the unchanged
/// [BusesBloc]/[BusesRepository] so that existing behavior is untouched.
class VehicleManagementPage extends StatelessWidget {
  const VehicleManagementPage({
    super.key,
    required this.schoolId,
    this.readOnly = false,
    this.showAppBar = false,
  });

  final String schoolId;

  /// Staff (read-only role) get the same fleet visibility with no add
  /// button, no status switch and no navigation into the editable detail
  /// page.
  final bool readOnly;

  /// True when pushed as its own route; false when hosted inside the
  /// Operations section's TabBarView, which already provides an app bar.
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              VehiclesBloc(VehiclesRepository())..add(VehiclesStarted(schoolId)),
        ),
        BlocProvider(
          create: (_) => BusesBloc(BusesRepository())..add(BusesStarted(schoolId)),
        ),
      ],
      child: _VehicleManagementView(
        schoolId: schoolId,
        readOnly: readOnly,
        showAppBar: showAppBar,
      ),
    );
  }
}

class _VehicleManagementView extends StatelessWidget {
  const _VehicleManagementView({
    required this.schoolId,
    required this.readOnly,
    required this.showAppBar,
  });

  final String schoolId;
  final bool readOnly;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VehiclesBloc, VehiclesState>(
      builder: (context, state) {
        Widget body;

        if (state is VehiclesLoading || state is VehiclesInitial) {
          body = ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 5,
            itemBuilder: (_, _) => const AppSkeletonListTile(),
          );
        } else if (state is VehiclesFailure) {
          body = ErrorStateView(
            message: state.message,
            onRetry: () =>
                context.read<VehiclesBloc>().add(VehiclesStarted(schoolId)),
          );
        } else {
          final snapshot = state is VehiclesLoaded ? state.snapshot : null;
          final buses = (snapshot?.docs ?? const [])
              .map((doc) => SchoolBus.fromMap(doc.id, doc.data()))
              .toList();

          body = buses.isEmpty
              ? EmptyStateView(
                  icon: Icons.directions_bus_outlined,
                  title: const S(
                    'No buses yet.',
                    'مفيش أتوبيسات لسه.',
                  ).of(context),
                  message: const S(
                    'Add your first bus to start tracking its documents, '
                        'maintenance and trip assignments.',
                    'ضيف أول أتوبيس عشان تبدأ تتابع أوراقه وصيانته '
                        'والرحلات المخصصة له.',
                  ).of(context),
                  actionLabel: readOnly
                      ? null
                      : const S('Add bus', 'إضافة أتوبيس').of(context),
                  onAction: readOnly ? null : () => _createBus(context),
                )
              : _FleetList(
                  schoolId: schoolId,
                  buses: buses,
                  readOnly: readOnly,
                );
        }

        return Scaffold(
          appBar: showAppBar
              ? AppBar(
                  title: Text(
                    const S('Vehicles', 'المركبات').of(context),
                  ),
                )
              : null,
          floatingActionButton: readOnly
              ? null
              : FloatingActionButton.extended(
                  // See admin_home_page.dart's Students/Routes/Trips FABs
                  // for why this needs its own tag — the same
                  // TabBarView-keeps-every-tab-mounted reasoning applies
                  // here too.
                  heroTag: 'vehicles-add-fab',
                  onPressed: () => _createBus(context),
                  icon: const Icon(Icons.add),
                  label: Text(const S('Bus', 'أتوبيس').of(context)),
                ),
          body: body,
        );
      },
    );
  }

  /// Unchanged from the tab this page replaces — same dialog, same
  /// [BusCreated] event, same repository write.
  Future<void> _createBus(BuildContext context) async {
    final name = TextEditingController();
    final plate = TextEditingController();
    final capacity = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(const S('Add bus', 'إضافة أتوبيس').of(dialogContext)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: const S('Name', 'الاسم').of(dialogContext),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: plate,
                decoration: InputDecoration(
                  labelText: const S(
                    'Plate number',
                    'رقم اللوحة',
                  ).of(dialogContext),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: capacity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: const S('Capacity', 'السعة').of(dialogContext),
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButton.secondary(
            label: const S('Cancel', 'إلغاء').of(dialogContext),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButton.primary(
            label: const S('Save', 'حفظ').of(dialogContext),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    if (result == true && name.text.trim().isNotEmpty) {
      context.read<BusesBloc>().add(
        BusCreated(
          schoolId: schoolId,
          name: name.text,
          plateNumber: plate.text,
          capacity: int.tryParse(capacity.text),
        ),
      );
    }

    name.dispose();
    plate.dispose();
    capacity.dispose();
  }
}

class _FleetList extends StatelessWidget {
  const _FleetList({
    required this.schoolId,
    required this.buses,
    required this.readOnly,
  });

  final String schoolId;
  final List<SchoolBus> buses;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();

    final needingAttention = buses
        .where((bus) => bus.hasExpiringDocuments(now))
        .length;
    final active = buses.where((bus) => bus.isActive).length;
    final unprofiled = buses
        .where(
          (bus) =>
              bus.insuranceExpiry == null &&
              bus.registrationExpiry == null &&
              bus.inspectionExpiry == null,
        )
        .length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl6,
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
                    icon: Icons.directions_bus,
                    tone: colors.success,
                    label: const S(
                      'Active vehicles',
                      'المركبات النشطة',
                    ).of(context),
                    value: '$active / ${buses.length}',
                  ),
                  MetricStatCard(
                    icon: Icons.warning_amber_rounded,
                    tone: needingAttention > 0 ? colors.warning : colors.success,
                    label: const S(
                      'Documents expiring or overdue',
                      'أوراق قربت تنتهي أو متأخرة',
                    ).of(context),
                    value: '$needingAttention',
                  ),
                  MetricStatCard(
                    icon: Icons.help_outline,
                    tone: colors.info,
                    label: const S(
                      'No documents recorded',
                      'من غير أوراق مسجلة',
                    ).of(context),
                    value: '$unprofiled',
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
              title: const S('Fleet', 'الأسطول').of(context),
              subtitle: const S(
                'Insurance, registration and inspection expiry at a glance. '
                    'Open a vehicle to edit its profile and maintenance log.',
                'التأمين ورخصة التسيير والفحص في نظرة واحدة. افتح المركبة '
                    'عشان تعدّل بياناتها وسجل صيانتها.',
              ).of(context),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.md;
                final columns = constraints.maxWidth >= 1080
                    ? 3
                    : constraints.maxWidth >= 720
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final bus in buses)
                      SizedBox(
                        width: cardWidth,
                        child: _VehicleCard(
                          key: ValueKey(bus.id),
                          schoolId: schoolId,
                          bus: bus,
                          readOnly: readOnly,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    super.key,
    required this.schoolId,
    required this.bus,
    required this.readOnly,
  });

  final String schoolId;
  final SchoolBus bus;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final needsAttention = bus.hasExpiringDocuments(now);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: readOnly
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    VehicleDetailPage(schoolId: schoolId, busId: bus.id),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: needsAttention
                ? colors.warning.withValues(alpha: 0.45)
                : colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (bus.isActive ? colors.success : colors.textMuted)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    size: 22,
                    color: bus.isActive ? colors.success : colors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.name,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          bus.plateNumber,
                          if (bus.model != null) bus.model!,
                          if (bus.year != null) '${bus.year}',
                          if (bus.capacity != null)
                            S(
                              '${bus.capacity} seats',
                              '${bus.capacity} كرسي',
                            ).of(context),
                        ].where((part) => part.isNotEmpty).join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (needsAttention)
                  Tooltip(
                    message: const S(
                      'One or more documents expire within 30 days, or have '
                          'already expired.',
                      'فيه ورقة أو أكتر هتنتهي خلال 30 يوم أو منتهية خلاص.',
                    ).of(context),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: colors.warning,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _ExpiryRow(
              label: const S('Insurance', 'التأمين').of(context),
              expiry: bus.insuranceExpiry,
              now: now,
            ),
            _ExpiryRow(
              label: const S('Registration', 'رخصة التسيير').of(context),
              expiry: bus.registrationExpiry,
              now: now,
            ),
            _ExpiryRow(
              label: const S('Inspection', 'الفحص الفني').of(context),
              expiry: bus.inspectionExpiry,
              now: now,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                StatusBadge(
                  label: bus.isActive
                      ? const S('Active', 'نشطة').of(context)
                      : const S('Inactive', 'غير نشطة').of(context),
                  tone: bus.isActive ? StatusTone.success : StatusTone.neutral,
                ),
                const Spacer(),
                if (!readOnly)
                  Switch(
                    value: bus.isActive,
                    onChanged: (value) => context.read<BusesBloc>().add(
                      BusStatusChanged(
                        schoolId: schoolId,
                        busId: bus.id,
                        active: value,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({
    required this.label,
    required this.expiry,
    required this.now,
  });

  final String label;
  final DateTime? expiry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final tone = dueDateTone(expiry, now);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          if (expiry == null)
            Text(
              const S('Not recorded', 'مش مسجلة').of(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
              ),
            )
          else
            StatusBadge(
              label: relativeDueLabel(expiry!, now, context),
              tone: tone,
            ),
        ],
      ),
    );
  }
}
