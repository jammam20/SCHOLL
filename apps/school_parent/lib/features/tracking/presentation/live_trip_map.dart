import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/analytics.dart';
import '../../schools/data/schools_repository.dart';
import '../../trips/data/stop_order_repository.dart';
import '../../trips/domain/journey_stage.dart';
import '../data/deviation_repository.dart';
import '../data/parent_tracking_repository.dart';
import '../domain/live_bus_position.dart';
import '../domain/parent_trip_eta.dart';
import 'eta_text.dart';
import 'map_marker_icons.dart';

/// Live map of a trip in progress, personalized to one child.
///
/// The experience is layered: the map itself carries the geography (a
/// custom bus marker turned to the driver's real heading, this child's own
/// numbered stop, the school as the final stop, and a line joining the
/// stops in their true `stopOrder` sequence), while everything a parent has
/// to *read* floats above it — the status/ETA card at the bottom, the
/// deviation notice at the top, the camera controls to the side. That
/// keeps the map surface itself uncluttered at the size it actually gets on
/// a phone.
///
/// Deliberately shows only *this* child's pickup point: firestore.rules
/// only lets a parent read their own child's student document, so the other
/// children on the same bus are unreadable here even in principle — and
/// their home addresses shouldn't be on this screen anyway. Their stops
/// still count: "stop 3 of 8" comes from the real order, it's only their
/// coordinates that are (correctly) absent.
///
/// The line follows the real roads whenever the trip's own
/// `routePolyline` has been computed (Feature: real route lines — see
/// functions/src/index.ts: onTripStopOrderRouted), falling back to a
/// straight sequence between real stop coordinates only until that catches
/// up — never a decorative invented route shape either way.
class LiveTripMap extends StatefulWidget {
  const LiveTripMap({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.tripStatus,
    required this.student,
    this.height = 300,
    this.fillAvailableSpace = false,
    this.onOpenFullScreen,
  });

  final String schoolId;
  final String tripId;

  /// The ETA engine refuses to estimate for a trip that isn't running
  /// (returning [EtaUnavailableReason.tripNotActive] instead), so it needs
  /// the trip's own status — this map is also shown while a trip is
  /// starting, paused or in an emergency.
  final TripStatus tripStatus;

  final Student student;

  /// Height of the embedded map. Ignored when [fillAvailableSpace] is set.
  final double height;

  /// Fill the parent's constraints instead of using [height] — how
  /// [LiveTripMapPage] renders the same map full-screen.
  final bool fillAvailableSpace;

  /// Shown as an "expand" control on the map when non-null. Null on the
  /// full-screen page itself, where there is nothing left to expand into.
  final VoidCallback? onOpenFullScreen;

  @override
  State<LiveTripMap> createState() => _LiveTripMapState();
}

class _LiveTripMapState extends State<LiveTripMap> {
  GoogleMapController? _controller;

  /// Whether the camera keeps re-centering on the bus. On by default —
  /// a parent opening a live map wants the bus on screen — but any pan or
  /// pinch of their own switches it off so the map stops fighting them.
  bool _followBus = true;

  /// Set while *we* are the ones moving the camera, so the gesture
  /// detection above doesn't mistake our own recentering for a user pan.
  bool _selfDrivenCameraMove = false;

  /// The route has been framed once (bus + stop + school all in view);
  /// after that the camera only follows or obeys the controls.
  bool _hasFramedRoute = false;

  LatLng? _lastFollowTarget;

  final Map<String, BitmapDescriptor> _icons = {};
  final Set<String> _iconsBuilding = {};

  @override
  void initState() {
    super.initState();
    AppAnalytics.logTrackingOpened(tripId: widget.tripId);
  }

