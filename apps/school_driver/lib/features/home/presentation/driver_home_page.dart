import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/app_settings.dart';
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.actionError!)));
            }
          },
          builder: (context, state) {
            if (state is TripsLoading || state is TripsInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is TripsFailure) {
              return Center(child: Text(state.message));
            }

            final snapshot = state is TripsLoaded ? state.snapshot : null;
            final docs = snapshot?.docs ?? const [];

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 56,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        const S(
                          'No trips assigned yet',
                          'مفيش رحلات متعينة لسه',
                        ).of(context),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              itemCount: docs.length,
              itemBuilder: (_, index) {
                final doc = docs[index];
                final trip = SchoolTrip.fromMap(doc.id, doc.data());
                return _TripCard(schoolId: user.schoolId, trip: trip);
              },
            );
          },
        ),
      ),
    );
  }
}

const _statusColors = {
  TripStatus.scheduled: Color(0xFF6C737F),
  TripStatus.starting: Color(0xFFF79009),
  TripStatus.active: Color(0xFF17B26A),
  TripStatus.paused: Color(0xFFF79009),
  TripStatus.completed: Color(0xFF155EEF),
  TripStatus.cancelled: Color(0xFF98A2B3),
  TripStatus.emergency: Color(0xFFF04438),
};

class _TripCard extends StatelessWidget {
  const _TripCard({required this.schoolId, required this.trip});

  final String schoolId;
  final SchoolTrip trip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColors[trip.status] ?? colors.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.routeName.isEmpty ? 'Route ${trip.routeId}' : trip.routeName,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trip.status.name,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.directions_bus, size: 15, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '${trip.busName} (${trip.busPlateNumber})',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.schedule, size: 15, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  DateFormat.yMMMd().add_jm().format(trip.scheduledAt),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: _actions(context)),
            if (trip.status == TripStatus.emergency)
              _ActiveEmergencyBanner(schoolId: schoolId, tripId: trip.id),
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

  List<Widget> _actions(BuildContext context) {
    final bloc = context.read<TripsBloc>();

    switch (trip.status) {
      case TripStatus.scheduled:
        return [
          FilledButton.icon(
            onPressed: () => bloc.add(
              TripStartRequested(
                schoolId: schoolId,
                tripId: trip.id,
                routeId: trip.routeId,
                alreadyStarting: false,
              ),
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(const S('Start trip', 'ابدأ الرحلة').of(context)),
          ),
        ];
      case TripStatus.starting:
        return [
          FilledButton.icon(
            onPressed: () => bloc.add(
              TripStartRequested(
                schoolId: schoolId,
                tripId: trip.id,
                routeId: trip.routeId,
                alreadyStarting: true,
              ),
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              const S('Continue starting', 'كمّل البدء').of(context),
            ),
          ),
        ];
      case TripStatus.active:
        return [
          OutlinedButton.icon(
            onPressed: () => bloc.add(
              TripPauseRequested(schoolId: schoolId, tripId: trip.id),
            ),
            icon: const Icon(Icons.pause),
            label: Text(const S('Pause', 'وقف مؤقت').of(context)),
          ),
          FilledButton.icon(
            onPressed: () => bloc.add(
              TripCompleteRequested(schoolId: schoolId, tripId: trip.id),
            ),
            icon: const Icon(Icons.check),
            label: Text(const S('Complete', 'إنهاء').of(context)),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            onPressed: () => _reportEmergency(context, bloc: bloc, schoolId: schoolId, tripId: trip.id),
            icon: const Icon(Icons.warning_amber_rounded),
            label: Text(const S('Emergency', 'طوارئ').of(context)),
          ),
        ];
      case TripStatus.paused:
        return [
          FilledButton.icon(
            onPressed: () => bloc.add(
              TripResumeRequested(schoolId: schoolId, tripId: trip.id),
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(const S('Resume', 'استكمال').of(context)),
          ),
          OutlinedButton.icon(
            onPressed: () => bloc.add(
              TripCancelRequested(schoolId: schoolId, tripId: trip.id),
            ),
            icon: const Icon(Icons.close),
            label: Text(const S('Cancel', 'إلغاء').of(context)),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            onPressed: () => _reportEmergency(context, bloc: bloc, schoolId: schoolId, tripId: trip.id),
            icon: const Icon(Icons.warning_amber_rounded),
            label: Text(const S('Emergency', 'طوارئ').of(context)),
          ),
        ];
      case TripStatus.emergency:
        return [
          FilledButton.icon(
            onPressed: () => bloc.add(
              TripCompleteRequested(schoolId: schoolId, tripId: trip.id),
            ),
            icon: const Icon(Icons.check),
            label: Text(const S('Complete', 'إنهاء').of(context)),
          ),
          OutlinedButton.icon(
            onPressed: () => bloc.add(
              TripCancelRequested(schoolId: schoolId, tripId: trip.id),
            ),
            icon: const Icon(Icons.close),
            label: Text(const S('Cancel', 'إلغاء').of(context)),
          ),
        ];
      case TripStatus.completed:
      case TripStatus.cancelled:
        return const [];
    }
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
/// anything — the only new UI this phase adds, since without it there's no
/// way to supply a valid `EmergencyType`.
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
    return AlertDialog(
      title: Text(const S('Report emergency', 'الإبلاغ عن حالة طوارئ').of(context)),
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
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: const S('Notes (optional)', 'ملاحظات (اختياري)').of(context),
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
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: EmergenciesRepository().watchActiveEmergency(
        schoolId: schoolId,
        tripId: tripId,
      ),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final emergency = SchoolEmergency.fromMap(docs.first.id, docs.first.data());

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(_emergencyTypeLabel(emergency.type, context)),
              subtitle: emergency.driverNote == null
                  ? null
                  : Text(emergency.driverNote!),
              trailing: OutlinedButton(
                onPressed: () => context.read<TripsBloc>().add(
                  TripEmergencyResolveRequested(
                    schoolId: schoolId,
                    tripId: tripId,
                    emergencyId: emergency.id,
                  ),
                ),
                child: Text(const S('Mark resolved', 'تم الحل').of(context)),
              ),
            ),
          ),
        );
      },
    );
  }
}
