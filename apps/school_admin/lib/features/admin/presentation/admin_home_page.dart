import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui show TextDirection;

import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/notification_routing.dart';
import '../../audit/presentation/audit_trail_page.dart';
import '../../buses/data/buses_repository.dart';
import '../../common/presentation/location_picker_page.dart';
import '../../dashboard/presentation/control_center_tab.dart';
import '../../driver_management/presentation/driver_management_page.dart';
import '../../drivers/data/drivers_repository.dart';
import '../../drivers/presentation/bloc/drivers_bloc.dart';
import '../../incidents/presentation/incidents_page.dart';
import '../../messages/data/parent_messages_repository.dart';
import '../../messages/presentation/parent_messages_page.dart';
import '../../ops/presentation/live_ops_tab.dart';
import '../../pickup_points/presentation/pickup_points_page.dart';
import '../../driver_management/presentation/driver_detail_page.dart';
import '../../parents/data/parents_repository.dart';
import '../../parents/presentation/bloc/parents_bloc.dart';
import '../../parents/presentation/parent_detail_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../reports/presentation/reports_tab.dart';
import '../../routes/data/routes_repository.dart';
import '../../routes/presentation/bloc/routes_bloc.dart';
import '../../routes/presentation/route_deviations_page.dart';
import '../../schools/data/schools_repository.dart';
import '../../students/data/students_repository.dart';
import '../../students/presentation/bloc/students_bloc.dart';
import '../../students/presentation/student_detail_page.dart';
import '../../trips/data/trips_repository.dart';
import '../../trips/presentation/bloc/trips_bloc.dart';
import '../../trips/presentation/trip_reassignment_dialog.dart';
import '../../vehicles/presentation/vehicle_management_page.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/pending_approval_card.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _index = 0;

  /// Which tab inside the Operations section to open when the dashboard's
  /// alert feed jumps here. Read (and cleared) by [_OperationsSection] so a
  /// jump lands on the right sub-tab, not just the section's first one.
  final ValueNotifier<int?> _operationsTabRequest = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    // The only push notification this app ever receives is an emergency
    // alert (see functions/src/index.ts: onTripStatusChanged) — tapping one
    // should open Operations, where Live Ops/emergencies live.
    NotificationRouting.pendingTarget.addListener(_onNotificationTapped);
    _onNotificationTapped();
  }

  @override
  void dispose() {
    NotificationRouting.pendingTarget.removeListener(_onNotificationTapped);
    _operationsTabRequest.dispose();
    super.dispose();
  }

  void _onNotificationTapped() {
    if (NotificationRouting.pendingTarget.value == null) return;
    NotificationRouting.pendingTarget.value = null;
    setState(() => _index = 2);
    _operationsTabRequest.value = _OperationsSection.liveMapTab;
  }

  /// Routes a dashboard alert to the surface that owns it, reusing the same
  /// index-based tab switching the notification handler above already uses
  /// rather than introducing a second navigation concept.
  void _onDashboardJump(DashboardJumpTarget target) {
    switch (target) {
      case DashboardJumpTarget.liveOps:
        setState(() => _index = 2);
        _operationsTabRequest.value = _OperationsSection.liveMapTab;
      case DashboardJumpTarget.incidents:
        setState(() => _index = 2);
        _operationsTabRequest.value = _OperationsSection.incidentsTab;
      case DashboardJumpTarget.deviations:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RouteDeviationsPage(schoolId: widget.user.schoolId),
          ),
        );
      case DashboardJumpTarget.people:
        setState(() => _index = 1);
      case DashboardJumpTarget.operations:
        setState(() => _index = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = widget.user.schoolId;
    final pages = [
      ControlCenterTab(user: widget.user, onJump: _onDashboardJump),
      _PeopleSection(schoolId: schoolId),
      _OperationsSection(
        schoolId: schoolId,
        tabRequest: _operationsTabRequest,
      ),
      ReportsTab(schoolId: schoolId),
      ParentMessagesPage(schoolId: schoolId),
      ProfilePage(user: widget.user, onSignOut: widget.onSignOut),
    ];

    final appColors = context.appColors;

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: DecoratedBox(
        // A hairline top border reads as a crisper, more deliberate seam
        // between content and navigation than elevation/shadow alone —
        // consistent with the design system's flat, border-forward surfaces
        // (see design-system/MASTER.md §6). The NavigationBar itself keeps
        // its existing selection/callback wiring untouched.
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: appColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: const S('Dashboard', 'الرئيسية').of(context),
            ),
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups),
              label: const S('People', 'الأشخاص').of(context),
            ),
            NavigationDestination(
              icon: const Icon(Icons.alt_route_outlined),
              selectedIcon: const Icon(Icons.alt_route),
              label: const S('Operations', 'العمليات').of(context),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: const S('Reports', 'التقارير').of(context),
            ),
            NavigationDestination(
              icon: _MessagesIcon(
                schoolId: schoolId,
                selected: false,
              ),
              selectedIcon: _MessagesIcon(
                schoolId: schoolId,
                selected: true,
              ),
              label: const S('Messages', 'الرسايل').of(context),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: const S('Profile', 'حسابي').of(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// A nav-bar icon with a live unread-count badge for the parent-messages
/// inbox — the same "don't disagree with what's inside" pattern the parent
/// app's own notification bell uses.
class _MessagesIcon extends StatelessWidget {
  const _MessagesIcon({required this.schoolId, required this.selected});

  final String schoolId;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ParentMessagesRepository().watchUnreadCount(schoolId),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        final icon = Icon(
          selected ? Icons.forum : Icons.forum_outlined,
        );
        return unread > 0 ? Badge.count(count: unread, child: icon) : icon;
      },
    );
  }
}

/// Students, drivers and parents grouped behind one bottom-nav destination,
/// switched with an ordinary top TabBar — three related directories don't
/// each need their own place in the bottom nav.
class _PeopleSection extends StatelessWidget {
  const _PeopleSection({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(const S('People', 'الأشخاص').of(context)),
          bottom: TabBar(
            tabs: [
              Tab(text: const S('Students', 'الطلاب').of(context)),
              Tab(text: const S('Drivers', 'السائقين').of(context)),
              Tab(text: const S('Parents', 'أولياء الأمور').of(context)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StudentsTab(schoolId: schoolId),
            _DriversTab(schoolId: schoolId),
            _ParentsTab(schoolId: schoolId),
          ],
        ),
      ),
    );
  }
}

/// Vehicles, routes, trips, the live map, incidents and pickup points
/// grouped behind one bottom-nav destination — the day-to-day fleet-running
/// side of the app, as opposed to the people directory above.
///
/// The old inline `_BusesTab` has been **replaced** by
/// [VehicleManagementPage] rather than kept alongside it: that page does
/// everything the tab did (list, add, activate/deactivate — still through
/// the unchanged BusesBloc) plus the vehicle profile and maintenance log,
/// so keeping both would have meant two competing places to manage the
/// same bus records.
class _OperationsSection extends StatefulWidget {
  const _OperationsSection({required this.schoolId, required this.tabRequest});

  final String schoolId;

  /// Set by the host page to jump straight to a given sub-tab (from a
  /// notification tap, or a dashboard alert). Cleared once consumed.
  final ValueNotifier<int?> tabRequest;

  /// Tab order: 0 vehicles, 1 routes, 2 trips, 3 live map, 4 incidents,
  /// 5 pickup points. Only the two that something actually jumps to are
  /// named — keeping constants for the rest would just be four unused
  /// fields drifting out of sync with the TabBarView below.
  static const liveMapTab = 3;
  static const incidentsTab = 4;
  static const tabCount = 6;

  @override
  State<_OperationsSection> createState() => _OperationsSectionState();
}

class _OperationsSectionState extends State<_OperationsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: _OperationsSection.tabCount,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    widget.tabRequest.addListener(_onTabRequested);
    _onTabRequested();
  }

  @override
  void dispose() {
    widget.tabRequest.removeListener(_onTabRequested);
    _controller.dispose();
    super.dispose();
  }

  void _onTabRequested() {
    final requested = widget.tabRequest.value;
    if (requested == null) return;
    widget.tabRequest.value = null;
    if (requested >= 0 && requested < _OperationsSection.tabCount) {
      _controller.animateTo(requested);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Operations', 'العمليات').of(context)),
        actions: [
          IconButton(
            tooltip: const S(
              'Route deviations',
              'الخروج عن المسار',
            ).of(context),
            icon: const Icon(Icons.alt_route),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RouteDeviationsPage(schoolId: widget.schoolId),
              ),
            ),
          ),
          IconButton(
            tooltip: const S('Drivers', 'إدارة السائقين').of(context),
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DriverManagementPage(schoolId: widget.schoolId),
              ),
            ),
          ),
          IconButton(
            tooltip: const S('Audit trail', 'سجل التدقيق').of(context),
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuditTrailPage(schoolId: widget.schoolId),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          tabs: [
            Tab(text: const S('Vehicles', 'المركبات').of(context)),
            Tab(text: const S('Routes', 'الخطوط').of(context)),
            Tab(text: const S('Trips', 'الرحلات').of(context)),
            Tab(text: const S('Live map', 'الخريطة المباشرة').of(context)),
            Tab(text: const S('Incidents', 'البلاغات').of(context)),
            Tab(text: const S('Pickup points', 'نقاط الاستلام').of(context)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          VehicleManagementPage(schoolId: widget.schoolId),
          _RoutesTab(schoolId: widget.schoolId),
          _TripsTab(schoolId: widget.schoolId),
          LiveOpsTab(schoolId: widget.schoolId),
          IncidentsPage(schoolId: widget.schoolId),
          PickupPointsPage(schoolId: widget.schoolId, showAppBar: false),
        ],
      ),
    );
  }
}