  @override
  void dispose() {
    try {
      _controller?.dispose();
    } catch (_) {
      // google_maps_flutter_web's controller.dispose() asserts
      // "Maps cannot be retrieved before calling buildView!" if this widget
      // is unmounted before the map's platform view finished attaching
      // (e.g. navigating away right after the map first appears, or a fast
      // reload while it's still initializing) — a real, reproducible crash
      // found during live QA that took down the entire page's widget-tree
      // teardown, not just this map. There is nothing to actually clean up
      // in that case, so swallowing it here is safe.
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Marker bitmaps
  // ---------------------------------------------------------------------

  /// Returns a cached custom marker, kicking off its rasterization the
  /// first time it's asked for. Returns null until that finishes, which
  /// callers fall back on with a built-in pin — so the map is never
  /// momentarily marker-less while a bitmap is being drawn.
  BitmapDescriptor? _cachedIcon(
    String key,
    Future<BitmapDescriptor> Function() build,
  ) {
    final cached = _icons[key];
    if (cached != null) return cached;
    if (_iconsBuilding.add(key)) unawaited(_buildIcon(key, build));
    return null;
  }

  Future<void> _buildIcon(
    String key,
    Future<BitmapDescriptor> Function() build,
  ) async {
    try {
      final icon = await build();
      if (!mounted) return;
      setState(() => _icons[key] = icon);
    } catch (_) {
      // A failed rasterization is not worth an error state: the map keeps
      // using the platform's default pin, which still shows the right
      // place. Clearing the guard lets a later rebuild retry.
      _iconsBuilding.remove(key);
    }
  }

  // ---------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------

  Future<void> _frameRoute(List<LatLng> points) async {
    final controller = _controller;
    if (controller == null || points.isEmpty) return;

    _selfDrivenCameraMove = true;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
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

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        48,
      ),
    );
  }

  /// Flips the follow mode from the on-map control, and snaps straight to
  /// the bus when turning it back on so the button visibly does something
  /// even if the next GPS tick is seconds away.
  void _toggleFollow(LatLng? busPoint) {
    setState(() => _followBus = !_followBus);
    if (_followBus && busPoint != null) {
      _lastFollowTarget = null;
      _followTo(busPoint);
    }
  }

  /// The parent panned or pinched the map themselves — stop yanking the
  /// camera back to the bus underneath their finger.
  void _releaseFollowForUserGesture() {
    if (_selfDrivenCameraMove || !_followBus) return;
    setState(() => _followBus = false);
  }

  void _followTo(LatLng target) {
    final controller = _controller;
    if (controller == null) return;
    if (_lastFollowTarget != null &&
        _lastFollowTarget!.latitude == target.latitude &&
        _lastFollowTarget!.longitude == target.longitude) {
      return;
    }
    _lastFollowTarget = target;
    _selfDrivenCameraMove = true;
    unawaited(controller.animateCamera(CameraUpdate.newLatLng(target)));
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!widget.student.hasLocation) {
      return _frame(
        child: EmptyStateView(
          compact: true,
          icon: Icons.location_off_outlined,
          title: const S(
            "Pickup point isn't set yet",
            'نقطة الاستلام لسه مش متحددة',
          ).of(context),
          message: const S(
            'Your school sets it from the Students tab — the live map '
                'turns on as soon as it does.',
            'المدرسة بتحددها من تبويب الطلاب — الخريطة المباشرة هتشتغل '
                'أول ما تتحدد.',
          ).of(context),
        ),
      );
    }

    final studentPoint = LatLng(
      widget.student.latitude!,
      widget.student.longitude!,
    );

