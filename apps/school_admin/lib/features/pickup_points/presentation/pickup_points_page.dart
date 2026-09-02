import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../../common/presentation/location_picker_page.dart';
import '../../routes/data/routes_repository.dart';
import '../../students/data/students_repository.dart';
import '../../../widgets/async_error_view.dart';
import '../data/pickup_points_repository.dart';
import '../domain/nearest_pickup_point.dart';
import 'bloc/pickup_points_bloc.dart';

/// Admin-managed shared pickup locations, plus the screen for assigning a
/// student to one.
///
/// Two tabs: the points themselves (CRUD, with the map picker), and a
/// student-assignment view that offers the nearest points to each
/// student's own coordinate. That suggestion is a plain distance sort —
/// see [rankPickupPointsByDistance], which is explicit that nothing
/// predictive is happening.
class PickupPointsPage extends StatelessWidget {
  const PickupPointsPage({
    super.key,
    required this.schoolId,
    this.showAppBar = true,
  });

  final String schoolId;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PickupPointsBloc(PickupPointsRepository())
        ..add(PickupPointsStarted(schoolId)),
      child: _PickupPointsView(schoolId: schoolId, showAppBar: showAppBar),
    );
  }
}

class _PickupPointsView extends StatelessWidget {
  const _PickupPointsView({required this.schoolId, required this.showAppBar});

