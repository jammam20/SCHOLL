import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// `hide TextDirection`: intl exports its own bidi `TextDirection` enum,
// which would otherwise collide with the `dart:ui`/Flutter one used below
// to force timestamps to render LTR inside an Arabic layout (RTL rule in
// design-system/MASTER.md §13).
import 'package:intl/intl.dart' hide TextDirection;
import 'package:school_shared/school_shared.dart';

import '../../../app/notification_routing.dart';
import '../../profile/presentation/profile_page.dart';
import '../../../tracking/data/driver_tracking_repository.dart';
import '../../emergencies/data/emergencies_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../../trips/presentation/bloc/trips_bloc.dart';
import '../../trips/presentation/stop_order_view.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // A tapped push notification (trip status change or emergency) always
    // means "look at your trips" — the only other tab is Profile.
    NotificationRouting.pendingTarget.addListener(_onNotificationTapped);
    _onNotificationTapped();
  }

  @override
  void dispose() {
    NotificationRouting.pendingTarget.removeListener(_onNotificationTapped);
    super.dispose();
  }

  void _onNotificationTapped() {
    if (NotificationRouting.pendingTarget.value == null) return;
    NotificationRouting.pendingTarget.value = null;
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _TripsTab(user: widget.user),
      ProfilePage(user: widget.user, onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.directions_bus_outlined),
            selectedIcon: const Icon(Icons.directions_bus_filled),
            label: const S('Trips', 'الرحلات').of(context),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: const S('Profile', 'حسابي').of(context),
          ),
        ],
      ),
    );
  }
}