    return StreamBuilder<School?>(
      stream: SchoolsRepository().watchSchool(widget.schoolId),
      builder: (context, schoolSnapshot) {
        final school = schoolSnapshot.data;
        final schoolPoint = school != null && school.hasLocation
            ? LatLng(school.latitude!, school.longitude!)
            : null;

        return StreamBuilder<TripStopProgress>(
          stream: StopOrderRepository().watchStopProgress(
            schoolId: widget.schoolId,
            tripId: widget.tripId,
          ),
          builder: (context, progressSnapshot) {
            final progress =
                progressSnapshot.data ?? const TripStopProgress();

            return StreamBuilder<DatabaseEvent>(
              stream: ParentTrackingRepository().watchTripLocation(
                schoolId: widget.schoolId,
                tripId: widget.tripId,
              ),
              builder: (context, locationSnapshot) {
                // A failed RTDB read leaves us exactly where a bus that
                // hasn't broadcast yet does: no position to reason from.
                // The map still has real geography to show (the stop and
                // the school), so it stays on screen and the status card
                // names the situation instead of the whole map vanishing.
                final busPosition = locationSnapshot.hasError
                    ? null
                    : LiveBusPosition.fromRtdbValue(
                        locationSnapshot.data?.snapshot.value,
                      );

                return _MapSurface(
                  state: this,
                  school: school,
                  schoolPoint: schoolPoint,
                  studentPoint: studentPoint,
                  progress: progress,
                  busPosition: busPosition,
                  locationUnavailable: locationSnapshot.hasError,
                );
              },
            );
          },
        );
      },
    );
  }

  /// The bordered, rounded surface every state of this widget lives in, so
  /// an empty state occupies the same slot the map would have.
  Widget _frame({required Widget child, bool padded = true}) {
    final colors = context.appColors;
    final content = widget.fillAvailableSpace
        ? SizedBox.expand(child: child)
        : SizedBox(height: widget.height, child: child);

    if (widget.fillAvailableSpace) return content;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: padded
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: content,
            )
          : content,
    );
  }
}

/// The map itself plus everything floating above it. Split out from
/// [_LiveTripMapState.build] purely so the four nested stream builders
/// above stay readable — it holds no state of its own and reads the
/// controller/camera flags straight off [state].
class _MapSurface extends StatelessWidget {
  const _MapSurface({
    required this.state,
    required this.school,
    required this.schoolPoint,
    required this.studentPoint,
    required this.progress,
    required this.busPosition,
    required this.locationUnavailable,
  });

  final _LiveTripMapState state;
  final School? school;
  final LatLng? schoolPoint;
  final LatLng studentPoint;
  final TripStopProgress progress;
  final LiveBusPosition? busPosition;
  final bool locationUnavailable;

  LiveTripMap get widget => state.widget;
  Student get student => widget.student;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final brightness = Theme.of(context).brightness;
    final primary = Theme.of(context).colorScheme.primary;

    final hasBoarded = progress.boardedStudents.contains(student.id);
    final hasBeenDroppedOff = progress.droppedOffStudents.contains(student.id);
    final ownStopDone = hasBoarded || hasBeenDroppedOff;

    final tripEta = computeParentTripEta(
      tripStatus: widget.tripStatus,
      progress: progress,
      student: student,
      school: school,
      busPosition: busPosition,
    );

    final busPoint = busPosition == null
        ? null
        : LatLng(busPosition!.latitude, busPosition!.longitude);
    final distanceToStudent = busPosition == null
        ? null
        : haversineMeters(
            busPosition!.latitude,
            busPosition!.longitude,
            studentPoint.latitude,
            studentPoint.longitude,
          );

    // The stops this parent may see, in their real `stopOrder` sequence —
    // the only honest basis for a line on this map.
    final orderedStops = _visibleStopsInOrder(studentPoint, schoolPoint);
    final framePoints = [...orderedStops, ?busPoint];

    final status = _resolveStatus(
      context,
      hasBoarded: hasBoarded,
      hasBeenDroppedOff: hasBeenDroppedOff,
      distanceToStudent: distanceToStudent,
      tripEta: tripEta,
      hasBusPosition: busPosition != null,
      locationUnavailable: locationUnavailable,
    );

    final stopState = hasBeenDroppedOff
        ? StopMarkerState.droppedOff
        : hasBoarded
        ? StopMarkerState.boarded
        : tripEta.eta.nextStopId == student.id
        ? StopMarkerState.next
        : StopMarkerState.pending;