  final String schoolId;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PickupPointsBloc, PickupPointsState>(
      listenWhen: (_, current) =>
          current is PickupPointsLoaded && current.actionError != null,
      listener: (context, state) {
        if (state is PickupPointsLoaded && state.actionError != null) {
          AppSnackbar.error(context, state.actionError!);
        }
      },
      builder: (context, state) {
        if (state is PickupPointsLoading || state is PickupPointsInitial) {
          return Scaffold(
            appBar: showAppBar
                ? AppBar(
                    title: Text(
                      const S('Pickup points', 'نقاط الاستلام').of(context),
                    ),
                  )
                : null,
            body: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 5,
              itemBuilder: (_, _) => const AppSkeletonListTile(),
            ),
          );
        }

        if (state is PickupPointsFailure) {
          return Scaffold(
            appBar: showAppBar
                ? AppBar(
                    title: Text(
                      const S('Pickup points', 'نقاط الاستلام').of(context),
                    ),
                  )
                : null,
            body: ErrorStateView(
              message: state.message,
              onRetry: () => context.read<PickupPointsBloc>().add(
                PickupPointsStarted(schoolId),
              ),
            ),
          );
        }

        final points = (state as PickupPointsLoaded).snapshot.docs
            .map((doc) => PickupPoint.fromMap(doc.id, doc.data()))
            .toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: showAppBar
                  ? Text(const S('Pickup points', 'نقاط الاستلام').of(context))
                  : null,
              toolbarHeight: showAppBar ? null : 0,
              bottom: TabBar(
                tabs: [
                  Tab(text: const S('Points', 'النقاط').of(context)),
                  Tab(
                    text: const S(
                      'Student assignment',
                      'تخصيص الطلاب',
                    ).of(context),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              // The Operations tab host keeps every sub-tab mounted at
              // once it's been visited (TabBarView) — see the same fix on
              // the other Operations/People tab FABs in admin_home_page.dart.
              heroTag: 'pickup-points-add-fab',
              onPressed: () => _createPoint(context, schoolId),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(const S('Pickup point', 'نقطة استلام').of(context)),
            ),
            body: TabBarView(
              children: [
                _PointsTab(schoolId: schoolId, points: points),
                _StudentAssignmentTab(schoolId: schoolId, points: points),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _createPoint(BuildContext context, String schoolId) async {
  final bloc = context.read<PickupPointsBloc>();
  final draft = await showDialog<_PointDraft>(
    context: context,
    builder: (dialogContext) => _PickupPointDialog(schoolId: schoolId),
  );
  if (draft == null) return;

  bloc.add(
    PickupPointCreated(
      schoolId: schoolId,
      name: draft.name,
      latitude: draft.latitude,
      longitude: draft.longitude,
      routeId: draft.routeId,
      radiusMeters: draft.radiusMeters,
    ),
  );
}

class _PointsTab extends StatelessWidget {
  const _PointsTab({required this.schoolId, required this.points});

  final String schoolId;
  final List<PickupPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return EmptyStateView(
        icon: Icons.place_outlined,
        title: const S(
          'No pickup points yet',
          'مفيش نقاط استلام لسه',
        ).of(context),
        message: const S(
          'Create shared pickup locations so students can be collected at a '
              'nearby safe point instead of at their exact home address.',
          'اعمل نقاط استلام مشتركة عشان الطلاب يتاخدوا من نقطة آمنة قريبة '
              'بدل عنوان البيت بالظبط.',
        ).of(context),
        actionLabel: const S('Add pickup point', 'إضافة نقطة').of(context),
        onAction: () => _createPoint(context, schoolId),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: RoutesRepository().watchRoutes(schoolId),
          builder: (context, routesSnapshot) {
            final routeNames = {
              for (final doc in routesSnapshot.data?.docs ?? const [])
                doc.id: doc.data()['name']?.toString() ?? doc.id,
            };

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl6,
              ),
              children: [
                SectionHeader(
                  title: const S(
                    'Shared pickup locations',
                    'نقاط الاستلام المشتركة',
                  ).of(context),
                  subtitle: S(
                    '${points.where((p) => p.isActive).length} active of '
                        '${points.length}',
                    '${points.where((p) => p.isActive).length} نشطة من '
                        '${points.length}',
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
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final point in points)
                          SizedBox(
                            width: cardWidth,
                            child: _PickupPointCard(
                              key: ValueKey(point.id),
                              schoolId: schoolId,
                              point: point,
                              routeName: point.routeId == null
                                  ? null
                                  : routeNames[point.routeId!],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PickupPointCard extends StatelessWidget {
  const _PickupPointCard({
    super.key,
    required this.schoolId,
    required this.point,
    required this.routeName,
  });

  final String schoolId;
  final PickupPoint point;
  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
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
                  color: (point.isActive ? colors.info : colors.textMuted)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.place,
                  size: 22,
                  color: point.isActive ? colors.info : colors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      routeName ??
                          const S('No route', 'من غير خط').of(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: point.isActive
                    ? const S('Active', 'نشطة').of(context)
                    : const S('Inactive', 'غير نشطة').of(context),
                tone: point.isActive ? StatusTone.success : StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.my_location, size: 14, color: colors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${point.latitude.toStringAsFixed(5)}, '
                    '${point.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.adjust, size: 14, color: colors.textMuted),
              const SizedBox(width: 4),
              Text(
                S(
                  'Safe zone ${point.radiusMeters.round()} m',
                  'نطاق آمن ${point.radiusMeters.round()} متر',
                ).of(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppButton.secondary(
                icon: Icons.edit_outlined,
                label: const S('Edit', 'تعديل').of(context),
                onPressed: () => _edit(context),
              ),
              const Spacer(),
              Switch(
                value: point.isActive,
                onChanged: (value) => context.read<PickupPointsBloc>().add(
                  PickupPointStatusChanged(
                    schoolId: schoolId,
                    pickupPointId: point.id,
                    isActive: value,
                  ),
                ),
              ),
              IconButton(
                tooltip: const S('Delete', 'مسح').of(context),
                icon: Icon(Icons.delete_outline, color: colors.textMuted),
                onPressed: () => _delete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final bloc = context.read<PickupPointsBloc>();
    final draft = await showDialog<_PointDraft>(
      context: context,
      builder: (dialogContext) =>
          _PickupPointDialog(schoolId: schoolId, existing: point),
    );
    if (draft == null) return;

    bloc.add(
      PickupPointUpdated(
        schoolId: schoolId,
        pickupPointId: point.id,
        name: draft.name,
        latitude: draft.latitude,
        longitude: draft.longitude,
        routeId: draft.routeId,
        radiusMeters: draft.radiusMeters,
        isActive: point.isActive,
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<PickupPointsBloc>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S(
        'Delete this pickup point?',
        'تمسح نقطة الاستلام دي؟',
      ).of(context),
      message: const S(
        'Students currently assigned to it will fall back to their own home '
            'coordinate. This cannot be undone.',
        'الطلاب المخصصين ليها هيرجعوا لإحداثيات بيتهم. الإجراء ده مينفعش '
            'يتراجع فيه.',
      ).of(context),
      confirmLabel: const S('Delete', 'مسح').of(context),
      destructive: true,
    );
    if (confirmed != true) return;

    bloc.add(
      PickupPointDeleted(schoolId: schoolId, pickupPointId: point.id),
    );
  }
}

class _PointDraft {
  const _PointDraft({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.routeId,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String? routeId;
}

class _PickupPointDialog extends StatefulWidget {
  const _PickupPointDialog({required this.schoolId, this.existing});

  final String schoolId;
  final PickupPoint? existing;

  @override
  State<_PickupPointDialog> createState() => _PickupPointDialogState();
}

class _PickupPointDialogState extends State<_PickupPointDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _radius = TextEditingController(
    text: (widget.existing?.radiusMeters ?? 100).round().toString(),
  );
  late double? _latitude = widget.existing?.latitude;
  late double? _longitude = widget.existing?.longitude;
  late String? _routeId = widget.existing?.routeId;

  @override
  void dispose() {
    _name.dispose();
    _radius.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _latitude != null && _longitude != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? const S('Add pickup point', 'إضافة نقطة استلام').of(context)
            : const S('Edit pickup point', 'تعديل نقطة الاستلام').of(context),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: const S('Name', 'الاسم').of(context),
                  hintText: const S(
                    'e.g. Maadi Club gate',
                    'مثلاً بوابة نادي المعادي',
                  ).of(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: RoutesRepository().watchRoutes(widget.schoolId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  final routes = snapshot.data?.docs ?? const [];
                  final known = routes.any((doc) => doc.id == _routeId);
                  return DropdownButtonFormField<String?>(
                    initialValue: known ? _routeId : null,
                    decoration: InputDecoration(
                      labelText: const S('Route', 'الخط').of(context),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          const S('No route', 'من غير خط').of(context),
                        ),
                      ),
                      for (final doc in routes)
                        DropdownMenuItem<String?>(
                          value: doc.id,
                          child: Text(
                            doc.data()['name']?.toString() ?? doc.id,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _routeId = value),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _radius,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: const S(
                    'Safe-zone radius (metres)',
                    'نطاق الأمان (متر)',
                  ).of(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(
                    _latitude == null
                        ? Icons.location_off_outlined
                        : Icons.location_on,
                    size: 18,
                    color: _latitude == null ? colors.textMuted : colors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _latitude == null
                        ? Text(
                            const S(
                              'No location picked yet.',
                              'لسه مفيش مكان متحدد.',
                            ).of(context),
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              'Lat ${_latitude!.toStringAsFixed(5)}, '
                              'Lng ${_longitude!.toStringAsFixed(5)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton.secondary(
                    icon: _latitude == null
                        ? Icons.add_location_alt
                        : Icons.edit_location_alt,
                    label: _latitude == null
                        ? const S('Set', 'تحديد').of(context)
                        : const S('Edit', 'تعديل').of(context),
                    onPressed: () async {
                      final picked = await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPickerPage(
                            title: const S(
                              'Set pickup point',
                              'تحديد نقطة الاستلام',
                            ).of(context),
                            initialPosition:
                                _latitude == null || _longitude == null
                                ? null
                                : LatLng(_latitude!, _longitude!),
                          ),
                        ),
                      );
                      if (picked == null) return;
                      setState(() {
                        _latitude = picked.latitude;
                        _longitude = picked.longitude;
                      });
                    },
                  ),
                ],
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
          label: const S('Save', 'حفظ').of(context),
          onPressed: _canSave
              ? () => Navigator.pop(
                  context,
                  _PointDraft(
                    name: _name.text,
                    latitude: _latitude!,
                    longitude: _longitude!,
                    radiusMeters:
                        double.tryParse(_radius.text.trim()) ?? 100,
                    routeId: _routeId,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// Assigns students to a shared pickup point, offering the nearest ones
/// first. The ordering is plain distance — see
/// [rankPickupPointsByDistance].
class _StudentAssignmentTab extends StatelessWidget {
  const _StudentAssignmentTab({required this.schoolId, required this.points});

  final String schoolId;
  final List<PickupPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return EmptyStateView(
        icon: Icons.place_outlined,
        title: const S(
          'Create a pickup point first',
          'اعمل نقطة استلام الأول',
        ).of(context),
        message: const S(
          'Students can only be assigned once at least one shared pickup '
              'point exists.',
          'الطلاب مينفعش يتخصصوا غير لما تبقى فيه نقطة استلام مشتركة واحدة '
              'على الأقل.',
        ).of(context),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: StudentsRepository().watchStudents(schoolId, limit: 200),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AsyncErrorView();
        if (!snapshot.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 6,
            itemBuilder: (_, _) => const AppSkeletonListTile(),
          );
        }

        final students = snapshot.data!.docs
            .map((doc) => Student.fromMap(doc.id, doc.data()))
            .where((student) => student.isActive && student.approved)
            .toList();

        if (students.isEmpty) {
          return EmptyStateView(
            icon: Icons.groups_outlined,
            title: const S(
              'No active students to assign.',
              'مفيش طلاب نشطين للتخصيص.',
            ).of(context),
          );
        }

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
                SectionHeader(
                  title: const S(
                    'Assign students',
                    'تخصيص الطلاب',
                  ).of(context),
                  subtitle: const S(
                    'Suggestions are ordered by straight-line distance from '
                        'the student’s own pickup coordinate — nothing more.',
                    'الاقتراحات مرتبة حسب المسافة المباشرة من إحداثيات '
                        'الطالب نفسه — مفيش أكتر من كده.',
                  ).of(context),
                ),
                for (final student in students)
                  _StudentAssignmentRow(
                    key: ValueKey(student.id),
                    schoolId: schoolId,
                    student: student,
                    points: points,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudentAssignmentRow extends StatelessWidget {
  const _StudentAssignmentRow({
    super.key,
    required this.schoolId,
    required this.student,
    required this.points,
  });

  final String schoolId;
  final Student student;
  final List<PickupPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    final assigned = points
        .where((point) => point.id == student.pickupPointId)
        .firstOrNull;
    final suggestions = rankPickupPointsByDistance(
      studentLatitude: student.latitude,
      studentLongitude: student.longitude,
      points: points,
      limit: 3,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.surfaceElevated,
                foregroundColor: colors.textSecondary,
                child: const Icon(Icons.person),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      assigned == null
                          ? const S(
                              'Uses their own home coordinate',
                              'بيستخدم إحداثيات بيته',
                            ).of(context)
                          : S(
                              'Assigned to ${assigned.name}',
                              'مخصص لـ ${assigned.name}',
                            ).of(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: assigned == null
                            ? colors.textMuted
                            : colors.success,
                      ),
                    ),
                  ],
                ),
              ),
              if (assigned != null)
                AppButton.secondary(
                  label: const S('Unassign', 'إلغاء التخصيص').of(context),
                  onPressed: () => context.read<PickupPointsBloc>().add(
                    StudentPickupPointAssigned(
                      schoolId: schoolId,
                      studentId: student.id,
                      pickupPointId: null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!student.hasLocation)
            Text(
              const S(
                'This student has no pickup coordinate set, so no nearest '
                    'point can be calculated. Set one from the Students tab, '
                    'or pick a point manually below.',
                'الطالب ده مفيش ليه إحداثيات استلام، فمش هينفع نحسب أقرب '
                    'نقطة. حددها من تبويب الطلاب أو اختار نقطة يدوي تحت.',
              ).of(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final suggestion in suggestions)
                  ActionChip(
                    avatar: Icon(
                      suggestion.withinRadius
                          ? Icons.check_circle_outline
                          : Icons.place_outlined,
                      size: 16,
                      color: suggestion.withinRadius
                          ? colors.success
                          : colors.textSecondary,
                    ),
                    label: Text(
                      '${suggestion.point.name} · '
                      '${formatDistance(suggestion.distanceMeters)}',
                    ),
                    onPressed: suggestion.point.id == student.pickupPointId
                        ? null
                        : () => context.read<PickupPointsBloc>().add(
                            StudentPickupPointAssigned(
                              schoolId: schoolId,
                              studentId: student.id,
                              pickupPointId: suggestion.point.id,
                            ),
                          ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: assigned?.id,
            isDense: true,
            decoration: InputDecoration(
              labelText: const S(
                'Assign to any point',
                'تخصيص لأي نقطة',
              ).of(context),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  const S('No shared point', 'من غير نقطة مشتركة').of(context),
                ),
              ),
              for (final point in points.where((p) => p.isActive))
                DropdownMenuItem<String?>(
                  value: point.id,
                  child: Text(point.name),
                ),
            ],
            onChanged: (value) => context.read<PickupPointsBloc>().add(
              StudentPickupPointAssigned(
                schoolId: schoolId,
                studentId: student.id,
                pickupPointId: value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
