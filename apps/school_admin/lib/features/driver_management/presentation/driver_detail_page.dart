import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../buses/data/buses_repository.dart';
import '../../common/presentation/domain_labels.dart';
import '../../drivers/data/drivers_repository.dart';
import '../../routes/data/routes_repository.dart';
import '../../../widgets/activity_timeline.dart';
import '../../../widgets/async_error_view.dart';
import '../data/driver_performance_repository.dart';
import '../data/driver_profiles_repository.dart';
import 'bloc/driver_management_bloc.dart';

/// One driver: their editable [DriverProfile] (licence, training, assigned
/// buses and routes) plus a performance section counted from real trip and
/// deviation records.
class DriverDetailPage extends StatelessWidget {
  const DriverDetailPage({
    super.key,
    required this.schoolId,
    required this.uid,
    required this.displayName,
  });

  final String schoolId;
  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          DriverManagementBloc(DriversRepository(), DriverProfilesRepository())
            ..add(DriverManagementStarted(schoolId)),
      child: _DriverDetailView(
        schoolId: schoolId,
        uid: uid,
        displayName: displayName,
      ),
    );
  }
}

class _DriverDetailView extends StatelessWidget {
  const _DriverDetailView({
    required this.schoolId,
    required this.uid,
    required this.displayName,
  });

  final String schoolId;
  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DriverManagementBloc, DriverManagementState>(
      listenWhen: (_, current) =>
          current is DriverManagementLoaded &&
          (current.actionError != null || current.saved),
      listener: (context, state) {
        if (state is! DriverManagementLoaded) return;
        if (state.actionError != null) {
          AppSnackbar.error(context, state.actionError!);
        } else if (state.saved) {
          AppSnackbar.success(
            context,
            const S(
              'Driver profile saved.',
              'تم حفظ بيانات السائق.',
              fr: 'Profil du chauffeur enregistré.',
              es: 'Perfil del conductor guardado.',
            ).of(context),
          );
        }
      },
      builder: (context, state) {
        Widget body;

        if (state is DriverManagementLoading ||
            state is DriverManagementInitial) {
          body = ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.xl),
            itemCount: 6,
            itemBuilder: (_, _) => const AppSkeletonListTile(),
          );
        } else if (state is DriverManagementFailure) {
          body = ErrorStateView(
            message: state.message,
            onRetry: () => context.read<DriverManagementBloc>().add(
              DriverManagementStarted(schoolId),
            ),
          );
        } else {
          final loaded = state as DriverManagementLoaded;
          final driver = loaded.drivers
              .where((candidate) => candidate.uid == uid)
              .firstOrNull;

          body = driver == null
              ? EmptyStateView(
                  icon: Icons.person_off_outlined,
                  title: const S(
                    'This driver is no longer in your school.',
                    'السائق ده مبقاش في مدرستك.',
                    fr: "Ce chauffeur ne fait plus partie de votre école.",
                    es: 'Este conductor ya no pertenece a su escuela.',
                  ).of(context),
                )
              : _DriverDetailBody(schoolId: schoolId, driver: driver);
        }

        return Scaffold(
          appBar: AppBar(title: Text(displayName)),
          body: body,
        );
      },
    );
  }
}

class _DriverDetailBody extends StatelessWidget {
  const _DriverDetailBody({required this.schoolId, required this.driver});

  final String schoolId;
  final DriverWithProfile driver;

  @override
  Widget build(BuildContext context) {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final profileCard = _DriverProfileCard(
                schoolId: schoolId,
                driver: driver,
              );
              final performanceCard = _DriverPerformanceCard(
                schoolId: schoolId,
                driver: driver,
              );
              final activityCard = _DriverActivityCard(
                schoolId: schoolId,
                driverId: driver.uid,
              );

              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    profileCard,
                    const SizedBox(height: AppSpacing.xl2),
                    performanceCard,
                    const SizedBox(height: AppSpacing.xl2),
                    activityCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: profileCard),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        performanceCard,
                        const SizedBox(height: AppSpacing.xl2),
                        activityCard,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Feature: activity timeline — reuses the school's existing audit trail,
/// filtered to entries about this one driver.
class _DriverActivityCard extends StatelessWidget {
  const _DriverActivityCard({required this.schoolId, required this.driverId});