class _TripsTab extends StatelessWidget {
  const _TripsTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TripsBloc(TripsRepository(), DriverTrackingRepository())
        ..add(TripsStarted(schoolId: user.schoolId, driverId: user.uid)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            S('Welcome, ${user.name}', 'أهلاً بيك، ${user.name}').of(context),
          ),
        ),
        body: BlocConsumer<TripsBloc, TripsState>(
          listener: (context, state) {
            if (state is TripsLoaded && state.actionError != null) {
              AppSnackbar.error(context, state.actionError!);
            }
          },
          builder: (context, state) {
            final reduceMotion = MediaQuery.of(context).disableAnimations;

            Widget child;
            if (state is TripsLoading || state is TripsInitial) {
              child = const Center(child: CircularProgressIndicator());
            } else if (state is TripsFailure) {
              child = ErrorStateView(message: state.message);
            } else {
              final snapshot = state is TripsLoaded ? state.snapshot : null;
              final docs = snapshot?.docs ?? const [];

              if (docs.isEmpty) {
                child = EmptyStateView(
                  icon: Icons.event_busy,
                  title: const S(
                    'No trips assigned yet',
                    'مفيش رحلات متعينة لسه',
                  ).of(context),
                  message: const S(
                    'Your school administrator will assign a route before '
                        'your next trip.',
                    'أدمن مدرستك هيعيّنلك خط سير قبل رحلتك الجاية.',
                  ).of(context),
                );
              } else {
                child = ListView.builder(
                  key: const PageStorageKey('trips-list'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl2,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final doc = docs[index];
                    final trip = SchoolTrip.fromMap(doc.id, doc.data());
                    return _TripCard(schoolId: user.schoolId, trip: trip);
                  },
                );
              }
            }

            // A single, restrained crossfade between loading/content/error/
            // empty — never re-triggered by unrelated rebuilds since the key
            // only changes when the state's shape actually changes. See
            // design-system/MASTER.md §10; skipped entirely under reduced
            // motion per §10/§12.
            return AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : AppDurations.stateSwitch,
              child: KeyedSubtree(
                key: ValueKey(state.runtimeType),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The one dot+label pattern (`StatusBadge`) is reused for every trip status,
/// so the tone here is the single source of truth for what each status
/// means at a glance. `info` covers both "starting" and "active" (en route)
/// per design-system/MASTER.md §2; `error` is deliberately never used here —
/// it's reserved for genuine failures, not normal trip states, even
/// terminal ones like `cancelled`.
StatusTone _statusTone(TripStatus status) => switch (status) {
  TripStatus.scheduled => StatusTone.neutral,
  TripStatus.starting => StatusTone.info,
  TripStatus.active => StatusTone.info,
  TripStatus.paused => StatusTone.warning,
  TripStatus.completed => StatusTone.success,
  TripStatus.cancelled => StatusTone.neutral,
  TripStatus.emergency => StatusTone.emergency,
};

String _statusLabel(TripStatus status, BuildContext context) => switch (status) {
  TripStatus.scheduled => const S('Scheduled', 'مجدولة').of(context),
  TripStatus.starting => const S('Starting', 'جاري البدء').of(context),
  TripStatus.active => const S('En route', 'في الطريق').of(context),
  TripStatus.paused => const S('Paused', 'متوقفة مؤقتاً').of(context),
  TripStatus.completed => const S('Completed', 'مكتملة').of(context),
  TripStatus.cancelled => const S('Cancelled', 'ملغاة').of(context),
  TripStatus.emergency => const S('Emergency', 'حالة طوارئ').of(context),
};

class _TripCard extends StatelessWidget {
  const _TripCard({required this.schoolId, required this.trip});

  final String schoolId;
  final SchoolTrip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isEmergency = trip.status == TripStatus.emergency;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      // A trip mid-emergency gets a solid emergency-colored outline — a
      // steady, unambiguous signal (never a pulse/flash — see
      // design-system/MASTER.md §10) so it can't be missed at a glance
      // while the driver is also watching the road.
      shape: isEmergency
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: colors.emergency, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    trip.routeName.isEmpty
                        ? S(
                            'Route ${trip.routeId}',
                            'خط سير ${trip.routeId}',
                          ).of(context)
                        : trip.routeName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: _statusLabel(trip.status, context),
                  tone: _statusTone(trip.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.directions_bus_outlined,
                  size: 16,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${trip.busName} (${trip.busPlateNumber})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    DateFormat.yMMMd().add_jm().format(trip.scheduledAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._actions(context),
            if (isEmergency) ...[
              const SizedBox(height: AppSpacing.md),
              _ActiveEmergencyBanner(schoolId: schoolId, tripId: trip.id),
            ],
            if (trip.status == TripStatus.active ||
                trip.status == TripStatus.starting ||
                trip.status == TripStatus.paused ||
                trip.status == TripStatus.emergency)
              StopOrderView(
                schoolId: schoolId,
                tripId: trip.id,
                routeId: trip.routeId,
              ),
          ],
        ),
      ),
    );
  }

  /// One full-width button per row — large touch targets, one obvious next
  /// step per card. The state-appropriate forward action (start/continue/
  /// resume/complete) is always the prominent `AppButton.primary` and comes
  /// first; a secondary action (pause/cancel) follows as `AppButton.
  /// secondary`; emergency reporting is kept visually separate from this
  /// hierarchy entirely — see `_emergencyButton` — so it never competes
  /// with, or gets mistaken for, the routine trip actions above it.
  List<Widget> _actions(BuildContext context) {
    final bloc = context.read<TripsBloc>();

    Widget primary(String label, IconData icon, VoidCallback onPressed) =>
        SizedBox(
          width: double.infinity,
          child: AppButton.primary(label: label, icon: icon, onPressed: onPressed),
        );
    Widget secondary(String label, IconData icon, VoidCallback onPressed) =>
        SizedBox(
          width: double.infinity,
          child: AppButton.secondary(label: label, icon: icon, onPressed: onPressed),
        );

    switch (trip.status) {
      case TripStatus.scheduled:
        return [
          primary(
            const S('Start trip', 'ابدأ الرحلة').of(context),
            Icons.play_arrow,
            () => bloc.add(
              TripStartRequested(
                schoolId: schoolId,
                tripId: trip.id,
                routeId: trip.routeId,
                alreadyStarting: false,
              ),
            ),
          ),
        ];
      case TripStatus.starting:
        return [
          primary(
            const S('Continue starting', 'كمّل البدء').of(context),
            Icons.play_arrow,
            () => bloc.add(
              TripStartRequested(
                schoolId: schoolId,
                tripId: trip.id,
                routeId: trip.routeId,
                alreadyStarting: true,
              ),
            ),
          ),
        ];
      case TripStatus.active:
        return [
          primary(
            const S('Complete', 'إنهاء').of(context),
            Icons.check,
            () => bloc.add(
              TripCompleteRequested(schoolId: schoolId, tripId: trip.id),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          secondary(
            const S('Pause', 'وقف مؤقت').of(context),
            Icons.pause,
            () => bloc.add(
              TripPauseRequested(schoolId: schoolId, tripId: trip.id),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _emergencyButton(
            context,
            () => _reportEmergency(context, bloc: bloc, schoolId: schoolId, tripId: trip.id),
          ),
        ];
      case TripStatus.paused:
        return [
          primary(
            const S('Resume', 'استكمال').of(context),
            Icons.play_arrow,
            () => bloc.add(
              TripResumeRequested(schoolId: schoolId, tripId: trip.id),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          secondary(
            const S('Cancel', 'إلغاء').of(context),
            Icons.close,
            () => bloc.add(
              TripCancelRequested(schoolId: schoolId, tripId: trip.id),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _emergencyButton(
            context,
            () => _reportEmergency(context, bloc: bloc, schoolId: schoolId, tripId: trip.id),
          ),
        ];
      case TripStatus.emergency:
        return [
          primary(
            const S('Complete', 'إنهاء').of(context),
            Icons.check,
            () => bloc.add(
              TripCompleteRequested(schoolId: schoolId, tripId: trip.id),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          secondary(
            const S('Cancel', 'إلغاء').of(context),
            Icons.close,
            () => bloc.add(
              TripCancelRequested(schoolId: schoolId, tripId: trip.id),
            ),
          ),
        ];
      case TripStatus.completed:
      case TripStatus.cancelled:
        return const [];
    }
  }

  /// Deliberately not an `AppButton` variant: reporting an emergency is not
  /// a routine trip action, so it's styled on its own — outlined in the
  /// `emergency` semantic token, full width, with the same generous
  /// (theme-default) padding as every other button here. Distinct, not
  /// decorative: a steady color, no motion, no siren iconography.
  Widget _emergencyButton(BuildContext context, VoidCallback onPressed) {
    final colors = context.appColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.emergency,
          side: BorderSide(color: colors.emergency, width: 1.6),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.warning_amber_rounded),
        label: Text(const S('Emergency', 'طوارئ').of(context)),
      ),
    );
  }

  Future<void> _reportEmergency(
    BuildContext context, {
    required TripsBloc bloc,
    required String schoolId,
    required String tripId,
  }) async {
    final result = await showDialog<({EmergencyType type, String? note})>(
      context: context,
      builder: (_) => const _EmergencyDialog(),
    );
    if (result == null) return;

    bloc.add(
      TripEmergencyRequested(
        schoolId: schoolId,
        tripId: tripId,
        emergencyType: result.type,
        driverNote: result.note,
      ),
    );
  }
}

String _emergencyTypeLabel(EmergencyType type, BuildContext context) {
  return switch (type) {
    EmergencyType.accident => const S('Accident', 'حادث').of(context),
    EmergencyType.vehicleBreakdown =>
      const S('Vehicle breakdown', 'عطل في المركبة').of(context),
    EmergencyType.medical => const S('Medical', 'حالة طبية').of(context),
    EmergencyType.security => const S('Security', 'أمنية').of(context),
    EmergencyType.other => const S('Other', 'أخرى').of(context),
  };
}

/// Asks for the minimum the emergency record needs (type is required by the
/// model; a note is optional) before the driver's tap actually creates
/// anything. Pre-existing from before this redesign pass — only its visual
/// styling changed here (emergency-toned icon/dialog button), not its
/// fields or flow.
class _EmergencyDialog extends StatefulWidget {
  const _EmergencyDialog();

  @override
  State<_EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<_EmergencyDialog> {
  EmergencyType _type = EmergencyType.other;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.emergency),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              const S('Report emergency', 'الإبلاغ عن حالة طوارئ').of(context),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<EmergencyType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: const S('Type', 'النوع').of(context),
              ),
              items: EmergencyType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_emergencyTypeLabel(type, context)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: const S(
                  'Notes (optional)',
                  'ملاحظات (اختياري)',
                ).of(context),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(const S('Cancel', 'إلغاء').of(context)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.emergency),
          onPressed: () => Navigator.pop(context, (
            type: _type,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          )),
          child: Text(const S('Report', 'إبلاغ').of(context)),
        ),
      ],
    );
  }
}

/// Shown on a trip card whenever its trip is in [TripStatus.emergency] and
/// has a still-active emergency record — lets the driver mark it resolved
/// without changing the trip's own status (which stays 'emergency' until
/// the driver explicitly completes or cancels the trip; see
/// TripStatus.canTransitionTo, unchanged by this phase).
class _ActiveEmergencyBanner extends StatelessWidget {
  const _ActiveEmergencyBanner({required this.schoolId, required this.tripId});

  final String schoolId;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: EmergenciesRepository().watchActiveEmergency(
        schoolId: schoolId,
        tripId: tripId,
      ),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final emergency = SchoolEmergency.fromMap(docs.first.id, docs.first.data());

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.emergency.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.emergency.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.emergency),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _emergencyTypeLabel(emergency.type, context),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (emergency.driverNote != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        emergency.driverNote!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.success,
                  side: BorderSide(color: colors.success),
                ),
                onPressed: () => context.read<TripsBloc>().add(
                  TripEmergencyResolveRequested(
                    schoolId: schoolId,
                    tripId: tripId,
                    emergencyId: emergency.id,
                  ),
                ),
                child: Text(const S('Mark resolved', 'تم الحل').of(context)),
              ),
            ],
          ),
        );
      },
    );
  }
}