    final stopColor = ownStopDone ? colors.success : primary;
    final stopIcon = state._cachedIcon(
      'stop|$brightness|$stopState|${tripEta.stopNumber}',
      () => MapMarkerIcons.stop(
        state: stopState,
        number: tripEta.stopNumber,
        color: stopColor,
        surface: colors.surface,
        devicePixelRatio: devicePixelRatio,
      ),
    );
    final schoolIcon = state._cachedIcon(
      'school|$brightness',
      () => MapMarkerIcons.school(
        color: colors.info,
        surface: colors.surface,
        devicePixelRatio: devicePixelRatio,
      ),
    );
    final busIcon = state._cachedIcon(
      'bus|$brightness',
      () => MapMarkerIcons.bus(
        color: primary,
        onColor: colors.surface,
        devicePixelRatio: devicePixelRatio,
      ),
    );

    final map = busPoint == null
        ? _buildMap(
            context,
            busPoint: null,
            animatedBus: null,
            orderedStops: orderedStops,
            framePoints: framePoints,
            stopIcon: stopIcon,
            schoolIcon: schoolIcon,
            busIcon: busIcon,
            stopState: stopState,
            tripEta: tripEta,
          )
        : TweenAnimationBuilder<LatLng>(
            // A new `end` on each GPS tick makes TweenAnimationBuilder
            // glide from wherever the marker currently sits to the new
            // fix, instead of the bus teleporting every few seconds.
            tween: _LatLngTween(begin: busPoint, end: busPoint),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (context, animatedBus, _) => _buildMap(
              context,
              busPoint: busPoint,
              animatedBus: animatedBus,
              orderedStops: orderedStops,
              framePoints: framePoints,
              stopIcon: stopIcon,
              schoolIcon: schoolIcon,
              busIcon: busIcon,
              stopState: stopState,
              tripEta: tripEta,
            ),
          );

