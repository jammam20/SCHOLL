import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/notification_routing.dart';
import '../../dashboard/presentation/control_center_tab.dart';
import '../../incidents/presentation/incidents_page.dart';
import '../../ops/presentation/live_ops_tab.dart';
import '../../profile/presentation/profile_page.dart';
import '../../routes/data/routes_repository.dart';
import '../../routes/presentation/route_deviations_page.dart';
import '../../students/data/students_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../../vehicles/presentation/vehicle_management_page.dart';
import '../../../widgets/async_error_view.dart';

/// The read-only home for [UserRole.staff] — school staff and teachers who
/// need operational visibility but must never be able to change anything.
///
/// Every surface here is either a read-only rendering of data staff can
/// already read per firestore.rules (`buses`, `routes`, `students`,
/// `trips`, `incidents`, `routeDeviations`, `driverProfiles`, `auditLog`),
/// or an existing widget explicitly placed in its read-only mode. There is
/// deliberately no add/edit/delete/approve control anywhere in this shell:
/// the rules never grant `staff` a write on anything, so offering one would
/// only ever produce a permission-denied error.
///
/// Read-only is enforced structurally rather than by disabling buttons —
/// the write-capable pages simply aren't reachable from this nav.
class StaffHomePage extends StatefulWidget {
  const StaffHomePage({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    NotificationRouting.pendingTarget.addListener(_onNotificationTapped);
    _onNotificationTapped();
  }

  @override
  void dispose() {
    NotificationRouting.pendingTarget.removeListener(_onNotificationTapped);
    super.dispose();
  }

  /// Tapping any push notification opens the live map, where emergencies,
  /// deviations and incidents all surface — the same routing rule the
  /// admin shell uses, pointed at this nav's own map index.
  void _onNotificationTapped() {
    if (NotificationRouting.pendingTarget.value == null) return;
    NotificationRouting.pendingTarget.value = null;
    setState(() => _index = 1);
  }

  void _jump(DashboardJumpTarget target) {
    switch (target) {
      case DashboardJumpTarget.liveOps:
        setState(() => _index = 1);
      case DashboardJumpTarget.incidents:
        setState(() => _index = 3);
      case DashboardJumpTarget.deviations:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RouteDeviationsPage(schoolId: widget.user.schoolId),
          ),
        );
      case DashboardJumpTarget.people:
      case DashboardJumpTarget.operations:
        // Staff's dashboard never shows the quick-actions row that raises
        // these (ControlCenterTab hides it when readOnly), and staff has
        // no People/manage-fleet destination of its own to jump to.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = widget.user.schoolId;
    final appColors = context.appColors;

    final pages = [
      ControlCenterTab(user: widget.user, onJump: _jump, readOnly: true),
      Scaffold(
        appBar: AppBar(
          title: Text(
            const S(
              'Live map',
              'الخريطة المباشرة',
              fr: 'Carte en direct',
              es: 'Mapa en vivo',
            ).of(context),
          ),
        ),
        body: LiveOpsTab(schoolId: schoolId, readOnly: true),
      ),
      _StaffFleetTab(schoolId: schoolId),
      IncidentsPage(schoolId: schoolId, readOnly: true),
      ProfilePage(user: widget.user, onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: DecoratedBox(
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
              label: const S(
                'Today',
                'النهارده',
                fr: "Aujourd'hui",
                es: 'Hoy',
              ).of(context),
            ),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              label: const S(
                'Live map',
                'الخريطة',
                fr: 'Carte',
                es: 'Mapa',
              ).of(context),
            ),
            NavigationDestination(
              icon: const Icon(Icons.directions_bus_outlined),
              selectedIcon: const Icon(Icons.directions_bus),
              label: const S(
                'Fleet',
                'الأسطول',
                fr: 'Flotte',
                es: 'Flota',
              ).of(context),
            ),
            NavigationDestination(
              icon: const Icon(Icons.report_outlined),
              selectedIcon: const Icon(Icons.report),
              label: const S(
                'Incidents',
                'البلاغات',
                fr: 'Incidents',
                es: 'Incidentes',
              ).of(context),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: const S(
                'Profile',
                'حسابي',
                fr: 'Profil',
                es: 'Perfil',
              ).of(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Buses, routes, expected students and today's trips — all read-only.
class _StaffFleetTab extends StatelessWidget {
  const _StaffFleetTab({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            const S(
              'Fleet',
              'الأسطول',
              fr: 'Flotte',
              es: 'Flota',
            ).of(context),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                text: const S(
                  'Buses',
                  'الأتوبيسات',
                  fr: 'Bus',
                  es: 'Autobuses',
                ).of(context),
              ),
              Tab(
                text: const S(
                  'Routes',
                  'الخطوط',
                  fr: 'Itinéraires',
                  es: 'Rutas',
                ).of(context),
              ),
              Tab(
                text: const S(
                  'Students',
                  'الطلاب',
                  fr: 'Élèves',
                  es: 'Estudiantes',
                ).of(context),
              ),
              Tab(
                text: const S(
                  'Trips today',
                  'رحلات النهارده',
                  fr: "Trajets du jour",
                  es: 'Viajes de hoy',
                ).of(context),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            VehicleManagementPage(schoolId: schoolId, readOnly: true),
            _StaffRoutesList(schoolId: schoolId),
            _StaffStudentsList(schoolId: schoolId),
            _StaffTripsList(schoolId: schoolId),
          ],
        ),
      ),
    );
  }
}

class _StaffRoutesList extends StatelessWidget {
  const _StaffRoutesList({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RoutesRepository().watchRoutes(schoolId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AsyncErrorView();
        if (!snapshot.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 5,
            itemBuilder: (_, _) => const AppSkeletonListTile(),
          );
        }

        final routes = snapshot.data!.docs
            .map((doc) => SchoolRoute.fromMap(doc.id, doc.data()))
            .toList();

        if (routes.isEmpty) {
          return EmptyStateView(
            icon: Icons.route_outlined,
            title: const S(
              'No routes yet.',
              'مفيش خطوط لسه.',
              fr: "Pas encore d'itinéraires.",
              es: 'Aún no hay rutas.',
            ).of(context),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: routes.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, index) {
            final route = routes[index];
            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.route, color: colors.info),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      route.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  StatusBadge(
                    label: route.isActive
                        ? const S(
                            'Active',
                            'نشط',
                            fr: 'Actif',
                            es: 'Activo',
                          ).of(context)
                        : const S(
                            'Inactive',
                            'غير نشط',
                            fr: 'Inactif',
                            es: 'Inactivo',
                          ).of(context),
                    tone: route.isActive
                        ? StatusTone.success
                        : StatusTone.neutral,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StaffStudentsList extends StatelessWidget {
  const _StaffStudentsList({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

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
            .where((student) => student.approved)
            .toList();

        if (students.isEmpty) {
          return EmptyStateView(
            icon: Icons.groups_outlined,
            title: const S(
              'No students yet.',
              'مفيش طلاب لسه.',
              fr: "Pas encore d'élèves.",
              es: 'Aún no hay estudiantes.',
            ).of(context),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: students.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, index) {
            final student = students[index];
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          student.routeId == null || student.routeId!.isEmpty
                              ? const S(
                                  'No route assigned',
                                  'من غير خط',
                                  fr: 'Aucun itinéraire assigné',
                                  es: 'Sin ruta asignada',
                                ).of(context)
                              : const S(
                                  'Route assigned',
                                  'الخط متحدد',
                                  fr: 'Itinéraire assigné',
                                  es: 'Ruta asignada',
                                ).of(context),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (student.isAbsentToday)
                    StatusBadge(
                      label: const S(
                        'Absent today',
                        'غايب النهاردة',
                        fr: "Absent aujourd'hui",
                        es: 'Ausente hoy',
                      ).of(context),
                      tone: StatusTone.warning,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StaffTripsList extends StatelessWidget {
  const _StaffTripsList({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchTrips(schoolId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AsyncErrorView();
        if (!snapshot.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 5,
            itemBuilder: (_, _) => const AppSkeletonListTile(),
          );
        }

        final now = DateTime.now();
        final trips = snapshot.data!.docs
            .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
            .where(
              (trip) =>
                  trip.scheduledAt.year == now.year &&
                  trip.scheduledAt.month == now.month &&
                  trip.scheduledAt.day == now.day,
            )
            .toList();

        if (trips.isEmpty) {
          return EmptyStateView(
            icon: Icons.event_busy_outlined,
            title: const S(
              'No trips scheduled today.',
              'مفيش رحلات النهارده.',
              fr: "Aucun trajet prévu aujourd'hui.",
              es: 'No hay viajes programados hoy.',
            ).of(context),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: trips.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, index) {
            final trip = trips[index];
            final tone = switch (trip.status) {
              TripStatus.scheduled => StatusTone.neutral,
              TripStatus.starting || TripStatus.active => StatusTone.info,
              TripStatus.paused => StatusTone.warning,
              TripStatus.completed => StatusTone.success,
              TripStatus.cancelled => StatusTone.neutral,
              TripStatus.emergency => StatusTone.emergency,
            };

            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bus,
                    color: toneColor(colors, tone),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.routeName.isEmpty
                              ? trip.routeId
                              : trip.routeName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${trip.busName} · ${trip.driverName}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: switch (trip.status) {
                      TripStatus.scheduled => const S(
                        'Scheduled',
                        'مجدولة',
                        fr: 'Planifié',
                        es: 'Programado',
                      ).of(context),
                      TripStatus.starting => const S(
                        'Starting',
                        'جاري البدء',
                        fr: 'Démarrage',
                        es: 'Iniciando',
                      ).of(context),
                      TripStatus.active => const S(
                        'En route',
                        'في الطريق',
                        fr: 'En route',
                        es: 'En camino',
                      ).of(context),
                      TripStatus.paused => const S(
                        'Paused',
                        'متوقفة مؤقتاً',
                        fr: 'En pause',
                        es: 'Pausado',
                      ).of(context),
                      TripStatus.completed => const S(
                        'Completed',
                        'مكتملة',
                        fr: 'Terminé',
                        es: 'Completado',
                      ).of(context),
                      TripStatus.cancelled => const S(
                        'Cancelled',
                        'ملغاة',
                        fr: 'Annulé',
                        es: 'Cancelado',
                      ).of(context),
                      TripStatus.emergency => const S(
                        'Emergency',
                        'حالة طوارئ',
                        fr: 'Urgence',
                        es: 'Emergencia',
                      ).of(context),
                    },
                    tone: tone,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