/// Shared loading placeholder for the three People-tab paginated lists —
/// mirrors the eventual list's shape (avatar + two lines) so the screen
/// doesn't jump/reflow once real content arrives. See
/// `design-system/MASTER.md` §9.
class _PeopleListSkeleton extends StatelessWidget {
  const _PeopleListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      itemBuilder: (_, index) =>
          AppSkeletonListTile(key: ValueKey('skeleton-$index')),
    );
  }
}

/// Maps a member's stored `status` string (drivers/parents — `pending` /
/// `approved` / `suspended` / `rejected`, see `DriversRepository` /
/// `ParentsRepository`) onto the one shared status pattern used everywhere
/// else in the product, per `design-system/MASTER.md` §2/§8.
StatusTone _memberStatusTone(String status) {
  switch (status) {
    case 'approved':
      return StatusTone.success;
    case 'suspended':
    case 'rejected':
      return StatusTone.error;
    case 'pending':
    default:
      return StatusTone.warning;
  }
}

String _memberStatusLabel(BuildContext context, String status) {
  switch (status) {
    case 'approved':
      return const S('Approved', 'مقبول').of(context);
    case 'suspended':
      return const S('Suspended', 'موقوف').of(context);
    case 'rejected':
      return const S('Rejected', 'مرفوض').of(context);
    case 'pending':
    default:
      return const S('Pending', 'قيد الانتظار').of(context);
  }
}