    return state._frame(
      padded: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          map,
          // Top: the deviation notice, and only when the server says an
          // episode is genuinely open right now.
          PositionedDirectional(
            top: AppSpacing.sm,
            start: AppSpacing.sm,
            end: 56,
            child: _DeviationBanner(
              schoolId: widget.schoolId,
              tripId: widget.tripId,
            ),
          ),
          PositionedDirectional(
            top: AppSpacing.sm,
            end: AppSpacing.sm,
            child: _MapControls(
              followBus: state._followBus,
              canFollow: busPoint != null,
              onToggleFollow: () => state._toggleFollow(busPoint),
              onFitRoute: () => unawaited(state._frameRoute(framePoints)),
              onOpenFullScreen: widget.onOpenFullScreen,
            ),
          ),
          PositionedDirectional(
            start: AppSpacing.sm,
            end: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _StatusCard(
              status: status,
              updatedAt: busPosition?.updatedAt,
              speedMetersPerSecond: busPosition?.speedMetersPerSecond,
              distanceToStudentMeters: ownStopDone ? null : distanceToStudent,
            ),
          ),
        ],
      ),
    );
  }

  /// This child's own stop and the school, in the order today's real
  /// `stopOrder` puts them. Before the driver computes that order, the two
  /// points still have a known sequence — the bus goes to the pickup point
  /// and then to the school; that's the definition of the trip, not a
  /// guess about the stops in between.
  List<LatLng> _visibleStopsInOrder(LatLng studentPoint, LatLng? schoolPoint) {
    if (progress.stopOrder.isEmpty) {
      return [studentPoint, ?schoolPoint];
    }
    final points = <LatLng>[];
    for (final stopId in progress.stopOrder) {
      if (stopId == student.id) {
        points.add(studentPoint);
      } else if (stopId == schoolStopId && schoolPoint != null) {
        points.add(schoolPoint);
      }
      // Every other id belongs to another family's child — unreadable
      // here by design, so it contributes no point to the line.
    }
    // A stop order that somehow lists neither (e.g. this child is marked
    // absent today, so the driver's order skips their stop) still has the
    // child's own pickup point worth showing on the map.
    return points.isEmpty ? [studentPoint, ?schoolPoint] : points;
  }

  Widget _buildMap(
    BuildContext context, {
    required LatLng? busPoint,
    required LatLng? animatedBus,
    required List<LatLng> orderedStops,
    required List<LatLng> framePoints,
    required BitmapDescriptor? stopIcon,
    required BitmapDescriptor? schoolIcon,
    required BitmapDescriptor? busIcon,
    required StopMarkerState stopState,
    required ParentTripEta tripEta,
  }) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final routePolylinePoints = [
      for (final point in progress.routePolyline) LatLng(point.lat, point.lng),
    ];

    // Camera work is queued for after this frame — animateCamera during a
    // build would run against a controller that is mid-layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.mounted || state._controller == null) return;
      if (!state._hasFramedRoute) {
        state._hasFramedRoute = true;
        unawaited(state._frameRoute(framePoints));
      } else if (state._followBus && busPoint != null) {
        state._followTo(busPoint);
      }
    });

    final initialTarget = animatedBus ?? orderedStops.first;

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
      onMapCreated: (controller) {
        state._controller = controller;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!state.mounted) return;
          state._hasFramedRoute = true;
          unawaited(state._frameRoute(framePoints));
        });
      },
      onCameraMoveStarted: state._releaseFollowForUserGesture,
      onCameraIdle: () => state._selfDrivenCameraMove = false,
      markers: {
        if (animatedBus != null)
          Marker(
            markerId: const MarkerId('bus'),
            position: animatedBus,
            // The driver's own reported GPS heading — the bus bitmap is
            // drawn pointing north precisely so this can turn it.
            rotation: busPosition?.heading ?? 0,
            flat: true,
            anchor: const Offset(0.5, 0.5),
            icon:
                busIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
            zIndexInt: 3,
            infoWindow: InfoWindow(
              title: const S('School bus', 'أتوبيس المدرسة').of(context),
            ),
          ),
        Marker(
          markerId: const MarkerId('student'),
          position: LatLng(student.latitude!, student.longitude!),
          anchor: const Offset(0.5, 0.5),
          icon:
              stopIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          zIndexInt: 2,
          infoWindow: InfoWindow(
            title: student.name,
            snippet: tripEta.hasStopPosition
                ? S(
                    'Stop ${tripEta.stopNumber} of ${tripEta.totalStops}',
                    'المحطة ${tripEta.stopNumber} من ${tripEta.totalStops}',
                  ).of(context)
                : const S('Your pickup point', 'نقطة استلامك').of(context),
          ),
        ),
        if (schoolPoint != null)
          Marker(
            markerId: const MarkerId('school'),
            position: schoolPoint!,
            anchor: const Offset(0.5, 0.5),
            icon:
                schoolIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
            zIndexInt: 1,
            infoWindow: InfoWindow(
              title: school?.name.isNotEmpty == true
                  ? school!.name
                  : const S('School', 'المدرسة').of(context),
              snippet: const S(
                'Final stop on this trip',
                'آخر محطة في الرحلة',
              ).of(context),
            ),
          ),
      },
      polylines: {
        if (routePolylinePoints.length > 1)
          // The real road-following path (Feature: real route lines).
          // Trimmed to what's still ahead of the live bus position —
          // snapped onto the route's own vertices — so the road already
          // driven simply disappears (the Uber picture) instead of a
          // static line for the whole trip regardless of progress; a
          // straight line from the live GPS dot to the stop looked
          // jarring once the rest of the path started following actual
          // roads, so this finds the nearest point on that same road path
          // to the bus and continues from there instead of a bird's-eye
          // line cutting across blocks/rivers/highways.
          Polyline(
            polylineId: const PolylineId('route'),
            points: animatedBus != null && !_ownStopReached
                ? [
                    for (final point in remainingRoute(
                      progress.routePolyline,
                      (lat: animatedBus.latitude, lng: animatedBus.longitude),
                    ))
                      LatLng(point.lat, point.lng),
                  ]
                : routePolylinePoints,
            color: theme.colorScheme.primary.withValues(alpha: 0.75),
            width: 5,
            zIndex: 1,
          )
        else if (orderedStops.length > 1)
          // Fallback until the route is computed: the stop sequence
          // itself, dashed and described in the status card as the stop
          // order rather than "the route" — straight lines between real
          // stop coordinates, not the roads the bus will drive.
          Polyline(
            polylineId: const PolylineId('stop-order'),
            points: orderedStops,
            color: theme.colorScheme.primary.withValues(alpha: 0.45),
            width: 4,
            patterns: [PatternItem.dash(14), PatternItem.gap(9)],
          ),
      },
      circles: {
        // The proximity ring that the journey stage machine itself uses to
        // decide "arrived at your stop" — drawn so the parent can see the
        // same threshold the app is reasoning with.
        Circle(
          circleId: const CircleId('pickup-zone'),
          center: LatLng(student.latitude!, student.longitude!),
          radius: arrivedProximityMeters,
          fillColor: (_ownStopReached ? colors.success : theme.colorScheme.primary)
              .withValues(alpha: 0.08),
          strokeColor:
              (_ownStopReached ? colors.success : theme.colorScheme.primary)
                  .withValues(alpha: 0.30),
          strokeWidth: 1,
        ),
      },
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      // The floating status card sits over the bottom edge; nudging the
      // map's own padding keeps Google's attribution out from under it.
      padding: EdgeInsets.only(
        bottom: state.widget.fillAvailableSpace ? 108 : 92,
        top: 8,
      ),
    );
  }

  bool get _ownStopReached =>
      progress.boardedStudents.contains(student.id) ||
      progress.droppedOffStudents.contains(student.id);

  /// What the floating card says, in strict priority order: what already
  /// happened to *this* child beats any estimate; "the bus is here right
  /// now" beats a number of minutes; and when there's no reliable estimate
  /// the engine's own reason is shown rather than an empty space.
  _MapStatus _resolveStatus(
    BuildContext context, {
    required bool hasBoarded,
    required bool hasBeenDroppedOff,
    required double? distanceToStudent,
    required ParentTripEta tripEta,
    required bool hasBusPosition,
    required bool locationUnavailable,
  }) {
    final colors = context.appColors;

    if (hasBeenDroppedOff) {
      return _MapStatus(
        color: colors.success,
        icon: Icons.task_alt_rounded,
        title: S(
          '${student.name} was dropped off',
          '${student.name} نزل من الأتوبيس',
        ).of(context),
      );
    }
    if (hasBoarded) {
      final toSchool = tripEta.eta.nextStopId == schoolStopId
          ? tripEta.eta.etaToNextStop
          : null;
      return _MapStatus(
        color: colors.success,
        icon: Icons.check_circle_rounded,
        title: S(
          '${student.name} is on the bus',
          '${student.name} في الأتوبيس',
        ).of(context),
        detail: toSchool == null
            ? null
            : S(
                'At school in about ${formatEtaDuration(context, toSchool)}',
                'هيوصل المدرسة خلال ${formatEtaDuration(context, toSchool)} تقريبًا',
              ).of(context),
      );
    }

    if (widget.tripStatus == TripStatus.emergency) {
      return _MapStatus(
        color: colors.emergency,
        icon: Icons.warning_amber_rounded,
        title: const S(
          'Emergency reported on this trip',
          'اتبلّغ عن طوارئ في الرحلة دي',
        ).of(context),
        detail: const S(
          'Your school has been alerted and the bus is still being '
              'tracked here.',
          'المدرسة اتبلغت والأتوبيس لسه بيتتابع هنا.',
        ).of(context),
      );
    }
    if (widget.tripStatus == TripStatus.paused) {
      return _MapStatus(
        color: colors.warning,
        icon: Icons.pause_circle_rounded,
        title: const S('Trip paused', 'الرحلة متوقفة مؤقتًا').of(context),
        detail: const S(
          "The driver paused the trip — you'll see it move again here as "
              'soon as it resumes.',
          'السواق وقف الرحلة مؤقتًا — هتشوفها بتتحرك هنا تاني أول ما '
              'تكمل.',
        ).of(context),
      );
    }

    if (!hasBusPosition) {
      return _MapStatus(
        color: colors.info,
        icon: Icons.wifi_tethering_off_rounded,
        title: const S(
          'Waiting for the bus to send its location',
          'في انتظار الأتوبيس يبعت موقعه',
        ).of(context),
        detail: locationUnavailable
            ? const S(
                "We can't reach the live feed right now — your child's stop "
                    'and the school are still shown below.',
                'مش قادرين نوصل للبث المباشر دلوقتي — محطة طفلك والمدرسة '
                    'لسه ظاهرين تحت.',
              ).of(context)
            : const S(
                "The driver hasn't started broadcasting yet.",
                'السواق لسه ما بدأش يبث موقعه.',
              ).of(context),
      );
    }

    if (tripEta.eta.unavailableReason == EtaUnavailableReason.staleGps) {
      return _MapStatus(
        color: colors.warning,
        icon: Icons.gps_off_rounded,
        title: const S(
          'Live signal has dropped',
          'الإشارة المباشرة اتقطعت',
        ).of(context),
        detail: etaUnavailableText(
          EtaUnavailableReason.staleGps,
        ).of(context),
      );
    }

    if (distanceToStudent != null &&
        distanceToStudent < arrivedProximityMeters) {
      return _MapStatus(
        color: colors.success,
        icon: Icons.location_on_rounded,
        title: const S(
          'Bus is at your pickup point now',
          'الأتوبيس عند نقطة استلامك دلوقتي',
        ).of(context),
      );
    }

    final eta = tripEta.eta.etaToNextStop;
    if (eta != null) {
      return _MapStatus(
        color: colors.info,
        icon: Icons.directions_bus_rounded,
        title: S(
          'Bus is about ${formatEtaDuration(context, eta)} away',
          'الأتوبيس على بُعد ${formatEtaDuration(context, eta)} تقريبًا',
        ).of(context),
        detail: tripEta.hasStopPosition
            ? S(
                'Your stop is number ${tripEta.stopNumber} of '
                    '${tripEta.totalStops} on today’s route',
                'محطتك رقم ${tripEta.stopNumber} من ${tripEta.totalStops} '
                    'في خط النهاردة',
              ).of(context)
            : null,
      );
    }

    final reason = tripEta.eta.unavailableReason;
    return _MapStatus(
      color: reason == EtaUnavailableReason.allStopsCompleted
          ? colors.success
          : colors.info,
      icon: reason == EtaUnavailableReason.allStopsCompleted
          ? Icons.task_alt_rounded
          : Icons.directions_bus_rounded,
      title: reason == null
          ? const S(
              'No arrival estimate right now',
              'مفيش وقت وصول متوقع دلوقتي',
            ).of(context)
          : etaUnavailableText(reason).of(context),
    );
  }
}

