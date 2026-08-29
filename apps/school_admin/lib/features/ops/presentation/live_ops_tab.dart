import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/analytics.dart';
import '../../common/presentation/domain_labels.dart';
import '../../deviations/data/deviations_repository.dart';
import '../../emergencies/data/emergencies_repository.dart';
import '../../incidents/data/incidents_repository.dart';
import '../../incidents/presentation/incidents_page.dart';
import '../../schools/data/schools_repository.dart';
import '../../students/data/students_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../data/ops_tracking_repository.dart';
import '../domain/trip_path.dart';
import 'stop_marker_factory.dart';

/// The fleet-operations control centre: every bus on the road on one map,
/// drawn against the expected path each trip is actually being measured
/// against, with per-bus ETA, live route-deviation flags, incident pins
/// and an unmissable emergency banner.
///
/// Layout is desktop-first — the map sits beside a full-height operations
/// rail on a wide viewport, and the rail moves below the map on a narrow
/// one, rather than the rail's content being hidden on small screens.
class LiveOpsTab extends StatefulWidget {
  const LiveOpsTab({
    super.key,
    required this.schoolId,
    this.readOnly = false,
  });

  final String schoolId;

  /// Staff (read-only role) see the identical map and panels with no
  /// resolve action on emergencies.
  final bool readOnly;

  @override
  State<LiveOpsTab> createState() => _LiveOpsTabState();
}

/// One live GPS fix for a trip, straight off RTDB.
class _BusFix {
  const _BusFix({
    required this.position,
    this.speedMetersPerSecond,
    this.updatedAt,
  });

  final LatLng position;
  final double? speedMetersPerSecond;
  final DateTime? updatedAt;
}

/// A trip plus the fields the map needs that [SchoolTrip] doesn't model
/// (`stopOrder`, `boardedStudents`, `droppedOffStudents` live on the trip
/// document but aren't part of the shared model, which stays focused on
/// what all four apps need).
class _LiveTrip {
  const _LiveTrip({
    required this.trip,
    required this.stopOrder,
    required this.boardedStudents,
    required this.droppedOffStudents,
  });

  factory _LiveTrip.fromDoc(String id, Map<String, dynamic> data) {
    return _LiveTrip(
      trip: SchoolTrip.fromMap(id, data),
      stopOrder: List<String>.from(data['stopOrder'] as List? ?? const []),
      boardedStudents: List<String>.from(
        data['boardedStudents'] as List? ?? const [],
      ),
      droppedOffStudents: List<String>.from(
        data['droppedOffStudents'] as List? ?? const [],
      ),
    );
  }

  final SchoolTrip trip;
  final List<String> stopOrder;
  final List<String> boardedStudents;
  final List<String> droppedOffStudents;

  bool get isOnRoad =>
      trip.status == TripStatus.active ||
      trip.status == TripStatus.starting ||
      trip.status == TripStatus.paused ||
      trip.status == TripStatus.emergency;
}

class _LiveOpsTabState extends State<LiveOpsTab> {
  static const _fallbackCenter = LatLng(30.0444, 31.2357);

  final Map<String, _BusFix> _fixes = {};
  final Map<String, DeviationRecord> _deviations = {};

  GoogleMapController? _mapController;

  // Filters
  String? _routeFilter;
  bool _showCompleted = false;
  String? _focusedTripId;
  bool _legendOpen = true;

  void _updateFix(String tripId, _BusFix? fix) {
    if (!mounted) return;
    setState(() {
      if (fix == null) {
        _fixes.remove(tripId);
      } else {
        _fixes[tripId] = fix;
      }
    });
  }

