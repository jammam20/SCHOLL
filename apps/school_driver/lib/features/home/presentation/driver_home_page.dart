import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
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
import '../../trips/data/trips_repository.dart';
import '../../trips/presentation/bloc/trips_bloc.dart';
import 'trip_detail_page.dart';

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

/// A clean, organized list of every trip — one compact card each, sorted
/// so the trip that actually needs the driver's attention right now sorts
/// first (Feature: driver app reorganization). Tapping any card opens its
/// full workspace ([TripDetailPage]): the map, the action, the students —
/// nothing else competes with them on that screen, which is exactly what
/// this list stays deliberately light in order to make room for.
class _TripsTab extends StatelessWidget {
  const _TripsTab({required this.user});

  final AppUser user;

  /// Whatever the driver is most likely to need to act on next, first:
  /// a live/urgent trip (emergency, then active/starting/paused) beats a
  /// merely scheduled one, which beats anything already finished. Ties
  /// keep Firestore's own order (soonest-scheduled first, in practice).
  int _priority(TripStatus status) => switch (status) {
    TripStatus.emergency => 0,
    TripStatus.active => 1,
    TripStatus.starting => 1,
    TripStatus.paused => 1,
    TripStatus.scheduled => 2,
    TripStatus.completed => 3,
    TripStatus.cancelled => 3,
  };

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
        // The one-tap SOS floats above the whole trip list rather than
        // living inside a card, so it stays reachable no matter how far the
        // driver has scrolled — the single control the spec calls for being
        // "always visible while a trip is running".
        floatingActionButton: BlocBuilder<TripsBloc, TripsState>(
          builder: (context, state) {
            final trip = _sosTargetTrip(state);
            if (trip == null) return const SizedBox.shrink();
            return _SosButton(schoolId: user.schoolId, tripId: trip.id);
          },
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
              final trips = (snapshot?.docs ?? const [])
                  .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => _priority(a.status).compareTo(_priority(b.status)));

              if (trips.isEmpty) {
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
                  itemCount: trips.length,
                  itemBuilder: (_, index) =>
                      _TripCard(schoolId: user.schoolId, trip: trips[index]),
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

/// The trip a one-tap SOS would be raised against: a trip that's currently
/// running (`active`) or temporarily stopped (`paused`) — exactly the two
/// statuses `TripStatus.canTransitionTo(emergency)` allows, so the button
/// is never offered when raising one would be rejected. A trip already in
/// `emergency` is excluded too: its card already carries the resolve
/// banner, and a second SOS on it would be refused by
/// EmergenciesRepository as a duplicate.
SchoolTrip? _sosTargetTrip(TripsState state) {
  if (state is! TripsLoaded) return null;
  for (final doc in state.snapshot.docs) {
    final trip = SchoolTrip.fromMap(doc.id, doc.data());
    if (trip.status == TripStatus.active || trip.status == TripStatus.paused) {
      return trip;
    }
  }
  return null;
}

/// A true one-tap SOS: no type, no notes, no form — a driver in a real
/// emergency should not be filling in a dropdown. The accidental-activation
/// guard is a press-and-hold rather than a confirmation dialog, because a
/// dialog is another thing to read and dismiss at the worst possible moment;
/// a plain tap explains the gesture instead of doing nothing silently.
///
/// This raises the *same* [TripEmergencyRequested] event the existing
/// type+notes dialog does — both paths end at
/// EmergenciesRepository.createEmergency, so there is one emergency-raising
/// code path in this app, not two.
class _SosButton extends StatelessWidget {
  const _SosButton({required this.schoolId, required this.tripId});

  final String schoolId;
  final String tripId;

  void _raise(BuildContext context) {
    HapticFeedback.heavyImpact();
    context.read<TripsBloc>().add(
      TripEmergencyRequested(
        schoolId: schoolId,
        tripId: tripId,
        emergencyType: EmergencyType.other,
      ),
    );
    AppSnackbar.error(
      context,
      const S(
        'SOS sent. Your school has been alerted.',
        'تم إرسال نداء الطوارئ. تم تنبيه مدرستك.',
      ).of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: const S(
        'SOS. Press and hold to raise an emergency.',
        'نداء طوارئ. اضغط مطولاً للإبلاغ عن حالة طوارئ.',
      ).of(context),
      child: Material(
        color: colors.emergency,
        shape: const StadiumBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onLongPress: () => _raise(context),
          onTap: () => AppSnackbar.info(
            context,
            const S(
              'Press and hold SOS to raise an emergency.',
              'اضغط مطولاً على زر الطوارئ للإبلاغ.',
            ).of(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sos_rounded, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  const S('Hold for SOS', 'اضغط مطولاً للطوارئ').of(context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One trip, compactly — route, direction, status, bus, time, and (for a
/// live one) a one-line emergency note if it has one. No map, no
/// buttons, no student list: this card's only job is "which trip is
/// this, and does it need me" — tapping it is the one action, opening the
/// full [TripDetailPage] for everything else. This is the entire fix for
/// the old screen's own clutter: every trip used to carry its map and
/// full timeline inline, so a driver with more than one trip scrolled
/// through several of both at once.
class _TripCard extends StatelessWidget {
  const _TripCard({required this.schoolId, required this.trip});

  final String schoolId;
  final SchoolTrip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isEmergency = trip.status == TripStatus.emergency;
    final isLive = trip.status == TripStatus.active ||
        trip.status == TripStatus.starting ||
        trip.status == TripStatus.paused ||
        isEmergency;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: isEmergency
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: colors.emergency, width: 2),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // TripDetailPage is reached via Navigator.push, which puts it on a
        // brand-new route — outside the BlocProvider<TripsBloc> that only
        // wraps _TripsTab's own Scaffold. Grabbing the bloc here (still
        // inside that scope) and re-providing the exact same instance to
        // the pushed route is what lets the detail page's action buttons
        // dispatch to it; without this, every one of them throws
        // ProviderNotFoundException the moment the page opens.
        onTap: () {
          final bloc = context.read<TripsBloc>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: TripDetailPage(schoolId: schoolId, trip: trip),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: toneColor(colors, tripStatusTone(trip.status)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isEmergency ? Icons.warning_amber_rounded : Icons.directions_bus_rounded,
                  color: toneColor(colors, tripStatusTone(trip.status)),
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
                                ? S('Route ${trip.routeId}', 'خط سير ${trip.routeId}')
                                      .of(context)
                                : trip.routeName,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge(
                          label: tripStatusLabel(trip.status, context),
                          tone: tripStatusTone(trip.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.direction == TripDirection.returnTrip
                          ? const S('← Return home', '← رجوع للمنزل').of(context)
                          : const S('→ To school', '→ للمدرسة').of(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        isLive
                            ? DateFormat.jm().format(trip.scheduledAt)
                            : DateFormat.yMMMd().add_jm().format(trip.scheduledAt),
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
