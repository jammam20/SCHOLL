import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/analytics.dart';
import '../../emergencies/data/emergencies_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../data/ops_tracking_repository.dart';

/// Every bus currently on the road, on one map — so the school can see at a
/// glance where all its trips are, not just one at a time.
class LiveOpsTab extends StatefulWidget {
  const LiveOpsTab({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<LiveOpsTab> createState() => _LiveOpsTabState();
}

class _LiveOpsTabState extends State<LiveOpsTab> {
  static const _fallbackCenter = LatLng(30.0444, 31.2357);

  final Map<String, LatLng> _positions = {};
  GoogleMapController? _mapController;

  void _updatePosition(String tripId, LatLng? position) {
    if (!mounted) return;
    setState(() {
      if (position == null) {
        _positions.remove(tripId);
      } else {
        _positions[tripId] = position;
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Fits the camera to every currently-broadcasting bus. The map never
  /// auto-recenters after its initial load (buses drift out of view as a
  /// trip progresses), so this gives the admin an explicit way to snap back
  /// to "see everything" — same bounds-fitting approach already used by the
  /// parent app's live trip map, just triggered by a button instead of a
  /// new-position callback.
  void _fitAllBuses() {
    final controller = _mapController;
    if (controller == null || _positions.isEmpty) return;

    if (_positions.length == 1) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_positions.values.first, 15),
      );
      return;
    }

    final points = _positions.values.toList();
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchTrips(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorStateView(onRetry: () => setState(() {}));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final trips = (snapshot.data?.docs ?? const [])
            .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
            .where(
              (trip) =>
                  trip.status == TripStatus.active ||
                  trip.status == TripStatus.starting ||
                  trip.status == TripStatus.paused ||
                  trip.status == TripStatus.emergency,
            )
            .toList();
        final tripsById = {for (final trip in trips) trip.id: trip};

        final center = _positions.values.isNotEmpty
            ? _positions.values.first
            : _fallbackCenter;

        return Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: center, zoom: 11),
              markers: {
                for (final entry in _positions.entries)
                  Marker(
                    markerId: MarkerId(entry.key),
                    position: entry.value,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      tripsById[entry.key]?.status == TripStatus.emergency
                          ? BitmapDescriptor.hueRed
                          : BitmapDescriptor.hueAzure,
                    ),
                    infoWindow: InfoWindow(
                      title: tripsById[entry.key]?.routeName ?? 'Trip',
                      snippet: tripsById[entry.key]?.busPlateNumber,
                    ),
                  ),
              },
              zoomControlsEnabled: false,
            ),
            // Invisible: each one just subscribes to its trip's RTDB
            // location and reports back via onPosition, so N independent
            // live streams can feed one shared marker set above.
            for (final trip in trips)
              _TripLocationSubscriber(
                key: ValueKey(trip.id),
                schoolId: widget.schoolId,
                tripId: trip.id,
                onPosition: (position) => _updatePosition(trip.id, position),
              ),
            PositionedDirectional(
              start: AppSpacing.md,
              top: AppSpacing.md,
              child: _BroadcastInfoCard(
                broadcasting: _positions.length,
                total: trips.length,
              ),
            ),
            PositionedDirectional(
              end: AppSpacing.md,
              top: AppSpacing.md,
              child: _RecenterButton(
                onPressed: _positions.isEmpty ? null : _fitAllBuses,
              ),
            ),
            PositionedDirectional(
              start: AppSpacing.md,
              end: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _ActiveEmergenciesPanel(schoolId: widget.schoolId),
            ),
          ],
        );
      },
    );
  }
}

/// The "N of M buses broadcasting" pill — a genuinely floating surface over
/// the map, so it gets an explicit elevation shadow rather than the flat
/// border-forward treatment ordinary cards use. See
/// `design-system/MASTER.md` §6.
class _BroadcastInfoCard extends StatelessWidget {
  const _BroadcastInfoCard({required this.broadcasting, required this.total});