  void _updateDeviation(String tripId, DeviationRecord? record) {
    if (!mounted) return;
    setState(() {
      // Only genuinely-ongoing episodes are tracked; a `normal` or
      // already-ended record is not a live deviation and must not keep the
      // bus flagged on the map.
      if (record == null || !record.isOngoing) {
        _deviations.remove(tripId);
      } else {
        _deviations[tripId] = record;
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Fits the camera to every currently-broadcasting bus. The map never
  /// auto-recenters after its initial load (buses drift out of view as a
  /// trip progresses), so this gives the admin an explicit way to snap
  /// back to "see everything".
  void _fitAllBuses() {
    final controller = _mapController;
    if (controller == null || _fixes.isEmpty) return;

    final points = _fixes.values.map((fix) => fix.position).toList();
    _fitPoints(controller, points);
  }

  void _fitPoints(GoogleMapController controller, List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }

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

  void _focusTrip(String tripId) {
    setState(() => _focusedTripId = _focusedTripId == tripId ? null : tripId);
    final controller = _mapController;
    final fix = _fixes[tripId];
    if (controller != null && fix != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(fix.position, 15));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchTrips(widget.schoolId),
      builder: (context, tripsSnapshot) {
        if (tripsSnapshot.hasError) {
          return ErrorStateView(onRetry: () => setState(() {}));
        }
        if (!tripsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: StudentsRepository().watchStudents(
            widget.schoolId,
            limit: 300,
          ),
          builder: (context, studentsSnapshot) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: SchoolsRepository().watchSchool(widget.schoolId),
              builder: (context, schoolSnapshot) {
                final allTrips = (tripsSnapshot.data?.docs ?? const [])
                    .map((doc) => _LiveTrip.fromDoc(doc.id, doc.data()))
                    .toList();

                // Trips whose location must be subscribed to: the ones
                // actually on the road. A completed trip has no live
                // position, so showing it never means subscribing to one.
                final onRoad = allTrips.where((t) => t.isOnRoad).toList();

                final completedToday = allTrips.where((t) {
                  if (t.trip.status != TripStatus.completed) return false;
                  final completedAt = t.trip.completedAt;
                  if (completedAt == null) return false;
                  final now = DateTime.now();
                  return completedAt.year == now.year &&
                      completedAt.month == now.month &&
                      completedAt.day == now.day;
                }).toList();

                final routeOptions = {
                  for (final trip in [...onRoad, ...completedToday])
                    trip.trip.routeId: trip.trip.routeName.isEmpty
                        ? trip.trip.routeId
                        : trip.trip.routeName,
                };

                bool matchesRoute(_LiveTrip trip) =>
                    _routeFilter == null || trip.trip.routeId == _routeFilter;

                final visibleOnRoad = onRoad.where(matchesRoute).toList();
                final visibleCompleted = _showCompleted
                    ? completedToday.where(matchesRoute).toList()
                    : <_LiveTrip>[];

                final students = <String, Student>{
                  for (final doc in studentsSnapshot.data?.docs ?? const [])
                    doc.id: Student.fromMap(doc.id, doc.data()),
                };
                final schoolData = schoolSnapshot.data?.data();
                final schoolLatitude = (schoolData?['latitude'] as num?)
                    ?.toDouble();
                final schoolLongitude = (schoolData?['longitude'] as num?)
                    ?.toDouble();
                final schoolName = schoolData?['name']?.toString() ?? '';

                // Expected path per visible trip, built exactly the way the
                // server-side deviation engine builds it.
                final paths = <String, List<TripPathStop>>{
                  for (final trip in [...visibleOnRoad, ...visibleCompleted])
                    trip.trip.id: buildTripPath(
                      stopOrder: trip.stopOrder,
                      studentsById: students,
                      boardedStudentIds: trip.boardedStudents,
                      droppedOffStudentIds: trip.droppedOffStudents,
                      schoolLatitude: schoolLatitude,
                      schoolLongitude: schoolLongitude,
                      schoolLabel: schoolName,
                    ),
                };

                final etas = <String, TripEta>{
                  for (final trip in visibleOnRoad)
                    trip.trip.id: computeTripEta(
                      tripStatus: trip.trip.status,
                      stopOrder: toEtaStopPoints(paths[trip.trip.id] ?? const []),
                      busLatitude: _fixes[trip.trip.id]?.position.latitude,
                      busLongitude: _fixes[trip.trip.id]?.position.longitude,
                      busSpeedMetersPerSecond:
                          _fixes[trip.trip.id]?.speedMetersPerSecond,
                      busPositionUpdatedAt: _fixes[trip.trip.id]?.updatedAt,
                    ),
                };

                return _LiveOpsScaffold(
                  schoolId: widget.schoolId,
                  readOnly: widget.readOnly,
                  onRoad: onRoad,
                  visibleOnRoad: visibleOnRoad,
                  visibleCompleted: visibleCompleted,
                  paths: paths,
                  etas: etas,
                  fixes: _fixes,
                  deviations: _deviations,
                  routeOptions: routeOptions,
                  routeFilter: _routeFilter,
                  showCompleted: _showCompleted,
                  focusedTripId: _focusedTripId,
                  legendOpen: _legendOpen,
                  onRouteFilterChanged: (value) =>
                      setState(() => _routeFilter = value),
                  onShowCompletedChanged: (value) =>
                      setState(() => _showCompleted = value),
                  onToggleLegend: () =>
                      setState(() => _legendOpen = !_legendOpen),
                  onFocusTrip: _focusTrip,
                  onMapCreated: _onMapCreated,
                  onFitAll: _fixes.isEmpty ? null : _fitAllBuses,
                  fallbackCenter: _fallbackCenter,
                  onPosition: _updateFix,
                  onDeviation: _updateDeviation,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Everything the map/rail needs, assembled once by the state above.
class _LiveOpsScaffold extends StatelessWidget {
  const _LiveOpsScaffold({
    required this.schoolId,
    required this.readOnly,
    required this.onRoad,
    required this.visibleOnRoad,
    required this.visibleCompleted,
    required this.paths,
    required this.etas,
    required this.fixes,
    required this.deviations,
    required this.routeOptions,
    required this.routeFilter,
    required this.showCompleted,
    required this.focusedTripId,
    required this.legendOpen,
    required this.onRouteFilterChanged,
    required this.onShowCompletedChanged,
    required this.onToggleLegend,
    required this.onFocusTrip,
    required this.onMapCreated,
    required this.onFitAll,
    required this.fallbackCenter,
    required this.onPosition,
    required this.onDeviation,
  });

  final String schoolId;
  final bool readOnly;
  final List<_LiveTrip> onRoad;
  final List<_LiveTrip> visibleOnRoad;
  final List<_LiveTrip> visibleCompleted;
  final Map<String, List<TripPathStop>> paths;
  final Map<String, TripEta> etas;
  final Map<String, _BusFix> fixes;
  final Map<String, DeviationRecord> deviations;
  final Map<String, String> routeOptions;
  final String? routeFilter;
  final bool showCompleted;
  final String? focusedTripId;
  final bool legendOpen;
  final ValueChanged<String?> onRouteFilterChanged;
  final ValueChanged<bool> onShowCompletedChanged;
  final VoidCallback onToggleLegend;
  final ValueChanged<String> onFocusTrip;
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback? onFitAll;
  final LatLng fallbackCenter;
  final void Function(String tripId, _BusFix? fix) onPosition;
  final void Function(String tripId, DeviationRecord? record) onDeviation;

  @override
  Widget build(BuildContext context) {
    final map = _OpsMap(
      schoolId: schoolId,
      visibleOnRoad: visibleOnRoad,
      visibleCompleted: visibleCompleted,
      paths: paths,
      etas: etas,
      fixes: fixes,
      deviations: deviations,
      focusedTripId: focusedTripId,
      legendOpen: legendOpen,
      routeOptions: routeOptions,
      routeFilter: routeFilter,
      showCompleted: showCompleted,
      onRouteFilterChanged: onRouteFilterChanged,
      onShowCompletedChanged: onShowCompletedChanged,
      onToggleLegend: onToggleLegend,
      onMapCreated: onMapCreated,
      onFitAll: onFitAll,
      fallbackCenter: fallbackCenter,
      broadcasting: fixes.length,
      total: onRoad.length,
    );

    final rail = _OpsRail(
      schoolId: schoolId,
      readOnly: readOnly,
      trips: visibleOnRoad,
      etas: etas,
      fixes: fixes,
      deviations: deviations,
      paths: paths,
      focusedTripId: focusedTripId,
      onFocusTrip: onFocusTrip,
    );

    return Column(
      children: [
        // The emergency banner sits above *everything*, full width, so an
        // admin glancing at the dashboard cannot miss an active SOS even
        // if the map is scrolled or the rail is collapsed.
        _EmergencyTopBanner(schoolId: schoolId),
        Expanded(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1000) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: map),
                        SizedBox(width: 380, child: rail),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(flex: 3, child: map),
                      Expanded(flex: 2, child: rail),
                    ],
                  );
                },
              ),
              // Invisible: each subscriber feeds one shared marker set, so
              // N independent live streams can drive one map.
              for (final trip in onRoad) ...[
                _TripLocationSubscriber(
                  key: ValueKey('loc-${trip.trip.id}'),
                  schoolId: schoolId,
                  tripId: trip.trip.id,
                  onPosition: (fix) => onPosition(trip.trip.id, fix),
                ),
                _TripDeviationSubscriber(
                  key: ValueKey('dev-${trip.trip.id}'),
                  schoolId: schoolId,
                  tripId: trip.trip.id,
                  onDeviation: (record) => onDeviation(trip.trip.id, record),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Map
// ---------------------------------------------------------------------------

/// Colours for each thing the map draws. Kept as one function so the map
/// and its legend can never disagree about what a colour means.
class _MapPalette {
  const _MapPalette(this.colors);
  final AppColorTokens colors;

  Color get expectedPath => colors.info;
  Color get deviationLink => colors.warning;
  Color get completedPath => colors.textMuted;
  Color get pendingStop => colors.textMuted;
  Color get boardedStop => colors.success;
  Color get droppedStop => colors.info;
  Color get schoolStop => colors.textPrimary;
}

class _OpsMap extends StatefulWidget {
  const _OpsMap({
    required this.schoolId,
    required this.visibleOnRoad,
    required this.visibleCompleted,
    required this.paths,
    required this.etas,
    required this.fixes,
    required this.deviations,
    required this.focusedTripId,
    required this.legendOpen,
    required this.routeOptions,
    required this.routeFilter,
    required this.showCompleted,
    required this.onRouteFilterChanged,
    required this.onShowCompletedChanged,
    required this.onToggleLegend,
    required this.onMapCreated,
    required this.onFitAll,
    required this.fallbackCenter,
    required this.broadcasting,
    required this.total,
  });

  final String schoolId;
  final List<_LiveTrip> visibleOnRoad;
  final List<_LiveTrip> visibleCompleted;
  final Map<String, List<TripPathStop>> paths;
  final Map<String, TripEta> etas;
  final Map<String, _BusFix> fixes;
  final Map<String, DeviationRecord> deviations;
  final String? focusedTripId;
  final bool legendOpen;
  final Map<String, String> routeOptions;
  final String? routeFilter;
  final bool showCompleted;
  final ValueChanged<String?> onRouteFilterChanged;
  final ValueChanged<bool> onShowCompletedChanged;
  final VoidCallback onToggleLegend;
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback? onFitAll;
  final LatLng fallbackCenter;
  final int broadcasting;
  final int total;

  @override
  State<_OpsMap> createState() => _OpsMapState();
}

class _OpsMapState extends State<_OpsMap> {
  /// Bumped whenever a batch of numbered stop pins finishes rendering, to
  /// force one repaint that picks them up out of the cache.
  int _markerGeneration = 0;

  /// Renders any stop pin this frame needed but didn't have cached yet,
  /// then triggers a single repaint. Called from build; the cache check
  /// makes repeat calls cheap and the early return stops it looping.
  Future<void> _prepareMarkers(
    List<TripPathStop> stops,
    _MapPalette palette,
    double ratio,
  ) async {
    var rendered = false;
    for (final stop in stops) {
      final color = _stopColor(stop, palette);
      if (StopMarkerFactory.cached(
            number: stop.sequence,
            progress: stop.progress,
            color: color,
            devicePixelRatio: ratio,
          ) !=
          null) {
        continue;
      }
      await StopMarkerFactory.prepare(
        number: stop.sequence,
        progress: stop.progress,
        color: color,
        devicePixelRatio: ratio,
      );
      rendered = true;
    }
    if (rendered && mounted) {
      setState(() => _markerGeneration++);
    }
  }

  Color _stopColor(TripPathStop stop, _MapPalette palette) =>
      switch (stop.progress) {
        TripStopProgress.school => palette.schoolStop,
        TripStopProgress.boarded => palette.boardedStop,
        TripStopProgress.droppedOff => palette.droppedStop,
        TripStopProgress.pending => palette.pendingStop,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = _MapPalette(colors);
    final ratio = MediaQuery.of(context).devicePixelRatio;

    final focused = widget.focusedTripId;
    // When one trip is focused, only its path is drawn — otherwise a busy
    // fleet turns the map into spaghetti.
    final pathTrips = [
      ...widget.visibleOnRoad,
      ...widget.visibleCompleted,
    ].where((trip) => focused == null || trip.trip.id == focused).toList();

    final allStops = [
      for (final trip in pathTrips) ...?widget.paths[trip.trip.id],
    ];
    // Fire-and-forget: renders anything missing, then repaints once.
    unawaitedPrepare(() => _prepareMarkers(allStops, palette, ratio));

    final markers = <Marker>{};
    final polylines = <Polyline>{};

    for (final trip in pathTrips) {
      final path = widget.paths[trip.trip.id] ?? const [];
      if (path.length >= 2) {
        final isCompleted = trip.trip.status == TripStatus.completed;
        polylines.add(
          Polyline(
            polylineId: PolylineId('path-${trip.trip.id}'),
            points: [
              for (final stop in path) LatLng(stop.latitude, stop.longitude),
            ],
            color: isCompleted
                ? palette.completedPath.withValues(alpha: 0.55)
                : palette.expectedPath.withValues(alpha: 0.85),
            width: isCompleted ? 3 : 5,
            patterns: isCompleted
                ? [PatternItem.dash(18), PatternItem.gap(12)]
                : const [],
          ),
        );
      }

      for (final stop in path) {
        final icon = StopMarkerFactory.cached(
          number: stop.sequence,
          progress: stop.progress,
          color: _stopColor(stop, palette),
          devicePixelRatio: ratio,
        );
        markers.add(
          Marker(
            markerId: MarkerId('stop-${trip.trip.id}-${stop.stopId}'),
            position: LatLng(stop.latitude, stop.longitude),
            icon: icon ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 1,
            infoWindow: InfoWindow(
              title: '${stop.sequence}. ${stop.label}',
              snippet: _stopStateLabel(stop.progress, context),
            ),
          ),
        );
      }
    }

    // Bus markers last, so they sit above stop pins.
    for (final trip in widget.visibleOnRoad) {
      final fix = widget.fixes[trip.trip.id];
      if (fix == null) continue;

      final deviation = widget.deviations[trip.trip.id];
      final isEmergency = trip.trip.status == TripStatus.emergency;
      final eta = widget.etas[trip.trip.id];

      markers.add(
        Marker(
          markerId: MarkerId('bus-${trip.trip.id}'),
          position: fix.position,
          zIndexInt: 2,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isEmergency
                ? BitmapDescriptor.hueRed
                : deviation != null
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: trip.trip.routeName.isEmpty
                ? trip.trip.busName
                : '${trip.trip.routeName} · ${trip.trip.busName}',
            snippet: _busSnippet(context, trip, eta, deviation),
          ),
        ),
      );

      // The "how far off route" connector: a dashed line from the bus to
      // the nearest point on its own expected path.
      if (deviation != null) {
        final path = widget.paths[trip.trip.id] ?? const [];
        final nearest = closestPointOnPath(
          latitude: fix.position.latitude,
          longitude: fix.position.longitude,
          path: path,
        );
        if (nearest != null) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('deviation-${trip.trip.id}'),
              points: [
                fix.position,
                LatLng(nearest.latitude, nearest.longitude),
              ],
              color: palette.deviationLink,
              width: 4,
              patterns: [PatternItem.dash(14), PatternItem.gap(10)],
            ),
          );
        }
      }
    }

    final center = widget.fixes.values.isNotEmpty
        ? widget.fixes.values.first.position
        : widget.fallbackCenter;

    return Stack(
      children: [
        GoogleMap(
          key: ValueKey('ops-map-$_markerGeneration'),
          onMapCreated: widget.onMapCreated,
          initialCameraPosition: CameraPosition(target: center, zoom: 11),
          markers: markers,
          polylines: polylines,
          zoomControlsEnabled: false,
        ),
        // Incident pins are their own overlay so they keep updating from
        // their own stream without rebuilding the whole map body.
        _OpenIncidentsOverlay(schoolId: widget.schoolId),
        PositionedDirectional(
          start: AppSpacing.md,
          top: AppSpacing.md,
          child: _MapFiltersCard(
            broadcasting: widget.broadcasting,
            total: widget.total,
            routeOptions: widget.routeOptions,
            routeFilter: widget.routeFilter,
            showCompleted: widget.showCompleted,
            onRouteFilterChanged: widget.onRouteFilterChanged,
            onShowCompletedChanged: widget.onShowCompletedChanged,
          ),
        ),
        PositionedDirectional(
          end: AppSpacing.md,
          top: AppSpacing.md,
          child: _RecenterButton(onPressed: widget.onFitAll),
        ),
        PositionedDirectional(
          start: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _MapLegend(
            open: widget.legendOpen,
            onToggle: widget.onToggleLegend,
            palette: palette,
          ),
        ),
      ],
    );
  }

  String _busSnippet(
    BuildContext context,
    _LiveTrip trip,
    TripEta? eta,
    DeviationRecord? deviation,
  ) {
    final parts = <String>[trip.trip.busPlateNumber];

    if (deviation != null) {
      parts.add(
        S(
          'OFF ROUTE by ${deviation.currentDeviationMeters.round()} m',
          'خارج المسار بـ ${deviation.currentDeviationMeters.round()} متر',
        ).of(context),
      );
    }

    final etaLabel = formatEtaMinutes(eta?.etaToNextStop);
    if (etaLabel != null) {
      parts.add(S('Next stop $etaLabel', 'المحطة الجاية $etaLabel').of(context));
    } else if (eta?.unavailableReason != null) {
      parts.add(_etaUnavailableLabel(eta!.unavailableReason!, context));
    }

    return parts.where((part) => part.isNotEmpty).join(' · ');
  }
}

/// Runs a fire-and-forget async side effect from build without tripping
/// the `discarded_futures`/`unawaited_futures` lints, and without the
/// caller needing to import `dart:async` just for `unawaited`.
void unawaitedPrepare(Future<void> Function() action) {
  action();
}

String _stopStateLabel(TripStopProgress progress, BuildContext context) =>
    switch (progress) {
      TripStopProgress.pending =>
        const S('Not yet reached', 'لسه موصلش').of(context),
      TripStopProgress.boarded =>
        const S('Boarded', 'ركب').of(context),
      TripStopProgress.droppedOff =>
        const S('Dropped off', 'نزل').of(context),
      TripStopProgress.school =>
        const S('School', 'المدرسة').of(context),
    };

String _etaUnavailableLabel(
  EtaUnavailableReason reason,
  BuildContext context,
) => switch (reason) {
  EtaUnavailableReason.tripNotActive =>
    const S('Trip not moving yet', 'الرحلة لسه مبدأتش').of(context),
  EtaUnavailableReason.noGpsSignal =>
    const S('No GPS signal', 'مفيش إشارة GPS').of(context),
  EtaUnavailableReason.staleGps =>
    const S('GPS out of date', 'إشارة GPS قديمة').of(context),
  EtaUnavailableReason.allStopsCompleted =>
    const S('All stops done', 'كل المحطات خلصت').of(context),
  EtaUnavailableReason.noRemainingStops =>
    const S('No stop order set', 'مفيش ترتيب محطات').of(context),
};

/// "N of M broadcasting", plus the map's own filters. A genuinely floating
/// surface over the map, so it gets an explicit elevation shadow rather
/// than the flat border-forward treatment ordinary cards use.
class _MapFiltersCard extends StatelessWidget {
  const _MapFiltersCard({
    required this.broadcasting,
    required this.total,
    required this.routeOptions,
    required this.routeFilter,
    required this.showCompleted,
    required this.onRouteFilterChanged,
    required this.onShowCompletedChanged,
  });

  final int broadcasting;
  final int total;
  final Map<String, String> routeOptions;
  final String? routeFilter;
  final bool showCompleted;
  final ValueChanged<String?> onRouteFilterChanged;
  final ValueChanged<bool> onShowCompletedChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.level1(colors.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_bus_filled_rounded,
                size: 18,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
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
              ),
            ],
          ),
          if (routeOptions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: routeFilter,
              isDense: true,
              decoration: InputDecoration(
                isDense: true,
                labelText: const S('Route', 'الخط').of(context),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    const S('All routes', 'كل الخطوط').of(context),
                  ),
                ),
                for (final entry in routeOptions.entries)
                  DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
              ],
              onChanged: onRouteFilterChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  const S(
                    "Show today's completed",
                    'إظهار المكتملة النهارده',
                  ).of(context),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Switch(value: showCompleted, onChanged: onShowCompletedChanged),
            ],
          ),
        ],
      ),
    );
  }
}