  final String schoolId;
  final String driverId;

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
            title: const S(
              'Recent activity',
              'النشاط الأخير',
              fr: 'Activité récente',
              es: 'Actividad reciente',
            ).of(context),
          ),
          const SizedBox(height: AppSpacing.md),
          ActivityTimeline(
            schoolId: schoolId,
            matches: (entry) => entry.driverId == driverId,
          ),
        ],
      ),
    );
  }
}

class _DriverProfileCard extends StatefulWidget {
  const _DriverProfileCard({required this.schoolId, required this.driver});

  final String schoolId;
  final DriverWithProfile driver;

  @override
  State<_DriverProfileCard> createState() => _DriverProfileCardState();
}

class _DriverProfileCardState extends State<_DriverProfileCard> {
  late final TextEditingController _licenseNumber = TextEditingController(
    text: widget.driver.profile?.licenseNumber ?? '',
  );
  late DateTime? _licenseExpiry = widget.driver.profile?.licenseExpiry;
  late DateTime? _trainingCompletedAt =
      widget.driver.profile?.trainingCompletedAt;
  late final Set<String> _busIds = {
    ...?widget.driver.profile?.assignedBusIds,
  };
  late final Set<String> _routeIds = {
    ...?widget.driver.profile?.assignedRouteIds,
  };

  @override
  void dispose() {
    _licenseNumber.dispose();
    super.dispose();
  }