  final int broadcasting;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.level1(colors.textPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_bus_filled_rounded,
            size: 18,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            total == 0
                ? const S(
                    'No trips on the road right now.',
                    'مفيش رحلات على الطريق دلوقتي.',
                  ).of(context)
                : S(
                    '$broadcasting of $total bus(es) broadcasting',
                    '$broadcasting من $total باص بيبث موقعه',
                  ).of(context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A floating "fit all buses" control — the map never auto-recenters once
/// buses drift, so this gives the admin an explicit way back to "see
/// everything." Disabled (not hidden) when nothing is broadcasting yet, per
/// `design-system/MASTER.md` §9 ("Disabled" — reduced opacity, not a color
/// swap alone).
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        boxShadow: AppShadows.level1(colors.textPrimary),
      ),
      child: IconButton(
        tooltip: const S('Fit all buses', 'عرض كل الباصات').of(context),
        icon: Icon(
          Icons.center_focus_strong_rounded,
          color: onPressed == null ? colors.disabled : colors.textPrimary,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

/// A minimal, functional list of the school's currently active emergencies
/// with a resolve action — the business/data layer this backs
/// (EmergenciesRepository) needs *some* surface for an admin to actually
/// see and act on it. Floats over the map like the info card above, so it
/// gets the same elevation treatment, one level heavier given its urgency.
class _ActiveEmergenciesPanel extends StatelessWidget {
  const _ActiveEmergenciesPanel({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: EmergenciesRepository().watchActiveEmergencies(schoolId),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final colors = context.appColors;
        final theme = Theme.of(context);

        return Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.emergency.withValues(alpha: 0.35)),
            boxShadow: AppShadows.level2(colors.textPrimary),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: colors.emergency,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        S(
                          'Active emergencies (${docs.length})',
                          'حالات طوارئ نشطة (${docs.length})',
                        ).of(context),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.emergency,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: AppSpacing.lg),
                  itemBuilder: (_, index) {
                    final doc = docs[index];
                    final emergency = SchoolEmergency.fromMap(doc.id, doc.data());
                    return _EmergencyTile(schoolId: schoolId, emergency: emergency);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

class _EmergencyTile extends StatefulWidget {
  const _EmergencyTile({required this.schoolId, required this.emergency});

  final String schoolId;
  final SchoolEmergency emergency;

  @override
  State<_EmergencyTile> createState() => _EmergencyTileState();
}

class _EmergencyTileState extends State<_EmergencyTile> {
  bool _resolving = false;

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    try {
      await EmergenciesRepository().resolveEmergency(
        schoolId: widget.schoolId,
        tripId: widget.emergency.tripId,
        emergencyId: widget.emergency.id,
      );
      await AppAnalytics.logEmergencyResolved(tripId: widget.emergency.tripId);
      if (!mounted) return;
      AppSnackbar.success(
        context,
        const S('Emergency resolved.', 'تم حل حالة الطوارئ.').of(context),
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergency = widget.emergency;
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(
                  label: _emergencyTypeLabel(emergency.type, context),
                  tone: StatusTone.emergency,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DateFormat.jm().format(emergency.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                if (emergency.driverNote != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    emergency.driverNote!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton.secondary(
            label: const S('Resolve', 'حل').of(context),
            loading: _resolving,
            onPressed: _resolving ? null : _resolve,
          ),
        ],
      ),
    );
  }
}

String _emergencyTypeLabel(EmergencyType type, BuildContext context) {
  switch (type) {
    case EmergencyType.accident:
      return const S('Accident', 'حادث').of(context);
    case EmergencyType.vehicleBreakdown:
      return const S('Vehicle breakdown', 'عطل في الباص').of(context);
    case EmergencyType.medical:
      return const S('Medical', 'حالة طبية').of(context);
    case EmergencyType.security:
      return const S('Security', 'أمنية').of(context);
    case EmergencyType.other:
      return const S('Other', 'أخرى').of(context);
  }
}

class _TripLocationSubscriber extends StatefulWidget {
  const _TripLocationSubscriber({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.onPosition,
  });

  final String schoolId;
  final String tripId;
  final ValueChanged<LatLng?> onPosition;

  @override
  State<_TripLocationSubscriber> createState() => _TripLocationSubscriberState();
}

class _TripLocationSubscriberState extends State<_TripLocationSubscriber> {
  @override
  void dispose() {
    widget.onPosition(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: OpsTrackingRepository().watchTripLocation(
        schoolId: widget.schoolId,
        tripId: widget.tripId,
      ),
      builder: (context, snapshot) {
        final raw = snapshot.data?.snapshot.value;
        LatLng? position;
        if (raw is Map) {
          final data = Map<Object?, Object?>.from(raw);
          final latitude = (data['latitude'] as num?)?.toDouble();
          final longitude = (data['longitude'] as num?)?.toDouble();
          if (latitude != null && longitude != null) {
            position = LatLng(latitude, longitude);
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPosition(position);
        });
        return const SizedBox.shrink();
      },
    );
  }
}