/// A floating "fit all buses" control. Disabled (not hidden) when nothing
/// is broadcasting yet, per `design-system/MASTER.md` §9.
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

/// Explains every colour and marker state on the map. Collapsible, because
/// on a small viewport it would otherwise cover the very thing it explains.
class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.open,
    required this.onToggle,
    required this.palette,
  });

  final bool open;
  final VoidCallback onToggle;
  final _MapPalette palette;

  @override
  Widget build(BuildContext context) {
    final colors = palette.colors;
    final theme = Theme.of(context);

    if (!open) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.level1(colors.textPrimary),
        ),
        child: IconButton(
          tooltip: const S('Show legend', 'إظهار المفتاح').of(context),
          icon: const Icon(Icons.info_outline),
          onPressed: onToggle,
        ),
      );
    }

    Widget row(Color color, String label, {bool ring = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: ring ? Colors.transparent : color,
              border: Border.all(color: color, width: ring ? 3 : 1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: 230,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.level1(colors.textPrimary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  const S('Legend', 'مفتاح الخريطة').of(context),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              InkWell(
                onTap: onToggle,
                child: Icon(Icons.close, size: 16, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          row(
            colors.info,
            const S('Bus en route', 'أتوبيس في الطريق').of(context),
          ),
          row(
            colors.warning,
            const S('Bus off route', 'أتوبيس خارج المسار').of(context),
          ),
          row(
            colors.emergency,
            const S('Bus in emergency', 'أتوبيس في حالة طوارئ').of(context),
          ),
          const Divider(height: AppSpacing.lg),
          row(
            palette.pendingStop,
            const S('Stop pending', 'محطة لسه', ).of(context),
          ),
          row(
            palette.boardedStop,
            const S('Student boarded', 'الطالب ركب').of(context),
          ),
          row(
            palette.droppedStop,
            const S('Student dropped off', 'الطالب نزل').of(context),
            ring: true,
          ),
          const Divider(height: AppSpacing.lg),
          Text(
            const S(
              'Solid line: expected path. Dashed to a bus: how far it is '
                  'off that path.',
              'الخط المتصل: المسار المتوقع. الخط المتقطع للأتوبيس: بعده عن '
                  'المسار ده.',
            ).of(context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A floating counter of open incidents that carry coordinates, opening a
/// sheet that lists them and links each to its own map view.
///
/// Deliberately *not* extra pins in the map's own marker set: incidents
/// are reported at arbitrary points that would collide visually with the
/// numbered stop pins and bus markers this map exists to show. Keeping
/// them one tap away preserves the map's legibility while still surfacing
/// them here rather than only on the Incidents tab.
class _OpenIncidentsOverlay extends StatelessWidget {
  const _OpenIncidentsOverlay({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SchoolIncident>>(
      stream: IncidentsRepository().watchOpenIncidents(schoolId),
      builder: (context, snapshot) {
        final located = (snapshot.data ?? const [])
            .where((incident) => incident.hasLocation)
            .toList();
        if (located.isEmpty) return const SizedBox.shrink();

        return PositionedDirectional(
          end: AppSpacing.md,
          top: 64,
          child: _OpenIncidentsChip(incidents: located),
        );
      },
    );
  }
}

class _OpenIncidentsChip extends StatelessWidget {
  const _OpenIncidentsChip({required this.incidents});

  final List<SchoolIncident> incidents;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    const S(
                      'Open incidents with a location',
                      'بلاغات مفتوحة ليها مكان',
                    ).of(sheetContext),
                    style: Theme.of(sheetContext).textTheme.titleSmall,
                  ),
                ),
                for (final incident in incidents)
                  ListTile(
                    leading: Icon(
                      incidentTypeIcon(incident.type),
                      color: colors.warning,
                    ),
                    title: Text(incidentTypeLabel(incident.type, sheetContext)),
                    subtitle: Text(
                      DateFormat.yMMMd().add_jm().format(incident.createdAt),
                    ),
                    trailing: const Icon(Icons.map_outlined),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IncidentMapPage(incident: incident),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: colors.warning.withValues(alpha: 0.45)),
            boxShadow: AppShadows.level1(colors.textPrimary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.report_outlined, size: 16, color: colors.warning),
              const SizedBox(width: AppSpacing.xs),
              Text(
                S(
                  '${incidents.length} open incident(s)',
                  '${incidents.length} بلاغ مفتوح',
                ).of(context),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Operations rail
// ---------------------------------------------------------------------------

/// The buses / deviations / emergencies rail beside the map.
class _OpsRail extends StatelessWidget {
  const _OpsRail({
    required this.schoolId,
    required this.readOnly,
    required this.trips,
    required this.etas,
    required this.fixes,
    required this.deviations,
    required this.paths,
    required this.focusedTripId,
    required this.onFocusTrip,
  });

  final String schoolId;
  final bool readOnly;
  final List<_LiveTrip> trips;
  final Map<String, TripEta> etas;
  final Map<String, _BusFix> fixes;
  final Map<String, DeviationRecord> deviations;
  final Map<String, List<TripPathStop>> paths;
  final String? focusedTripId;
  final ValueChanged<String> onFocusTrip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: BorderDirectional(start: BorderSide(color: colors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ActiveEmergenciesPanel(schoolId: schoolId, readOnly: readOnly),
          _DeviationsPanel(
            trips: trips,
            deviations: deviations,
            onFocusTrip: onFocusTrip,
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              const S('Buses on the road', 'الأتوبيسات على الطريق')
                  .of(context)
                  .toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (trips.isEmpty)
            EmptyStateView(
              compact: true,
              icon: Icons.directions_bus_outlined,
              title: const S(
                'No trips on the road.',
                'مفيش رحلات على الطريق.',
              ).of(context),
            )
          else
            for (final trip in trips)
              _BusRailTile(
                key: ValueKey(trip.trip.id),
                trip: trip,
                eta: etas[trip.trip.id],
                fix: fixes[trip.trip.id],
                deviation: deviations[trip.trip.id],
                path: paths[trip.trip.id] ?? const [],
                focused: focusedTripId == trip.trip.id,
                onTap: () => onFocusTrip(trip.trip.id),
              ),
        ],
      ),
    );
  }
}

class _BusRailTile extends StatelessWidget {
  const _BusRailTile({
    super.key,
    required this.trip,
    required this.eta,
    required this.fix,
    required this.deviation,
    required this.path,
    required this.focused,
    required this.onTap,
  });

  final _LiveTrip trip;
  final TripEta? eta;
  final _BusFix? fix;
  final DeviationRecord? deviation;
  final List<TripPathStop> path;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isEmergency = trip.trip.status == TripStatus.emergency;

    final accent = isEmergency
        ? colors.emergency
        : deviation != null
        ? colors.warning
        : colors.info;

    final nextStop = eta?.nextStopId == null
        ? null
        : path.where((stop) => stop.stopId == eta!.nextStopId).firstOrNull;
    final etaLabel = formatEtaMinutes(eta?.etaToNextStop);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: focused
                ? accent
                : deviation != null || isEmergency
                ? accent.withValues(alpha: 0.45)
                : colors.border,
            width: focused ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, size: 18, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    trip.trip.routeName.isEmpty
                        ? trip.trip.busName
                        : trip.trip.routeName,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fix == null)
                  Tooltip(
                    message: const S(
                      'This bus is not broadcasting its location.',
                      'الأتوبيس ده مش بيبث موقعه.',
                    ).of(context),
                    child: Icon(
                      Icons.gps_off,
                      size: 16,
                      color: colors.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${trip.trip.busName} · ${trip.trip.busPlateNumber} · '
              '${trip.trip.driverName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (isEmergency)
                  StatusBadge(
                    label: const S('Emergency', 'حالة طوارئ').of(context),
                    tone: StatusTone.emergency,
                  ),
                if (deviation != null)
                  StatusBadge(
                    label: S(
                      'Off route ${deviation!.currentDeviationMeters.round()} m',
                      'خارج المسار ${deviation!.currentDeviationMeters.round()} م',
                    ).of(context),
                    tone: StatusTone.error,
                  ),
                if (etaLabel != null)
                  StatusBadge(
                    label: nextStop == null
                        ? S('Next stop $etaLabel', 'المحطة الجاية $etaLabel')
                              .of(context)
                        : S(
                            '${nextStop.label} · $etaLabel',
                            '${nextStop.label} · $etaLabel',
                          ).of(context),
                    tone: StatusTone.info,
                  )
                else if (eta?.unavailableReason != null)
                  StatusBadge(
                    label: _etaUnavailableLabel(
                      eta!.unavailableReason!,
                      context,
                    ),
                    tone: StatusTone.neutral,
                  ),
              ],
            ),
            if (eta != null && eta!.stopsRemaining > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: eta!.routeProgressFraction,
                  minHeight: 6,
                  backgroundColor: colors.border,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                S(
                  '${eta!.stopsCompleted} of '
                      '${eta!.stopsCompleted + eta!.stopsRemaining} stops done',
                  '${eta!.stopsCompleted} من '
                      '${eta!.stopsCompleted + eta!.stopsRemaining} محطة خلصت',
                ).of(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Buses currently off their expected path — the deviation counterpart to
/// the emergencies panel, sitting directly alongside it.
class _DeviationsPanel extends StatelessWidget {
  const _DeviationsPanel({
    required this.trips,
    required this.deviations,
    required this.onFocusTrip,
  });

  final List<_LiveTrip> trips;
  final Map<String, DeviationRecord> deviations;
  final ValueChanged<String> onFocusTrip;

  @override
  Widget build(BuildContext context) {
    final active = trips
        .where((trip) => deviations.containsKey(trip.trip.id))
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final colors = context.appColors;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.warning.withValues(alpha: 0.45)),
        boxShadow: AppShadows.level1(colors.textPrimary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Icon(Icons.alt_route, size: 18, color: colors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    S(
                      'Off route (${active.length})',
                      'خارج المسار (${active.length})',
                    ).of(context),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final trip in active)
            ListTile(
              dense: true,
              onTap: () => onFocusTrip(trip.trip.id),
              title: Text(
                trip.trip.routeName.isEmpty
                    ? trip.trip.busName
                    : trip.trip.routeName,
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                S(
                  '${trip.trip.busName} · '
                      '${deviations[trip.trip.id]!.currentDeviationMeters.round()} m '
                      'off path · since '
                      '${DateFormat.jm().format(deviations[trip.trip.id]!.startedAt)}',
                  '${trip.trip.busName} · '
                      '${deviations[trip.trip.id]!.currentDeviationMeters.round()} م '
                      'عن المسار · من '
                      '${DateFormat.jm().format(deviations[trip.trip.id]!.startedAt)}',
                ).of(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              trailing: Icon(
                Icons.my_location,
                size: 18,
                color: colors.textMuted,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emergencies (Feature: SOS prominence)
// ---------------------------------------------------------------------------

/// A full-width, impossible-to-miss banner shown whenever *any* emergency
/// is active anywhere in the school. This is deliberately additive: it
/// does not change how an emergency is raised or resolved (that logic is
/// untouched in EmergenciesRepository), only how loudly an active one
/// announces itself to an admin glancing at the dashboard.
class _EmergencyTopBanner extends StatelessWidget {
  const _EmergencyTopBanner({required this.schoolId});

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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          color: colors.emergency,
          child: Row(
            children: [
              const _PulsingDot(color: Colors.white),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  docs.length == 1
                      ? const S(
                          'EMERGENCY IN PROGRESS — a driver has raised an SOS.',
                          'حالة طوارئ جارية — سائق ضغط زر الاستغاثة.',
                        ).of(context)
                      : S(
                          '${docs.length} EMERGENCIES IN PROGRESS.',
                          '${docs.length} حالات طوارئ جارية.',
                        ).of(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A slowly pulsing dot. Respects `MediaQuery.disableAnimations` by
/// rendering a static dot instead, per `design-system/MASTER.md` §10/§12 —
/// urgency must never come at the cost of a reduce-motion setting.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;
  static const size = 12.0;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: _PulsingDot.size,
      height: _PulsingDot.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );

    if (MediaQuery.of(context).disableAnimations) return dot;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.35 + _controller.value * 0.65,
        child: Transform.scale(
          scale: 0.85 + _controller.value * 0.35,
          child: child,
        ),
      ),
      child: dot,
    );
  }
}

/// The school's currently-active emergencies with a resolve action.
///
/// Unchanged in what it does — same [EmergenciesRepository] stream, same
/// resolve call — but visually escalated: a pulsing indicator in the
/// header, and it now sits at the very top of the operations rail rather
/// than floating at the bottom of the map where it could be missed.
class _ActiveEmergenciesPanel extends StatelessWidget {
  const _ActiveEmergenciesPanel({
    required this.schoolId,
    this.readOnly = false,
  });

  final String schoolId;
  final bool readOnly;

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
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.emergency.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.emergency),
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
                    _PulsingDot(color: colors.emergency),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        S(
                          'Active emergencies (${docs.length})',
                          'حالات طوارئ نشطة (${docs.length})',
                        ).of(context),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.emergency,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: docs.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: AppSpacing.lg),
                itemBuilder: (_, index) {
                  final doc = docs[index];
                  final emergency = SchoolEmergency.fromMap(doc.id, doc.data());
                  return _EmergencyTile(
                    schoolId: schoolId,
                    emergency: emergency,
                    readOnly: readOnly,
                  );
                },
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
  const _EmergencyTile({
    required this.schoolId,
    required this.emergency,
    this.readOnly = false,
  });

  final String schoolId;
  final SchoolEmergency emergency;
  final bool readOnly;

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
                  label: emergencyTypeLabel(emergency.type, context),
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
          if (!widget.readOnly) ...[
            const SizedBox(width: AppSpacing.sm),
            AppButton.destructive(
              label: const S('Resolve', 'حل').of(context),
              loading: _resolving,
              onPressed: _resolving ? null : _resolve,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live subscribers
// ---------------------------------------------------------------------------

class _TripLocationSubscriber extends StatefulWidget {
  const _TripLocationSubscriber({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.onPosition,
  });

  final String schoolId;
  final String tripId;
  final ValueChanged<_BusFix?> onPosition;

  @override
  State<_TripLocationSubscriber> createState() =>
      _TripLocationSubscriberState();
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
        _BusFix? fix;
        if (raw is Map) {
          final data = Map<Object?, Object?>.from(raw);
          final latitude = (data['latitude'] as num?)?.toDouble();
          final longitude = (data['longitude'] as num?)?.toDouble();
          if (latitude != null && longitude != null) {
            final updatedAtMillis = (data['updatedAt'] as num?)?.toInt();
            fix = _BusFix(
              position: LatLng(latitude, longitude),
              speedMetersPerSecond: (data['speed'] as num?)?.toDouble(),
              updatedAt: updatedAtMillis == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
            );
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPosition(fix);
        });
        return const SizedBox.shrink();
      },
    );
  }
}

/// Watches one trip's live `deviation/current` document. Server-written
/// only — see [DeviationsRepository].
class _TripDeviationSubscriber extends StatefulWidget {
  const _TripDeviationSubscriber({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.onDeviation,
  });

  final String schoolId;
  final String tripId;
  final ValueChanged<DeviationRecord?> onDeviation;

  @override
  State<_TripDeviationSubscriber> createState() =>
      _TripDeviationSubscriberState();
}

class _TripDeviationSubscriberState extends State<_TripDeviationSubscriber> {
  @override
  void dispose() {
    widget.onDeviation(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviationRecord?>(
      stream: DeviationsRepository().watchLiveDeviation(
        schoolId: widget.schoolId,
        tripId: widget.tripId,
      ),
      builder: (context, snapshot) {
        final record = snapshot.data;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onDeviation(record);
        });
        return const SizedBox.shrink();
      },
    );
  }
}