/// One resolved line (or two) for the floating card, already localized.
class _MapStatus {
  const _MapStatus({
    required this.color,
    required this.icon,
    required this.title,
    this.detail,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? detail;
}

/// The card that floats over the bottom of the map. Kept to at most three
/// lines — headline, supporting detail, and a muted telemetry footnote —
/// because it is covering the map it's describing.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.updatedAt,
    required this.speedMetersPerSecond,
    required this.distanceToStudentMeters,
  });

  final _MapStatus status;
  final DateTime? updatedAt;
  final double? speedMetersPerSecond;
  final double? distanceToStudentMeters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final footnoteParts = <String>[
      if (distanceToStudentMeters != null)
        S(
          '${formatDistanceMeters(context, distanceToStudentMeters!)} away',
          'على بُعد ${formatDistanceMeters(context, distanceToStudentMeters!)}',
        ).of(context),
      if (updatedAt != null)
        S(
          'Updated ${TimeOfDay.fromDateTime(updatedAt!).format(context)}',
          'آخر تحديث ${TimeOfDay.fromDateTime(updatedAt!).format(context)}',
        ).of(context),
      if (speedMetersPerSecond != null && speedMetersPerSecond! >= 0.5)
        S(
          '${(speedMetersPerSecond! * 3.6).round()} km/h',
          '${(speedMetersPerSecond! * 3.6).round()} كم/س',
        ).of(context),
    ];

    return AnimatedContainer(
      duration: AppDurations.stateSwitch,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: status.color.withValues(alpha: 0.30)),
        boxShadow: AppShadows.level2(Colors.black),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(status.icon, size: 20, color: status.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (status.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    status.detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                if (footnoteParts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    footnoteParts.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The stacked camera controls. Each is a real action on real state — the
/// follow toggle reflects (and flips) whether the camera is tracking the
/// bus, and is disabled outright while there is no bus position to follow
/// rather than sitting there looking tappable.
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.followBus,
    required this.canFollow,
    required this.onToggleFollow,
    required this.onFitRoute,
    required this.onOpenFullScreen,
  });

  final bool followBus;
  final bool canFollow;
  final VoidCallback onToggleFollow;
  final VoidCallback onFitRoute;
  final VoidCallback? onOpenFullScreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(
          icon: followBus ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
          tooltip: followBus
              ? const S('Stop following the bus', 'وقف متابعة الأتوبيس').of(
                  context,
                )
              : const S('Follow the bus', 'تابع الأتوبيس').of(context),
          active: followBus && canFollow,
          onPressed: canFollow ? onToggleFollow : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MapControlButton(
          icon: Icons.zoom_out_map_rounded,
          tooltip: const S('Fit the whole trip', 'اعرض الرحلة كلها').of(
            context,
          ),
          onPressed: onFitRoute,
        ),
        if (onOpenFullScreen != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _MapControlButton(
            icon: Icons.open_in_full_rounded,
            tooltip: const S('Open full screen', 'افتح ملء الشاشة').of(context),
            onPressed: onOpenFullScreen,
          ),
        ],
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? primary.withValues(alpha: 0.16)
            : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              semanticLabel: tooltip,
              color: !enabled
                  ? colors.disabled
                  : active
                  ? primary
                  : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown only while the server-side deviation engine says this trip is
/// actually off its expected route (`deviation_started` or `deviating` on
/// `schools/{schoolId}/trips/{tripId}/deviation/current`). A closed episode
/// (`deviation_ended`), a normal one, or no document at all renders
/// nothing.
///
/// Wording is deliberately calm: a bus leaves its usual roads for ordinary
/// reasons — roadworks, a closed street, traffic being routed around — and
/// the tracking a parent is looking at keeps working throughout. Telling
/// them something is wrong would be both alarming and, most of the time,
/// untrue. It says what is observed and nothing more.
class _DeviationBanner extends StatelessWidget {
  const _DeviationBanner({required this.schoolId, required this.tripId});

  final String schoolId;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviationRecord?>(
      stream: DeviationRepository().watchCurrentDeviation(
        schoolId: schoolId,
        tripId: tripId,
      ),
      builder: (context, snapshot) {
        final deviation = snapshot.data;
        final isOffRoute =
            deviation != null &&
            (deviation.status == DeviationStatus.deviationStarted ||
                deviation.status == DeviationStatus.deviating);

        final colors = context.appColors;
        return AnimatedSwitcher(
          duration: AppDurations.stateSwitch,
          child: !isOffRoute
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.40),
                    ),
                    boxShadow: AppShadows.level1(Colors.black),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.alt_route_rounded,
                          color: colors.warning, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          const S(
                            'Bus is temporarily off its usual route — '
                                "you're still tracking it live. Your school "
                                'has been notified.',
                            'الأتوبيس خارج مساره المعتاد مؤقتًا — لسه '
                                'بتتابعه مباشر. والمدرسة اتبلغت.',
                          ).of(context),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng super.begin, required LatLng super.end});

  @override
  LatLng lerp(double t) {
    final b = begin!;
    final e = end!;
    return LatLng(
      b.latitude + (e.latitude - b.latitude) * t,
      b.longitude + (e.longitude - b.longitude) * t,
    );
  }
}