  void _save() {
    context.read<DriverManagementBloc>().add(
      DriverProfileSaved(
        schoolId: widget.schoolId,
        uid: widget.driver.uid,
        licenseNumber: _licenseNumber.text.trim().isEmpty
            ? null
            : _licenseNumber.text,
        licenseExpiry: _licenseExpiry,
        trainingCompletedAt: _trainingCompletedAt,
        assignedBusIds: _busIds.toList(),
        assignedRouteIds: _routeIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();

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
            title: const S(
              'Driver profile',
              'بيانات السائق',
              fr: 'Profil du chauffeur',
              es: 'Perfil del conductor',
            ).of(context),
            trailing: StatusBadge(
              label: memberStatusLabel(context, widget.driver.status),
              tone: memberStatusTone(widget.driver.status),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.driver.licenseExpired ||
              widget.driver.licenseExpiringSoon(now))
            _LicenseAlertBanner(driver: widget.driver, now: now),
          TextField(
            controller: _licenseNumber,
            decoration: InputDecoration(
              labelText: const S(
                'Licence number',
                'رقم الرخصة',
                fr: 'Numéro de permis',
                es: 'Número de licencia',
              ).of(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: const S(
              'Licence expiry',
              'انتهاء الرخصة',
              fr: 'Expiration du permis',
              es: 'Vencimiento de la licencia',
            ).of(context),
            value: _licenseExpiry,
            onChanged: (value) => setState(() => _licenseExpiry = value),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: const S(
              'Training completed',
              'تاريخ إتمام التدريب',
              fr: 'Formation terminée',
              es: 'Capacitación completada',
            ).of(context),
            value: _trainingCompletedAt,
            onChanged: (value) => setState(() => _trainingCompletedAt = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            const S(
              'Assigned buses',
              'الأتوبيسات المخصصة',
              fr: 'Bus assignés',
              es: 'Autobuses asignados',
            ).of(context).toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: BusesRepository().watchBuses(widget.schoolId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const AsyncErrorView(compact: true);
              }
              final buses = snapshot.data?.docs ?? const [];
              if (buses.isEmpty) {
                return Text(
                  const S(
                    'No buses to assign yet.',
                    'مفيش أتوبيسات تتخصص لسه.',
                    fr: "Aucun bus à assigner pour l'instant.",
                    es: 'Aún no hay autobuses para asignar.',
                  ).of(context),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                );
              }
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final doc in buses)
                    FilterChip(
                      label: Text(
                        '${doc.data()['name'] ?? doc.id} '
                        '(${doc.data()['plateNumber'] ?? ''})',
                      ),
                      selected: _busIds.contains(doc.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _busIds.add(doc.id);
                        } else {
                          _busIds.remove(doc.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            const S(
              'Assigned routes',
              'الخطوط المخصصة',
              fr: 'Itinéraires assignés',
              es: 'Rutas asignadas',
            ).of(context).toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: RoutesRepository().watchRoutes(widget.schoolId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const AsyncErrorView(compact: true);
              }
              final routes = snapshot.data?.docs ?? const [];
              if (routes.isEmpty) {
                return Text(
                  const S(
                    'No routes to assign yet.',
                    'مفيش خطوط تتخصص لسه.',
                    fr: "Aucun itinéraire à assigner pour l'instant.",
                    es: 'Aún no hay rutas para asignar.',
                  ).of(context),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                );
              }
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final doc in routes)
                    FilterChip(
                      label: Text(doc.data()['name']?.toString() ?? doc.id),
                      selected: _routeIds.contains(doc.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _routeIds.add(doc.id);
                        } else {
                          _routeIds.remove(doc.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            icon: Icons.save_outlined,
            label: const S(
              'Save profile',
              'حفظ البيانات',
              fr: 'Enregistrer le profil',
              es: 'Guardar perfil',
            ).of(context),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _LicenseAlertBanner extends StatelessWidget {
  const _LicenseAlertBanner({required this.driver, required this.now});

  final DriverWithProfile driver;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final expired = driver.licenseExpired;
    final accent = expired ? colors.error : colors.warning;
    final expiry = driver.profile!.licenseExpiry!;
    final days = DateTime(expiry.year, expiry.month, expiry.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.gpp_bad_outlined : Icons.warning_amber_rounded,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              expired
                  ? S(
                      'This licence expired ${-days} day(s) ago. This driver '
                          'should not be assigned to trips until it is renewed.',
                      'الرخصة دي انتهت من ${-days} يوم. مينفعش السائق ده '
                          'يتخصص لرحلات لحد ما تتجدد.',
                      fr:
                          'Ce permis a expiré il y a ${-days} jour(s). Ce '
                          "chauffeur ne doit pas être assigné à des trajets "
                          "tant qu'il n'est pas renouvelé.",
                      es:
                          'Esta licencia venció hace ${-days} día(s). Este '
                          'conductor no debe ser asignado a viajes hasta que '
                          'se renueve.',
                    ).of(context)
                  : S(
                      'This licence expires in $days day(s).',
                      'الرخصة دي هتنتهي خلال $days يوم.',
                      fr: 'Ce permis expire dans $days jour(s).',
                      es: 'Esta licencia vence en $days día(s).',
                    ).of(context),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trip and deviation counts for this driver, all counted from real
/// records. See [DriverPerformance]'s doc comment for what is deliberately
/// *not* shown here (no safety score, no rating — this system stores no
/// data that could honestly produce either).
class _DriverPerformanceCard extends StatelessWidget {
  const _DriverPerformanceCard({required this.schoolId, required this.driver});

  final String schoolId;
  final DriverWithProfile driver;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final repository = DriverPerformanceRepository();

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
            title: const S(
              'Performance',
              'الأداء',
              fr: 'Performance',
              es: 'Rendimiento',
            ).of(context),
            subtitle: const S(
              'Counted from this driver’s own trip and route-deviation '
                  'records.',
              'محسوبة من سجل رحلات السائق ده وخروجه عن المسار.',
              fr:
                  "Calculé à partir des trajets et des écarts d'itinéraire "
                  'propres à ce chauffeur.',
              es:
                  'Calculado a partir de los viajes y desvíos de ruta '
                  'propios de este conductor.',
            ).of(context),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: repository.watchDriverTrips(
              schoolId: schoolId,
              driverId: driver.uid,
            ),
            builder: (context, tripsSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: repository.watchDeviations(schoolId),
                builder: (context, deviationsSnapshot) {
                  if (tripsSnapshot.hasError || deviationsSnapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  if (!tripsSnapshot.hasData) {
                    return const Column(
                      children: [
                        AppSkeletonListTile(),
                        AppSkeletonListTile(),
                      ],
                    );
                  }

                  final trips = tripsSnapshot.data!.docs
                      .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
                      .toList();
                  // Deviations may still be loading; an absent list just
                  // means the deviation count reads 0 for a moment, which
                  // is preferable to blocking the whole card.
                  final deviations = (deviationsSnapshot.data?.docs ?? const [])
                      .map((doc) => DeviationRecord.fromMap(doc.id, doc.data()))
                      .toList();

                  final performance =
                      DriverPerformanceRepository.performanceFrom(
                        driverId: driver.uid,
                        trips: trips,
                        deviations: deviations,
                      );

                  if (performance.totalTrips == 0) {
                    return EmptyStateView(
                      compact: true,
                      icon: Icons.event_busy_outlined,
                      title: const S(
                        'No trips assigned to this driver yet.',
                        'مفيش رحلات متخصصة للسائق ده لسه.',
                        fr: "Aucun trajet assigné à ce chauffeur pour l'instant.",
                        es: 'Aún no hay viajes asignados a este conductor.',
                      ).of(context),
                    );
                  }

                  return _PerformanceGrid(performance: performance);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PerformanceGrid extends StatelessWidget {
  const _PerformanceGrid({required this.performance});

  final DriverPerformance performance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    String duration(Duration? value) {
      if (value == null) return '—';
      if (value.inHours > 0) {
        return '${value.inHours}h ${value.inMinutes % 60}m';
      }
      return '${value.inMinutes}m';
    }

    final cards = [
      MetricStatCard(
        icon: Icons.task_alt,
        tone: colors.success,
        label: const S(
          'Completed trips',
          'رحلات مكتملة',
          fr: 'Trajets terminés',
          es: 'Viajes completados',
        ).of(context),
        value: '${performance.completedTrips}',
      ),
      MetricStatCard(
        icon: Icons.schedule,
        tone: colors.info,
        label: const S(
          'On-time rate',
          'نسبة الالتزام بالمعاد',
          fr: 'Taux de ponctualité',
          es: 'Tasa de puntualidad',
        ).of(context),
        value: performance.onTimeRate == null
            ? '—'
            : '${(performance.onTimeRate! * 100).round()}%',
      ),
      MetricStatCard(
        icon: Icons.warning_amber_rounded,
        tone: performance.emergencyTrips > 0
            ? colors.emergency
            : colors.success,
        label: const S(
          'Emergency trips',
          'رحلات بها طوارئ',
          fr: 'Trajets d’urgence',
          es: 'Viajes de emergencia',
        ).of(context),
        value: '${performance.emergencyTrips}',
      ),
      MetricStatCard(
        icon: Icons.alt_route,
        tone: performance.deviationCount > 0 ? colors.warning : colors.success,
        label: const S(
          'Route deviations',
          'خروج عن المسار',
          fr: "Écarts d'itinéraire",
          es: 'Desvíos de ruta',
        ).of(context),
        value: '${performance.deviationCount}',
      ),
      MetricStatCard(
        icon: Icons.timer_outlined,
        label: const S(
          'Avg. trip duration',
          'متوسط مدة الرحلة',
          fr: 'Durée moyenne du trajet',
          es: 'Duración media del viaje',
        ).of(context),
        value: duration(performance.averageTripDuration),
      ),
      MetricStatCard(
        icon: Icons.cancel_outlined,
        tone: colors.textMuted,
        label: const S(
          'Cancelled trips',
          'رحلات ملغاة',
          fr: 'Trajets annulés',
          es: 'Viajes cancelados',
        ).of(context),
        value: '${performance.cancelledTrips}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
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

/// Same tap-to-pick-with-clear date control the vehicle profile uses.
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
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 20),
          lastDate: DateTime(now.year + 20),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.event_outlined)
              : IconButton(
                  tooltip: const S(
                    'Clear',
                    'مسح',
                    fr: 'Effacer',
                    es: 'Borrar',
                  ).of(context),
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          value == null
              ? const S(
                  'Not set',
                  'مش متحدد',
                  fr: 'Non défini',
                  es: 'No definido',
                ).of(context)
              : DateFormat.yMMMd().format(value!),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: value == null ? colors.textMuted : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