/// Feature: unified accept/reject UI. Shared by the driver and parent
/// directory rows' "more actions" menu — a suspend/reject on an already-
/// approved member now asks for confirmation (and, for reject, a reason)
/// the same way the fresh-pending PendingApprovalCard does, instead of
/// firing straight off a menu tap.
Future<void> _handleMemberAction(
  BuildContext context, {
  required String value,
  required String name,
  required void Function(String? reason) onSuspend,
  required void Function(String? reason) onReject,
}) async {
  if (value != 'suspend' && value != 'reject') return;
  final isReject = value == 'reject';
  final reasonController = TextEditingController();
  final confirmed = await showAppConfirmDialog(
    context,
    title: isReject
        ? S('Reject $name?', 'رفض $name؟').of(context)
        : S('Suspend $name?', 'إيقاف $name؟').of(context),
    message: isReject
        ? const S(
            'They will lose access immediately.',
            'هيفقد الوصول فوراً.',
          ).of(context)
        : const S(
            'They can be re-approved later.',
            'ممكن تتوافق عليه تاني بعدين.',
          ).of(context),
    confirmLabel: isReject
        ? const S('Reject', 'رفض').of(context)
        : const S('Suspend', 'إيقاف').of(context),
    destructive: true,
    reasonController: reasonController,
    reasonHint: const S('Reason (visible in the audit log)', 'السبب (يظهر في سجل التدقيق)')
        .of(context),
  );
  final reason = reasonController.text.trim();
  // Deliberately not disposed here: the dialog's own TextField is still
  // mounted and mid-exit-transition when this Future resolves (showDialog
  // completes as soon as Navigator.pop is called, before the reverse
  // animation finishes), so an immediate dispose() crashes with "A
  // TextEditingController was used after being disposed" the next time
  // that still-animating TextField rebuilds. A short-lived, unowned
  // controller with no other resources is safe to just let the GC collect.
  if (confirmed != true) return;
  if (isReject) {
    onReject(reason.isEmpty ? null : reason);
  } else {
    onSuspend(reason.isEmpty ? null : reason);
  }
}

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          StudentsBloc(StudentsRepository())..add(StudentsStarted(schoolId)),
      child: BlocBuilder<StudentsBloc, StudentsState>(
        builder: (context, state) {
          final reduceMotion = MediaQuery.of(context).disableAnimations;
          final colors = context.appColors;

          Widget body;
          if (state is StudentsLoading || state is StudentsInitial) {
            body = const _PeopleListSkeleton(key: ValueKey('loading'));
          } else if (state is StudentsFailure) {
            body = Center(
              key: const ValueKey('error'),
              child: ErrorStateView(
                message: state.message,
                onRetry: () => context.read<StudentsBloc>().add(
                  StudentsStarted(schoolId),
                ),
              ),
            );
          } else {
            final snapshot = state is StudentsLoaded ? state.snapshot : null;
            final docs = snapshot?.docs ?? const [];
            final hasMore = state is StudentsLoaded && state.hasMore;

            body = docs.isEmpty
                ? EmptyStateView(
                    key: const ValueKey('empty'),
                    icon: Icons.groups_outlined,
                    title: const S('No students yet', 'مفيش طلاب لسه').of(
                      context,
                    ),
                    message: const S(
                      'Add your first student to start assigning routes '
                          'and pickup points.',
                      'ضيف أول طالب عشان تبدأ تحدد الخطوط ونقاط الاستلام.',
                    ).of(context),
                    actionLabel: const S('Add student', 'إضافة طالب').of(
                      context,
                    ),
                    onAction: () => _createStudent(context),
                  )
                : ListView.builder(
                    key: const ValueKey('content'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: docs.length + (hasMore ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == docs.length) {
                        return Padding(
                          key: const ValueKey('load-more'),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Center(
                            child: AppButton.secondary(
                              label: const S('Load more', 'حمّل المزيد').of(
                                context,
                              ),
                              icon: Icons.expand_more,
                              onPressed: () => context
                                  .read<StudentsBloc>()
                                  .add(StudentsLoadMoreRequested()),
                            ),
                          ),
                        );
                      }
                      final doc = docs[index];
                      final data = doc.data();
                      final routeId = data['routeId']?.toString();
                      final parentIds = List<String>.from(
                        data['parentIds'] as List? ?? const [],
                      );
                      final latitude = (data['latitude'] as num?)?.toDouble();
                      final longitude = (data['longitude'] as num?)
                          ?.toDouble();
                      final pendingLatitude =
                          (data['pendingLatitude'] as num?)?.toDouble();
                      final pendingLongitude =
                          (data['pendingLongitude'] as num?)?.toDouble();
                      final hasPendingLocation =
                          pendingLatitude != null && pendingLongitude != null;
                      final approved = data['approved'] != false;
                      final absentOn = data['absentOn'] as String?;
                      final isAbsentToday =
                          absentOn != null && absentOn == todayIsoDate();
                      final isArabic =
                          Localizations.localeOf(context).languageCode ==
                          'ar';

                      if (!approved) {
                        final studentName = data['name']?.toString() ?? '';
                        final bloc = context.read<StudentsBloc>();
                        return Padding(
                          key: ValueKey(doc.id),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: PendingApprovalCard(
                            icon: Icons.hourglass_top,
                            title: studentName,
                            subtitle: const S(
                              'Awaiting approval',
                              'في انتظار الموافقة',
                            ).of(context),
                            actions: [
                              ApprovalAction(
                                label: const S('Approve', 'موافقة').of(context),
                                icon: Icons.check_circle_outline,
                                onConfirmed: (_) async => bloc.add(
                                  StudentApproved(
                                    schoolId: schoolId,
                                    studentId: doc.id,
                                  ),
                                ),
                              ),
                              ApprovalAction(
                                label: const S('Reject', 'رفض').of(context),
                                icon: Icons.cancel_outlined,
                                destructive: true,
                                requiresReason: true,
                                confirmTitle: const S(
                                  'Reject this student?',
                                  'رفض الطالب ده؟',
                                ).of(context),
                                confirmMessage: const S(
                                  "This removes the parent's request — it "
                                      'was never visible to anyone but '
                                      'them.',
                                  'ده هيمسح طلب ولي الأمر — كان مش ظاهر لحد '
                                      'غيره.',
                                ).of(context),
                                onConfirmed: (reason) async => bloc.add(
                                  StudentRejected(
                                    schoolId: schoolId,
                                    studentId: doc.id,
                                    studentName: studentName,
                                    reason: reason,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final isActive = data['isActive'] == true;

                      return Card(
                        key: ValueKey(doc.id),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          // Feature: card -> details -> management — tapping
                          // anywhere on the row (not just the manage icon)
                          // opens the unified student profile.
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentDetailPage(
                                schoolId: schoolId,
                                studentId: doc.id,
                              ),
                            ),
                          ),
                          child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.sm,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: colors.surfaceElevated,
                                foregroundColor: colors.textSecondary,
                                child: const Icon(Icons.person),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['name']?.toString() ?? '',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isArabic
                                          ? 'الصف: ${data['grade'] ?? '-'} · '
                                                '${routeId == null || routeId.isEmpty ? 'من غير خط' : 'الخط متحدد'} · '
                                                '${parentIds.length} ولي أمر مرتبط · '
                                                '${latitude == null ? 'من غير نقطة استلام' : 'نقطة الاستلام متحددة'}'
                                          : 'Grade: ${data['grade'] ?? '-'} · '
                                                '${routeId == null || routeId.isEmpty ? 'No route' : 'Route assigned'} · '
                                                '${parentIds.length} parent(s) linked · '
                                                '${latitude == null ? 'No pickup point' : 'Pickup point set'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                    ),
                                    if (isAbsentToday) ...[
                                      const SizedBox(height: 6),
                                      StatusBadge(
                                        tone: StatusTone.warning,
                                        label: const S(
                                          'Absent today',
                                          'غايب النهاردة',
                                        ).of(context),
                                      ),
                                    ],
                                    if (hasPendingLocation) ...[
                                      const SizedBox(height: 6),
                                      StatusBadge(
                                        tone: StatusTone.info,
                                        label: const S(
                                          'Location suggested by parent',
                                          'موقع مقترح من ولي الأمر',
                                        ).of(context),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: const S(
                                  'Assign route, pickup point & link parents',
                                  'تحديد الخط ونقطة الاستلام وربط أولياء الأمور',
                                ).of(context),
                                icon: Icon(
                                  Icons.manage_accounts,
                                  color: hasPendingLocation ? colors.info : null,
                                ),
                                onPressed: () => _manageStudent(
                                  context,
                                  schoolId: schoolId,
                                  studentId: doc.id,
                                  currentRouteId: routeId,
                                  currentParentIds: parentIds,
                                  currentLatitude: latitude,
                                  currentLongitude: longitude,
                                  pendingLatitude: pendingLatitude,
                                  pendingLongitude: pendingLongitude,
                                ),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (value) {
                                  context.read<StudentsBloc>().add(
                                    StudentStatusChanged(
                                      schoolId: schoolId,
                                      studentId: doc.id,
                                      active: value,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    },
                  );
          }

          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              // The People/Operations tab hosts keep every sub-tab mounted
              // at once (TabBarView, like the parent app's IndexedStack
              // shell — see that fix's own comment), so each of this
              // section's FABs needs its own tag or they collide on
              // Flutter's shared default the moment more than one tab has
              // ever been visited.
              heroTag: 'students-add-fab',
              onPressed: () => _createStudent(context),
              icon: const Icon(Icons.add),
              label: Text(const S('Student', 'طالب').of(context)),
            ),
            body: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : AppDurations.stateSwitch,
              child: body,
            ),
          );
        },
      ),
    );
  }

  Future<void> _createStudent(BuildContext context) async {
    final name = TextEditingController();
    final grade = TextEditingController();
    final phone = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(const S('Add student', 'إضافة طالب').of(dialogContext)),
        content: Column(
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
              controller: grade,
              decoration: InputDecoration(
                labelText: const S('Grade', 'الصف').of(dialogContext),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phone,
              decoration: InputDecoration(
                labelText: const S('Phone', 'التليفون').of(dialogContext),
              ),
            ),
          ],
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
      context.read<StudentsBloc>().add(
        StudentCreated(
          schoolId: schoolId,
          name: name.text,
          grade: grade.text,
          phone: phone.text.isEmpty ? null : phone.text,
        ),
      );
    }

    name.dispose();
    grade.dispose();
    phone.dispose();
  }

  Future<void> _manageStudent(
    BuildContext context, {
    required String schoolId,
    required String studentId,
    required String? currentRouteId,
    required List<String> currentParentIds,
    required double? currentLatitude,
    required double? currentLongitude,
    double? pendingLatitude,
    double? pendingLongitude,
  }) async {
    final bloc = context.read<StudentsBloc>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ManageStudentDialog(
        schoolId: schoolId,
        studentId: studentId,
        initialRouteId: currentRouteId,
        initialParentIds: currentParentIds,
        initialLatitude: currentLatitude,
        initialLongitude: currentLongitude,
        pendingLatitude: pendingLatitude,
        pendingLongitude: pendingLongitude,
        onRouteChanged: (routeId) => bloc.add(
          StudentRouteAssigned(
            schoolId: schoolId,
            studentId: studentId,
            routeId: routeId,
          ),
        ),
        onLocationChanged: (latitude, longitude) => bloc.add(
          StudentLocationChanged(
            schoolId: schoolId,
            studentId: studentId,
            latitude: latitude,
            longitude: longitude,
          ),
        ),
        onLocationRequestAccepted: (latitude, longitude) => bloc.add(
          StudentLocationRequestAccepted(
            schoolId: schoolId,
            studentId: studentId,
            latitude: latitude,
            longitude: longitude,
          ),
        ),
        onLocationRequestRejected: () => bloc.add(
          StudentLocationRequestRejected(schoolId: schoolId, studentId: studentId),
        ),
        onParentLinked: (parentUid) => bloc.add(
          StudentParentLinked(
            schoolId: schoolId,
            studentId: studentId,
            parentUid: parentUid,
          ),
        ),
        onParentUnlinked: (parentUid) => bloc.add(
          StudentParentUnlinked(
            schoolId: schoolId,
            studentId: studentId,
            parentUid: parentUid,
          ),
        ),
      ),
    );
  }
}

/// Lets an admin assign the route a student rides and link/unlink the
/// parent account(s) that should be able to see that student's live trip.
class _ManageStudentDialog extends StatefulWidget {
  const _ManageStudentDialog({
    required this.schoolId,
    required this.studentId,
    required this.initialRouteId,
    required this.initialParentIds,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onRouteChanged,
    required this.onLocationChanged,
    required this.onParentLinked,
    required this.onParentUnlinked,
    this.pendingLatitude,
    this.pendingLongitude,
    this.onLocationRequestAccepted,
    this.onLocationRequestRejected,
  });

  final String schoolId;
  final String studentId;
  final String? initialRouteId;
  final List<String> initialParentIds;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<String?> onRouteChanged;
  final void Function(double latitude, double longitude) onLocationChanged;
  final ValueChanged<String> onParentLinked;
  final ValueChanged<String> onParentUnlinked;

  // Feature: Parent can add child location.
  final double? pendingLatitude;
  final double? pendingLongitude;
  final void Function(double latitude, double longitude)?
  onLocationRequestAccepted;
  final VoidCallback? onLocationRequestRejected;

  @override
  State<_ManageStudentDialog> createState() => _ManageStudentDialogState();
}

class _ManageStudentDialogState extends State<_ManageStudentDialog> {
  late String? _routeId = widget.initialRouteId?.isEmpty ?? true
      ? null
      : widget.initialRouteId;
  late final List<String> _parentIds = List.of(widget.initialParentIds);
  late double? _latitude = widget.initialLatitude;
  late double? _longitude = widget.initialLongitude;
  late bool _hasPendingLocation =
      widget.pendingLatitude != null && widget.pendingLongitude != null;
  String? _parentToAdd;

  // The confirm dialog itself is now PendingApprovalCard's job (see the
  // ApprovalAction list below) — this only performs the actual accept/
  // reject once that's already been confirmed.
  Future<void> _resolveLocationRequest({required bool accept}) async {
    if (accept) {
      widget.onLocationRequestAccepted?.call(
        widget.pendingLatitude!,
        widget.pendingLongitude!,
      );
      setState(() {
        _latitude = widget.pendingLatitude;
        _longitude = widget.pendingLongitude;
        _hasPendingLocation = false;
      });
    } else {
      widget.onLocationRequestRejected?.call();
      setState(() => _hasPendingLocation = false);
    }
  }

  /// The small uppercase "section eyebrow" used above each field group in
  /// this dialog — MASTER.md §3's `labelSmall`/Label style, used here for
  /// "section eyebrows" exactly as documented.
  Widget _sectionLabel(BuildContext context, String text) {
    final colors = context.appColors;
    return Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(const S('Manage student', 'إدارة الطالب').of(context)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(context, const S('Route', 'الخط').of(context)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: RoutesRepository().watchRoutes(widget.schoolId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  // Wait for the real route list before ever building the
                  // dropdown: DropdownButtonFormField only reads
                  // `initialValue` on its very first build (a later
                  // rebuild with a *different* initialValue does NOT
                  // retroactively update the shown selection — this is a
                  // known Flutter quirk, not a bug in the widget below).
                  // Building it once, before the stream has emitted, with
                  // `_routeId` set to an id the (still-empty) items list
                  // doesn't contain yet is exactly what threw "There
                  // should be exactly one item with [DropdownButton]'s
                  // value" — and building it a second time with the real
                  // data wouldn't have fixed the already-locked-in
                  // selection anyway.
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final routes = snapshot.data!.docs;
                  final routeIds = routes.map((doc) => doc.id).toSet();
                  return DropdownButtonFormField<String?>(
                    // A student's routeId can point at a route that no
                    // longer exists (deleted after assignment) — falling
                    // back to null here is what the same assertion would
                    // otherwise catch permanently, not just on first load.
                    initialValue: routeIds.contains(_routeId) ? _routeId : null,
                    decoration: InputDecoration(
                      labelText: const S(
                        'Assigned route',
                        'الخط المخصص',
                      ).of(context),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(const S('No route', 'من غير خط').of(context)),
                      ),
                      ...routes.map(
                        (doc) => DropdownMenuItem<String?>(
                          value: doc.id,
                          child: Text(
                            doc.data()['name']?.toString() ?? doc.id,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _routeId = value);
                      widget.onRouteChanged(value);
                    },
                  );
                },
              ),
              if (_hasPendingLocation) ...[
                const SizedBox(height: AppSpacing.xl),
                _sectionLabel(
                  context,
                  const S(
                    'Pending location request',
                    'طلب موقع قيد المراجعة',
                  ).of(context),
                ),
                const SizedBox(height: 8),
                // Feature: unified accept/reject UI — the same
                // PendingApprovalCard used for student/driver/parent
                // approval.
                Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Builder(
                    builder: (context) => PendingApprovalCard(
                      icon: Icons.location_on_outlined,
                      title: _latitude == null
                          ? 'No current pickup point'
                          : 'Current: ${_latitude!.toStringAsFixed(5)}, '
                                '${_longitude!.toStringAsFixed(5)}',
                      subtitle: 'Requested: '
                          '${widget.pendingLatitude!.toStringAsFixed(5)}, '
                          '${widget.pendingLongitude!.toStringAsFixed(5)}',
                      tone: StatusTone.info,
                      actions: [
                        ApprovalAction(
                          label: const S('Reject', 'رفض').of(context),
                          icon: Icons.cancel_outlined,
                          destructive: true,
                          confirmTitle: const S(
                            'Reject this suggestion?',
                            'رفض الاقتراح ده؟',
                          ).of(context),
                          confirmMessage: const S(
                            "The parent's suggested location will be "
                                'dismissed — the official pickup point (if '
                                'any) stays unchanged.',
                            'الموقع المقترح من ولي الأمر هيتشال — نقطة '
                                'الاستلام الرسمية (لو موجودة) هتفضل زي ما '
                                'هي.',
                          ).of(context),
                          onConfirmed: (_) => _resolveLocationRequest(accept: false),
                        ),
                        ApprovalAction(
                          label: const S('Accept', 'قبول').of(context),
                          icon: Icons.check_circle_outline,
                          confirmTitle: const S(
                            'Accept this location?',
                            'قبول الموقع ده؟',
                          ).of(context),
                          confirmMessage: const S(
                            "This becomes the student's official pickup "
                                'point.',
                            'ده هيبقى نقطة الاستلام الرسمية للطالب.',
                          ).of(context),
                          onConfirmed: (_) => _resolveLocationRequest(accept: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _sectionLabel(
                context,
                const S('Pickup point', 'نقطة الاستلام').of(context),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _latitude == null
                        ? Icons.location_off_outlined
                        : Icons.location_on,
                    size: 18,
                    color: _latitude == null
                        ? context.appColors.textMuted
                        : context.appColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _latitude == null || _longitude == null
                          ? const S(
                              "Not set — this student won't appear on the "
                                  "driver's pickup order.",
                              'لسه مش متحدد — الطالب ده مش هيظهر في ترتيب '
                                  'استلام السواق.',
                            ).of(context)
                          : 'Lat ${_latitude!.toStringAsFixed(5)}, '
                                'Lng ${_longitude!.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton.secondary(
                    icon: _latitude == null ? Icons.add_location_alt : Icons.edit_location_alt,
                    label: _latitude == null
                        ? const S('Set', 'تحديد').of(context)
                        : const S('Edit', 'تعديل').of(context),
                    onPressed: () async {
                      final picked = await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPickerPage(
                            title: 'Set pickup point',
                            initialPosition: _latitude == null || _longitude == null
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
                      widget.onLocationChanged(picked.latitude, picked.longitude);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _sectionLabel(
                context,
                const S('Linked parents', 'أولياء الأمور المرتبطين').of(context),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: StudentsRepository().watchParentMembers(
                  widget.schoolId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  final parents = snapshot.data?.docs ?? const [];
                  final parentNames = {
                    for (final doc in parents)
                      doc.id: doc.data()['displayName']?.toString() ?? doc.id,
                  };
                  final availableParents = parents
                      .where((doc) => !_parentIds.contains(doc.id))
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_parentIds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: context.appColors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                const S(
                                  'No parents linked yet.',
                                  'مفيش أولياء أمور مرتبطين لسه.',
                                ).of(context),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.appColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _parentIds
                            .map(
                              (uid) => Chip(
                                avatar: const Icon(Icons.person, size: 16),
                                label: Text(parentNames[uid] ?? uid),
                                onDeleted: () {
                                  setState(() => _parentIds.remove(uid));
                                  widget.onParentUnlinked(uid);
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _parentToAdd,
                              decoration: InputDecoration(
                                labelText: const S(
                                  'Add parent',
                                  'إضافة ولي أمر',
                                ).of(context),
                              ),
                              items: availableParents
                                  .map(
                                    (doc) => DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: Text(parentNames[doc.id] ?? doc.id),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _parentToAdd = value),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppButton.primary(
                            icon: Icons.link,
                            label: const S('Link', 'ربط').of(context),
                            onPressed: _parentToAdd == null
                                ? null
                                : () {
                                    final uid = _parentToAdd!;
                                    setState(() {
                                      _parentIds.add(uid);
                                      _parentToAdd = null;
                                    });
                                    widget.onParentLinked(uid);
                                  },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton.secondary(
          label: const S('Done', 'تم').of(context),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _DriversTab extends StatelessWidget {
  const _DriversTab({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          DriversBloc(DriversRepository())..add(DriversStarted(schoolId)),
      child: BlocBuilder<DriversBloc, DriversState>(
        builder: (context, state) {
          final reduceMotion = MediaQuery.of(context).disableAnimations;

          Widget body;
          if (state is DriversLoading || state is DriversInitial) {
            body = const _PeopleListSkeleton(key: ValueKey('loading'));
          } else if (state is DriversFailure) {
            body = Center(
              key: const ValueKey('error'),
              child: ErrorStateView(
                message: state.message,
                onRetry: () =>
                    context.read<DriversBloc>().add(DriversStarted(schoolId)),
              ),
            );
          } else {
            final snapshot = state is DriversLoaded ? state.snapshot : null;
            final docs = snapshot?.docs ?? const [];
            final hasMore = state is DriversLoaded && state.hasMore;

            body = docs.isEmpty
                ? EmptyStateView(
                    key: const ValueKey('empty'),
                    icon: Icons.badge_outlined,
                    title: const S('No drivers found', 'مفيش سائقين').of(
                      context,
                    ),
                    message: const S(
                      'Drivers appear here once they sign up and request '
                          'to join your school.',
                      'السواقين هيظهروا هنا لما يسجلوا ويطلبوا الانضمام '
                          'لمدرستك.',
                    ).of(context),
                  )
                : ListView.builder(
                    key: const ValueKey('content'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: docs.length + (hasMore ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == docs.length) {
                        return Padding(
                          key: const ValueKey('load-more'),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Center(
                            child: AppButton.secondary(
                              label: const S('Load more', 'حمّل المزيد').of(
                                context,
                              ),
                              icon: Icons.expand_more,
                              onPressed: () => context
                                  .read<DriversBloc>()
                                  .add(DriversLoadMoreRequested()),
                            ),
                          ),
                        );
                      }
                      final doc = docs[index];
                      final data = doc.data();
                      final status = data['status']?.toString() ?? 'pending';
                      final name = data['displayName']?.toString() ??
                          data['name']?.toString() ??
                          doc.id;

                      // Feature: unified accept/reject UI — a driver
                      // awaiting review gets the same PendingApprovalCard
                      // shape (with a confirm dialog, and a required reason
                      // on reject) that student approval and location
                      // requests use, instead of a bare menu tap with no
                      // confirmation at all.
                      if (status == 'pending') {
                        final bloc = context.read<DriversBloc>();
                        return Padding(
                          key: ValueKey(doc.id),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: PendingApprovalCard(
                            icon: Icons.badge_outlined,
                            title: name,
                            subtitle: const S(
                              'Awaiting approval to join as a driver',
                              'في انتظار الموافقة على الانضمام كسائق',
                            ).of(context),
                            actions: [
                              ApprovalAction(
                                label: const S('Approve', 'موافقة').of(context),
                                icon: Icons.check_circle_outline,
                                onConfirmed: (_) async =>
                                    bloc.add(DriverApproved(schoolId, doc.id)),
                              ),
                              ApprovalAction(
                                label: const S('Reject', 'رفض').of(context),
                                icon: Icons.cancel_outlined,
                                destructive: true,
                                requiresReason: true,
                                confirmTitle: const S(
                                  'Reject this driver?',
                                  'رفض السائق ده؟',
                                ).of(context),
                                confirmMessage: const S(
                                  'They will not be able to sign in as a '
                                      'driver at your school.',
                                  'مش هيقدر يسجل دخول كسائق في مدرستك.',
                                ).of(context),
                                onConfirmed: (reason) async => bloc.add(
                                  DriverRejected(schoolId, doc.id, reason: reason),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Card(
                        key: ValueKey(doc.id),
                        child: ListTile(
                          // Feature: card -> details -> management.
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverDetailPage(
                                schoolId: schoolId,
                                uid: doc.id,
                                displayName: name,
                              ),
                            ),
                          ),
                          leading: const CircleAvatar(child: Icon(Icons.badge)),
                          title: Text(name),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: StatusBadge(
                              tone: _memberStatusTone(status),
                              label: _memberStatusLabel(context, status),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: const S(
                              'More actions',
                              'إجراءات إضافية',
                            ).of(context),
                            onSelected: (value) => _handleMemberAction(
                              context,
                              value: value,
                              name: name,
                              onSuspend: (reason) => context
                                  .read<DriversBloc>()
                                  .add(DriverSuspended(schoolId, doc.id, reason: reason)),
                              onReject: (reason) => context
                                  .read<DriversBloc>()
                                  .add(DriverRejected(schoolId, doc.id, reason: reason)),
                            ),
                            itemBuilder: (menuContext) => [
                              PopupMenuItem(
                                value: 'suspend',
                                child: _MemberActionMenuRow(
                                  icon: Icons.pause_circle_outline,
                                  color: menuContext.appColors.warning,
                                  label: const S('Suspend', 'إيقاف').of(
                                    menuContext,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'reject',
                                child: _MemberActionMenuRow(
                                  icon: Icons.cancel_outlined,
                                  color: menuContext.appColors.error,
                                  label: const S('Reject', 'رفض').of(
                                    menuContext,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
          }

          return AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : AppDurations.stateSwitch,
            child: body,
          );
        },
      ),
    );
  }
}

class _ParentsTab extends StatelessWidget {
  const _ParentsTab({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ParentsBloc(ParentsRepository())..add(ParentsStarted(schoolId)),
      child: BlocBuilder<ParentsBloc, ParentsState>(
        builder: (context, state) {
          final reduceMotion = MediaQuery.of(context).disableAnimations;

          Widget body;
          if (state is ParentsLoading || state is ParentsInitial) {
            body = const _PeopleListSkeleton(key: ValueKey('loading'));
          } else if (state is ParentsFailure) {
            body = Center(
              key: const ValueKey('error'),
              child: ErrorStateView(
                message: state.message,
                onRetry: () =>
                    context.read<ParentsBloc>().add(ParentsStarted(schoolId)),
              ),
            );
          } else {
            final snapshot = state is ParentsLoaded ? state.snapshot : null;
            final docs = snapshot?.docs ?? const [];
            final hasMore = state is ParentsLoaded && state.hasMore;

            body = docs.isEmpty
                ? EmptyStateView(
                    key: const ValueKey('empty'),
                    icon: Icons.family_restroom_outlined,
                    title: const S('No parents found', 'مفيش أولياء أمور').of(
                      context,
                    ),
                    message: const S(
                      'Parents appear here once they sign up and request '
                          'to join your school.',
                      'أولياء الأمور هيظهروا هنا لما يسجلوا ويطلبوا '
                          'الانضمام لمدرستك.',
                    ).of(context),
                  )
                : ListView.builder(
                    key: const ValueKey('content'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: docs.length + (hasMore ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == docs.length) {
                        return Padding(
                          key: const ValueKey('load-more'),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Center(
                            child: AppButton.secondary(
                              label: const S('Load more', 'حمّل المزيد').of(
                                context,
                              ),
                              icon: Icons.expand_more,
                              onPressed: () => context
                                  .read<ParentsBloc>()
                                  .add(ParentsLoadMoreRequested()),
                            ),
                          ),
                        );
                      }
                      final doc = docs[index];
                      final data = doc.data();
                      final status = data['status']?.toString() ?? 'pending';
                      final name = data['displayName']?.toString() ??
                          data['name']?.toString() ??
                          doc.id;

                      // Feature: unified accept/reject UI — see the same
                      // treatment in _DriversTab above.
                      if (status == 'pending') {
                        final bloc = context.read<ParentsBloc>();
                        return Padding(
                          key: ValueKey(doc.id),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: PendingApprovalCard(
                            icon: Icons.person_outline,
                            title: name,
                            subtitle: const S(
                              'Awaiting approval to join as a parent',
                              'في انتظار الموافقة على الانضمام كولي أمر',
                            ).of(context),
                            actions: [
                              ApprovalAction(
                                label: const S('Approve', 'موافقة').of(context),
                                icon: Icons.check_circle_outline,
                                onConfirmed: (_) async =>
                                    bloc.add(ParentApproved(schoolId, doc.id)),
                              ),
                              ApprovalAction(
                                label: const S('Reject', 'رفض').of(context),
                                icon: Icons.cancel_outlined,
                                destructive: true,
                                requiresReason: true,
                                confirmTitle: const S(
                                  'Reject this parent?',
                                  'رفض ولي الأمر ده؟',
                                ).of(context),
                                confirmMessage: const S(
                                  'They will not be able to sign in at your '
                                      'school.',
                                  'مش هيقدر يسجل دخول في مدرستك.',
                                ).of(context),
                                onConfirmed: (reason) async => bloc.add(
                                  ParentRejected(schoolId, doc.id, reason: reason),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Card(
                        key: ValueKey(doc.id),
                        child: ListTile(
                          // Feature: card -> details -> management.
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ParentDetailPage(
                                schoolId: schoolId,
                                uid: doc.id,
                              ),
                            ),
                          ),
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(name),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: StatusBadge(
                              tone: _memberStatusTone(status),
                              label: _memberStatusLabel(context, status),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: const S(
                              'More actions',
                              'إجراءات إضافية',
                            ).of(context),
                            onSelected: (value) => _handleMemberAction(
                              context,
                              value: value,
                              name: name,
                              onSuspend: (reason) => context
                                  .read<ParentsBloc>()
                                  .add(ParentSuspended(schoolId, doc.id, reason: reason)),
                              onReject: (reason) => context
                                  .read<ParentsBloc>()
                                  .add(ParentRejected(schoolId, doc.id, reason: reason)),
                            ),
                            itemBuilder: (menuContext) => [
                              PopupMenuItem(
                                value: 'suspend',
                                child: _MemberActionMenuRow(
                                  icon: Icons.pause_circle_outline,
                                  color: menuContext.appColors.warning,
                                  label: const S('Suspend', 'إيقاف').of(
                                    menuContext,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'reject',
                                child: _MemberActionMenuRow(
                                  icon: Icons.cancel_outlined,
                                  color: menuContext.appColors.error,
                                  label: const S('Reject', 'رفض').of(
                                    menuContext,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
          }

          return AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : AppDurations.stateSwitch,
            child: body,
          );
        },
      ),
    );
  }
}

/// One row inside the approve/suspend/reject [PopupMenuButton] used by both
/// the Drivers and Parents tabs — an icon plus a label tinted to match the
/// action's outcome (success/warning/error), so the menu itself communicates
/// meaning instead of three visually-identical text rows.
class _MemberActionMenuRow extends StatelessWidget {
  const _MemberActionMenuRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _RoutesTab extends StatelessWidget {
  const _RoutesTab({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    // Feature: school location must be set first. Routes are operational
    // geography — a route's implied final stop is the school's own
    // location — so creating one before that exists is blocked here (and,
    // load-bearingly, by firestore.rules' routes `create` rule too; this is
    // the explanatory UI on top of that real enforcement, not a substitute
    // for it).
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: SchoolsRepository().watchSchool(schoolId),
      builder: (context, schoolSnapshot) {
        final data = schoolSnapshot.data?.data();
        final hasLocation = data != null &&
            School.fromMap(schoolSnapshot.data!.id, data).hasLocation;
        if (schoolSnapshot.hasData && !hasLocation) {
          return _SchoolLocationRequiredGate(schoolId: schoolId);
        }
        return _RoutesTabContent(schoolId: schoolId);
      },
    );
  }
}

/// Shown in place of the routes list until the school's own location is
/// configured — see `_RoutesTab.build`'s comment.
class _SchoolLocationRequiredGate extends StatelessWidget {
  const _SchoolLocationRequiredGate({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.location_off_outlined,
      title: const S(
        'Set your school location first',
        'حدد موقع مدرستك الأول',
      ).of(context),
      message: const S(
        "Every trip ends at your school's own location, so routes and "
            "pickup points can't be created until it's set.",
        'كل رحلة بتنتهي عند موقع مدرستك، فمينفعش تضيف خطوط سير أو نقاط '
            'استلام قبل ما تحدده.',
      ).of(context),
      actionLabel: const S('Set school location', 'تحديد موقع المدرسة')
          .of(context),
      onAction: () async {
        final picked = await Navigator.push<LatLng>(
          context,
          MaterialPageRoute(
            builder: (_) => LocationPickerPage(
              title: const S('Set school location', 'تحديد موقع المدرسة')
                  .of(context),
            ),
          ),
        );
        if (picked == null || !context.mounted) return;
        try {
          await SchoolsRepository().updateLocation(
            schoolId: schoolId,
            latitude: picked.latitude,
            longitude: picked.longitude,
          );
        } on SchoolLocationException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      },
    );
  }
}

class _RoutesTabContent extends StatelessWidget {
  const _RoutesTabContent({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          RoutesBloc(RoutesRepository())..add(RoutesStarted(schoolId)),
      child: BlocBuilder<RoutesBloc, RoutesState>(
        builder: (context, state) {
          if (state is RoutesLoading || state is RoutesInitial) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 4,
              itemBuilder: (_, _) => const AppSkeletonListTile(),
            );
          }
          if (state is RoutesFailure) {
            return ErrorStateView(message: state.message);
          }

          final snapshot = state is RoutesLoaded ? state.snapshot : null;
          final docs = snapshot?.docs ?? const [];

          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'routes-add-fab',
              onPressed: () => _createRoute(context),
              icon: const Icon(Icons.add),
              label: Text(const S('Route', 'خط سير').of(context)),
            ),
            body: docs.isEmpty
                ? EmptyStateView(
                    icon: Icons.route_outlined,
                    title: const S(
                      'No routes yet.',
                      'مفيش خطوط سير لسه.',
                    ).of(context),
                    message: const S(
                      'Add your first route so it can be picked when you '
                          'schedule a trip.',
                      'ضيف أول خط سير عشان تقدر تختاره لما تجدول رحلة.',
                    ).of(context),
                    actionLabel: const S(
                      'Add route',
                      'إضافة خط سير',
                    ).of(context),
                    onAction: () => _createRoute(context),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final route = SchoolRoute.fromMap(doc.id, data);
                      final description = data['description']?.toString();
                      final colors = context.appColors;

                      return Container(
                        key: ValueKey(doc.id),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colors.info.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(
                                Icons.route,
                                color: colors.info,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route.name,
                                    style: Theme.of(context).textTheme.titleSmall
                                        ?.copyWith(color: colors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description == null || description.isEmpty
                                        ? const S(
                                            'No description',
                                            'من غير وصف',
                                          ).of(context)
                                        : description,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: colors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 6),
                                  // The corridor width the deviation engine
                                  // measures this route's buses against.
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.social_distance_outlined,
                                        size: 14,
                                        color: colors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          S(
                                            'Deviation tolerance '
                                                '${route.deviationToleranceMeters.round()} m',
                                            'حد الخروج عن المسار '
                                                '${route.deviationToleranceMeters.round()} متر',
                                          ).of(context),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.textMuted,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusBadge(
                                  label: route.isActive
                                      ? const S('Active', 'نشطة').of(context)
                                      : const S(
                                          'Inactive',
                                          'غير نشطة',
                                        ).of(context),
                                  tone: route.isActive
                                      ? StatusTone.success
                                      : StatusTone.neutral,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: const S(
                                        'Edit route',
                                        'تعديل الخط',
                                      ).of(context),
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _editRoute(
                                        context,
                                        route: route,
                                        description: description,
                                      ),
                                    ),
                                    Switch(
                                      value: route.isActive,
                                      onChanged: (value) => context
                                          .read<RoutesBloc>()
                                          .add(
                                            RouteStatusChanged(
                                              schoolId: schoolId,
                                              routeId: route.id,
                                              active: value,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  Future<void> _createRoute(BuildContext context) async {
    final bloc = context.read<RoutesBloc>();
    final draft = await showDialog<_RouteDraft>(
      context: context,
      builder: (dialogContext) => const _RouteDialog(),
    );
    if (draft == null) return;

    bloc.add(
      RouteCreated(
        schoolId: schoolId,
        name: draft.name,
        description: draft.description,
        deviationToleranceMeters: draft.deviationToleranceMeters,
      ),
    );
  }

  Future<void> _editRoute(
    BuildContext context, {
    required SchoolRoute route,
    required String? description,
  }) async {
    final bloc = context.read<RoutesBloc>();
    final draft = await showDialog<_RouteDraft>(
      context: context,
      builder: (dialogContext) =>
          _RouteDialog(route: route, description: description),
    );
    if (draft == null) return;

    bloc.add(
      RouteUpdated(
        schoolId: schoolId,
        routeId: route.id,
        name: draft.name,
        description: draft.description,
        deviationToleranceMeters: draft.deviationToleranceMeters,
        isActive: route.isActive,
        outboundScheduledMinutes: draft.outboundScheduledMinutes,
        returnScheduledMinutes: draft.returnScheduledMinutes,
      ),
    );
  }
}

class _RouteDraft {
  const _RouteDraft({
    required this.name,
    required this.deviationToleranceMeters,
    this.description,
    this.outboundScheduledMinutes,
    this.returnScheduledMinutes,
  });

  final String name;
  final String? description;
  final double deviationToleranceMeters;
  final int? outboundScheduledMinutes;
  final int? returnScheduledMinutes;
}

/// Add/edit a route, including its deviation tolerance — how far (in
/// metres) a bus on this route may stray from its expected stop-to-stop
/// path before the server-side deviation engine flags it. Exposed per
/// route because a rural route and a dense-urban one genuinely need
/// different corridor widths.
class _RouteDialog extends StatefulWidget {
  const _RouteDialog({this.route, this.description});

  final SchoolRoute? route;
  final String? description;

  @override
  State<_RouteDialog> createState() => _RouteDialogState();
}

class _RouteDialogState extends State<_RouteDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.route?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.description ?? '',
  );
  late double _tolerance =
      widget.route?.deviationToleranceMeters ??
      defaultDeviationToleranceMeters;

  // Feature: two daily trips. Held as a local wall-clock TimeOfDay for
  // editing; converted to/from the stored UTC-minutes value (see
  // localTimeToUtcMinutes/utcMinutesToLocalTime) only at the model
  // boundary. Null means that direction isn't run on this route.
  late TimeOfDay? _outbound = _fromStored(widget.route?.outboundScheduledMinutes);
  late TimeOfDay? _return = _fromStored(widget.route?.returnScheduledMinutes);

  static TimeOfDay? _fromStored(int? utcMinutes) {
    if (utcMinutes == null) return null;
    final (hour, minute) = utcMinutesToLocalTime(utcMinutes);
    return TimeOfDay(hour: hour, minute: minute);
  }

  int? _toStored(TimeOfDay? time) =>
      time == null ? null : localTimeToUtcMinutes(time.hour, time.minute);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      title: Text(
        widget.route == null
            ? const S('Add route', 'إضافة خط سير').of(context)
            : const S('Edit route', 'تعديل الخط').of(context),
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
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: const S('Description', 'الوصف').of(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                const S(
                  'Deviation tolerance',
                  'حد الخروج عن المسار',
                ).of(context).toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                const S(
                  'How far a bus on this route may be from its expected '
                      'stop-to-stop path before it is flagged as off route.',
                  'قد إيه الأتوبيس على الخط ده ينفع يبعد عن مساره المتوقع '
                      'قبل ما يتحسب خارج المسار.',
                ).of(context),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _tolerance.clamp(
                        minDeviationToleranceMeters,
                        maxDeviationToleranceMeters,
                      ),
                      min: minDeviationToleranceMeters,
                      max: maxDeviationToleranceMeters,
                      divisions: 39,
                      label: '${_tolerance.round()} m',
                      onChanged: (value) => setState(() => _tolerance = value),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        '${_tolerance.round()} m',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                const S(
                  'Daily schedule',
                  'الجدول اليومي',
                ).of(context).toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                const S(
                  'The fixed time this route runs each direction — used for '
                      'generating today\'s outbound/return trips and for the '
                      'absence cutoff. Leave a direction blank if this route '
                      "doesn't run it.",
                  'الميعاد الثابت للخط في كل اتجاه — بيتحسب عليه رحلات '
                      'الذهاب/العودة اليومية وموعد قفل الغياب. سيب الاتجاه '
                      'فاضي لو الخط ده مش بيعمله.',
                ).of(context),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DirectionTimeRow(
                label: const S('Outbound (to school)', 'الذهاب للمدرسة')
                    .of(context),
                time: _outbound,
                onChanged: (time) => setState(() => _outbound = time),
              ),
              const SizedBox(height: AppSpacing.xs),
              _DirectionTimeRow(
                label: const S('Return (home)', 'العودة للمنزل').of(context),
                time: _return,
                onChanged: (time) => setState(() => _return = time),
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
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _RouteDraft(
                    name: _name.text,
                    description: _description.text.trim().isEmpty
                        ? null
                        : _description.text,
                    deviationToleranceMeters: _tolerance,
                    outboundScheduledMinutes: _toStored(_outbound),
                    returnScheduledMinutes: _toStored(_return),
                  ),
                ),
        ),
      ],
    );
  }
}

/// One direction's fixed time-of-day, plus a clear affordance to unset it
/// (this route doesn't run that direction).
class _DirectionTimeRow extends StatelessWidget {
  const _DirectionTimeRow({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 7, minute: 0),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text(label),
          subtitle: time == null
              ? Text(
                  const S("Not run", 'مش بيعمله').of(context),
                  style: TextStyle(color: colors.textMuted),
                )
              : Text(time!.format(context)),
          trailing: time == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: const S('Clear', 'مسح').of(context),
                  onPressed: () => onChanged(null),
                ),
        ),
      ),
    );
  }
}

/// The one dot+label pattern (`StatusBadge`) is reused for every trip
/// status, so the tone here is the single source of truth for what each
/// status means at a glance — the same tone mapping the driver app uses for
/// its own trip cards. `info` covers both "starting" and "active" (en
/// route) per design-system/MASTER.md §2; `error` is deliberately never
/// used here — it's reserved for genuine failures, not normal trip states,
/// even terminal ones like `cancelled`.
StatusTone _tripStatusTone(TripStatus status) => switch (status) {
  TripStatus.scheduled => StatusTone.neutral,
  TripStatus.starting => StatusTone.info,
  TripStatus.active => StatusTone.info,
  TripStatus.paused => StatusTone.warning,
  TripStatus.completed => StatusTone.success,
  TripStatus.cancelled => StatusTone.neutral,
  TripStatus.emergency => StatusTone.emergency,
};

String _tripStatusLabel(TripStatus status, BuildContext context) =>
    switch (status) {
      TripStatus.scheduled => const S('Scheduled', 'مجدولة').of(context),
      TripStatus.starting => const S('Starting', 'جاري البدء').of(context),
      TripStatus.active => const S('En route', 'في الطريق').of(context),
      TripStatus.paused => const S('Paused', 'متوقفة مؤقتاً').of(context),
      TripStatus.completed => const S('Completed', 'مكتملة').of(context),
      TripStatus.cancelled => const S('Cancelled', 'ملغاة').of(context),
      TripStatus.emergency => const S('Emergency', 'حالة طوارئ').of(context),
    };

/// Maps a [StatusTone] onto its token color — used to tint a trip's leading
/// icon the same color as its [StatusBadge], so the two visually agree.
Color _toneColor(AppColorTokens colors, StatusTone tone) {
  switch (tone) {
    case StatusTone.success:
      return colors.success;
    case StatusTone.warning:
      return colors.warning;
    case StatusTone.error:
      return colors.error;
    case StatusTone.info:
      return colors.info;
    case StatusTone.emergency:
      return colors.emergency;
    case StatusTone.neutral:
      return colors.textMuted;
  }
}

class _TripsTab extends StatelessWidget {
  const _TripsTab({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TripsBloc(TripsRepository())..add(TripsStarted(schoolId)),
      child: BlocConsumer<TripsBloc, TripsState>(
        // A reassignment reports its own outcome without disturbing the
        // list the admin is working in.
        listenWhen: (_, current) =>
            current is TripsActionFailure || current is TripsActionSucceeded,
        listener: (context, state) {
          if (state is TripsActionFailure) {
            AppSnackbar.error(context, state.message);
          } else if (state is TripsActionSucceeded) {
            AppSnackbar.success(
              context,
              const S(
                'Trip reassigned. Affected parents and the new driver have '
                    'been notified.',
                'تم تغيير تخصيص الرحلة. أولياء الأمور المعنيين والسائق '
                    'الجديد اتبلغوا.',
              ).of(context),
            );
          }
        },
        builder: (context, state) {
          if (state is TripsLoading || state is TripsInitial) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 4,
              itemBuilder: (_, _) => const AppSkeletonListTile(),
            );
          }
          if (state is TripsFailure) {
            return ErrorStateView(message: state.message);
          }

          final snapshot = switch (state) {
            TripsLoaded(:final snapshot) => snapshot,
            TripsActionFailure(:final snapshot) => snapshot,
            TripsActionSucceeded(:final snapshot) => snapshot,
            _ => null,
          };
          final docs = snapshot?.docs ?? const [];
          final hasMore = switch (state) {
            TripsLoaded(:final hasMore) => hasMore,
            TripsActionFailure(:final hasMore) => hasMore,
            TripsActionSucceeded(:final hasMore) => hasMore,
            _ => false,
          };

          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'trips-add-fab',
              onPressed: () => _createTrip(context),
              icon: const Icon(Icons.add),
              label: Text(const S('Trip', 'رحلة').of(context)),
            ),
            body: docs.isEmpty
                ? EmptyStateView(
                    icon: Icons.event_busy_outlined,
                    title: const S(
                      'No trips scheduled yet.',
                      'مفيش رحلات متجدولة لسه.',
                    ).of(context),
                    message: const S(
                      'Schedule your first trip by picking a route, a bus '
                          'and a driver.',
                      'جدول أول رحلة باختيار خط وأتوبيس وسائق.',
                    ).of(context),
                    actionLabel: const S('Add trip', 'إضافة رحلة').of(context),
                    onAction: () => _createTrip(context),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: docs.length + (hasMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, index) {
                      if (index == docs.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Center(
                            child: AppButton.secondary(
                              label: const S(
                                'Load more',
                                'حمّل المزيد',
                              ).of(context),
                              icon: Icons.expand_more,
                              onPressed: () => context
                                  .read<TripsBloc>()
                                  .add(TripsLoadMoreRequested()),
                            ),
                          ),
                        );
                      }
                      final doc = docs[index];
                      final trip = SchoolTrip.fromMap(doc.id, doc.data());
                      final canCancel = trip.status == TripStatus.scheduled ||
                          trip.status == TripStatus.starting ||
                          trip.status == TripStatus.paused;
                      final canReassign =
                          trip.status != TripStatus.completed &&
                          trip.status != TripStatus.cancelled;
                      final colors = context.appColors;
                      final tone = _tripStatusTone(trip.status);
                      final toneColor = _toneColor(colors, tone);

                      return Container(
                        key: ValueKey(trip.id),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: toneColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(
                                _tripStatusIcon(trip.status),
                                color: toneColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          trip.routeName.isEmpty
                                              ? S(
                                                  'Route ${trip.routeId}',
                                                  'الخط ${trip.routeId}',
                                                ).of(context)
                                              : trip.routeName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: colors.textPrimary,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      StatusBadge(
                                        label: _tripStatusLabel(
                                          trip.status,
                                          context,
                                        ),
                                        tone: tone,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.directions_bus_outlined,
                                        size: 14,
                                        color: colors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${trip.busName} '
                                          '(${trip.busPlateNumber}) · '
                                          '${trip.driverName}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.textMuted,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_outlined,
                                        size: 14,
                                        color: colors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          DateFormat.yMMMd()
                                              .add_jm()
                                              .format(trip.scheduledAt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.textMuted,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // A finished trip is history: reassigning it
                            // would fire a parent notification about a trip
                            // that is no longer happening, so the control
                            // isn't offered (and the repository refuses it
                            // too).
                            if (canReassign) ...[
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                tooltip: const S(
                                  'Reassign bus or driver',
                                  'تغيير الأتوبيس أو السائق',
                                ).of(context),
                                icon: Icon(
                                  Icons.swap_horiz,
                                  color: colors.info,
                                ),
                                onPressed: () =>
                                    _reassign(context, trip: trip),
                              ),
                            ],
                            IconButton(
                              tooltip: const S(
                                'Change history',
                                'سجل التغييرات',
                              ).of(context),
                              icon: Icon(
                                Icons.history,
                                color: colors.textMuted,
                              ),
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                builder: (_) => TripReassignmentHistorySheet(
                                  schoolId: schoolId,
                                  trip: trip,
                                ),
                              ),
                            ),
                            if (canCancel) ...[
                              IconButton(
                                tooltip: const S(
                                  'Cancel trip',
                                  'إلغاء الرحلة',
                                ).of(context),
                                icon: Icon(
                                  Icons.cancel_outlined,
                                  color: colors.error,
                                ),
                                onPressed: () => _confirmCancel(
                                  context,
                                  schoolId: schoolId,
                                  tripId: trip.id,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  IconData _tripStatusIcon(TripStatus status) => switch (status) {
    TripStatus.scheduled => Icons.schedule,
    TripStatus.starting => Icons.directions_bus,
    TripStatus.active => Icons.directions_bus,
    TripStatus.paused => Icons.pause_circle_outline,
    TripStatus.completed => Icons.check_circle_outline,
    TripStatus.cancelled => Icons.cancel_outlined,
    TripStatus.emergency => Icons.warning_amber_rounded,
  };

  Future<void> _confirmCancel(
    BuildContext context, {
    required String schoolId,
    required String tripId,
  }) async {
    final bloc = context.read<TripsBloc>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S('Cancel this trip?', 'تلغي الرحلة دي؟').of(context),
      message: const S(
        'The driver and any linked parents will see this trip as '
            'cancelled. This cannot be undone.',
        'السائق وأولياء الأمور المرتبطين هيشوفوا الرحلة دي ملغاة. '
            'الإجراء ده مينفعش يتراجع فيه.',
      ).of(context),
      confirmLabel: const S('Cancel trip', 'إلغاء الرحلة').of(context),
      destructive: true,
    );
    if (confirmed != true) return;

    bloc.add(TripCancelled(schoolId: schoolId, tripId: tripId));
  }

  /// Feature: Dynamic Route/Last-Minute Changes. The repository writes the
  /// trip's `busId`/`driverId` (which is what makes the deployed
  /// `onTripAssignmentChanged` function notify affected parents and the new
  /// driver), a ReassignmentRecord, and an audit entry together.
  Future<void> _reassign(
    BuildContext context, {
    required SchoolTrip trip,
  }) async {
    final bloc = context.read<TripsBloc>();
    final draft = await showDialog<TripReassignmentDraft>(
      context: context,
      builder: (dialogContext) =>
          TripReassignmentDialog(schoolId: schoolId, trip: trip),
    );
    if (draft == null || draft.isEmpty) return;

    bloc.add(
      TripReassigned(
        schoolId: schoolId,
        tripId: trip.id,
        busId: draft.busId,
        busName: draft.busName,
        busPlateNumber: draft.busPlateNumber,
        driverId: draft.driverId,
        driverName: draft.driverName,
        reason: draft.reason,
      ),
    );
  }

  Future<void> _createTrip(BuildContext context) async {
    final bloc = context.read<TripsBloc>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreateTripDialog(
        schoolId: schoolId,
        onCreate: (event) => bloc.add(event),
      ),
    );
  }
}

/// Picks a route, an active bus, an approved driver and a schedule time,
/// then dispatches a [TripCreated] event. Route/bus/driver names are copied
/// onto the trip document at creation time (see TripsRepository.createTrip)
/// so the driver and parent apps can show a trip card without needing their
/// own read access to the buses/routes/members collections.
class _CreateTripDialog extends StatefulWidget {
  const _CreateTripDialog({required this.schoolId, required this.onCreate});

  final String schoolId;
  final ValueChanged<TripCreated> onCreate;

  @override
  State<_CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<_CreateTripDialog> {
  // Selection is tracked by document id rather than by holding onto a
  // QueryDocumentSnapshot from the StreamBuilder below: Firestore commonly
  // hands out a brand-new snapshot object (even for an unchanged document)
  // on the next stream event, and DropdownButtonFormField requires its
  // current value to be `==` to exactly one item — snapshot objects aren't
  // equal by identity across rebuilds, so holding one would eventually trip
  // that assertion. Ids are stable and compare correctly instead. The
  // human-readable fields are captured alongside the id at selection time
  // and denormalized onto the trip document by TripsRepository.createTrip.
  String? _routeId;
  String _routeName = '';
  String? _busId;
  String _busName = '';
  String _busPlateNumber = '';
  String? _driverId;
  String _driverName = '';
  DateTime _scheduledAt = DateTime.now().add(const Duration(minutes: 30));

  // Feature: recurring trips — an admin running the same route every school
  // day doesn't want to open this dialog and re-enter the same route/bus/
  // driver every morning. Repeating creates one real SchoolTrip document
  // per day (same time-of-day as _scheduledAt) up to and including
  // _repeatUntil, by dispatching the exact same TripCreated event this
  // dialog already uses once per day — no new creation path, so every
  // generated trip goes through the identical validation TripsBloc/
  // TripsRepository already apply to a single trip.
  bool _repeatDaily = false;
  DateTime? _repeatUntil;

  // Feature: two daily trips. Defaults to outbound — the common case for a
  // single freshly-created trip.
  TripDirection _direction = TripDirection.outbound;

  // Feature: school calendar. Fetched once (not streamed — a holiday
  // calendar doesn't change mid-dialog) purely so _scheduledDates() can
  // skip configured weekly/special holidays when repeating.
  School? _school;

  @override
  void initState() {
    super.initState();
    SchoolsRepository().watchSchool(widget.schoolId).first.then((snapshot) {
      final data = snapshot.data();
      if (mounted && data != null) {
        setState(() => _school = School.fromMap(snapshot.id, data));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(const S('Add trip', 'إضافة رحلة').of(context)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: RoutesRepository().watchRoutes(widget.schoolId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  final routes = (snapshot.data?.docs ?? const [])
                      .where((doc) => doc.data()['isActive'] == true)
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _routeId,
                    decoration: InputDecoration(
                      labelText: const S('Route', 'الخط').of(context),
                    ),
                    items: routes
                        .map(
                          (doc) => DropdownMenuItem(
                            value: doc.id,
                            child: Text(doc.data()['name']?.toString() ?? doc.id),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      final doc = routes.firstWhere((doc) => doc.id == id);
                      setState(() {
                        _routeId = id;
                        _routeName = doc.data()['name']?.toString() ?? '';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: BusesRepository().watchBuses(widget.schoolId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  final buses = (snapshot.data?.docs ?? const [])
                      .where((doc) => doc.data()['isActive'] == true)
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _busId,
                    decoration: InputDecoration(
                      labelText: const S('Bus', 'الأتوبيس').of(context),
                    ),
                    items: buses
                        .map(
                          (doc) => DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              '${doc.data()['name'] ?? doc.id} '
                              '(${doc.data()['plateNumber'] ?? ''})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      final doc = buses.firstWhere((doc) => doc.id == id);
                      setState(() {
                        _busId = id;
                        _busName = doc.data()['name']?.toString() ?? '';
                        _busPlateNumber =
                            doc.data()['plateNumber']?.toString() ?? '';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: DriversRepository().watchDrivers(widget.schoolId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  final drivers = (snapshot.data?.docs ?? const [])
                      .where((doc) => doc.data()['status'] == 'approved')
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _driverId,
                    decoration: InputDecoration(
                      labelText: const S('Driver', 'السائق').of(context),
                    ),
                    items: drivers
                        .map(
                          (doc) => DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              doc.data()['displayName']?.toString() ?? doc.id,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      final doc = drivers.firstWhere((doc) => doc.id == id);
                      setState(() {
                        _driverId = id;
                        _driverName = doc.data()['displayName']?.toString() ?? '';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              // Feature: two daily trips — which leg of the school day this
              // trip (or repeated series) covers. Stops are ordered by the
              // driver app at runtime from this same flag (home->school for
              // outbound, school->home for return), not by a separate route.
              SegmentedButton<TripDirection>(
                segments: [
                  ButtonSegment(
                    value: TripDirection.outbound,
                    label: Text(const S('Outbound', 'ذهاب').of(context)),
                    icon: const Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: TripDirection.returnTrip,
                    label: Text(const S('Return', 'عودة').of(context)),
                    icon: const Icon(Icons.south_west),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (selection) =>
                    setState(() => _direction = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _pickScheduledAt,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.appColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      const S(
                        'Scheduled time',
                        'موعد الرحلة',
                      ).of(context),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat.yMMMd().add_jm().format(_scheduledAt),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _repeatDaily,
                onChanged: (value) => setState(() {
                  _repeatDaily = value ?? false;
                  _repeatUntil ??= _scheduledAt.add(const Duration(days: 6));
                }),
                title: Text(
                  const S('Repeat every day', 'تكرار كل يوم').of(context),
                ),
                subtitle: Text(
                  const S(
                    'Creates one trip per day at the same time, up to the '
                        'end date below.',
                    'بينشئ رحلة كل يوم في نفس الميعاد، لحد تاريخ النهاية '
                        'تحت.',
                  ).of(context),
                ),
              ),
              if (_repeatDaily)
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: _pickRepeatUntil,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.appColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_repeat_outlined),
                      title: Text(
                        const S('Repeat until', 'يتكرر لحد').of(context),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().format(
                          _repeatUntil ?? _scheduledAt,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textPrimary,
                        ),
                      ),
                      trailing: Text(
                        S(
                          '${_dayCount()} trips',
                          '${_dayCount()} رحلة',
                        ).of(context),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(const S('Cancel', 'إلغاء').of(context)),
        ),
        FilledButton(
          onPressed: _routeId == null || _busId == null || _driverId == null
              ? null
              : () {
                  for (final date in _scheduledDates()) {
                    widget.onCreate(
                      TripCreated(
                        schoolId: widget.schoolId,
                        routeId: _routeId!,
                        routeName: _routeName,
                        busId: _busId!,
                        busName: _busName,
                        busPlateNumber: _busPlateNumber,
                        driverId: _driverId!,
                        driverName: _driverName,
                        scheduledAt: date,
                        direction: _direction,
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
          child: Text(const S('Save', 'حفظ').of(context)),
        ),
      ],
    );
  }

  /// One entry for a single trip, or one per non-holiday day (inclusive) up
  /// to [_repeatUntil] when repeating — always at least one (a single trip
  /// the admin explicitly picked a date for is created even if that date
  /// happens to be a holiday; the calendar only prunes the *generated*
  /// days of a repeat), and repeating with an end date before the start
  /// date still yields exactly the original single trip rather than
  /// creating none. Feature: school calendar — skips any day
  /// `_school?.isHoliday` flags (weekly recurring or a special date).
  List<DateTime> _scheduledDates() {
    if (!_repeatDaily) return [_scheduledAt];
    final until = _repeatUntil ?? _scheduledAt;
    final days = until
        .difference(DateTime(_scheduledAt.year, _scheduledAt.month, _scheduledAt.day))
        .inDays;
    if (days <= 0) return [_scheduledAt];
    final school = _school;
    return [
      for (var i = 0; i <= days; i++)
        if (school == null || !school.isHoliday(_scheduledAt.add(Duration(days: i))))
          _scheduledAt.add(Duration(days: i)),
    ];
  }

  int _dayCount() => _scheduledDates().length;

  Future<void> _pickRepeatUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? _scheduledAt.add(const Duration(days: 6)),
      firstDate: _scheduledAt,
      lastDate: _scheduledAt.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() => _repeatUntil = picked);
  }

  Future<void> _pickScheduledAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }
}
