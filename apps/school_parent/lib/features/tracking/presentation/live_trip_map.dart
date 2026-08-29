import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/analytics.dart';
import '../../schools/data/schools_repository.dart';
import '../../trips/data/stop_order_repository.dart';
import '../../trips/domain/journey_stage.dart';
import '../../../widgets/async_error_view.dart';
import '../data/deviation_repository.dart';
import '../data/parent_tracking_repository.dart';
import '../domain/live_bus_position.dart';
import '../domain/parent_trip_eta.dart';
import 'eta_text.dart';

/// Live map of a trip in progress, personalized to one child: an animated
/// bus marker, a reference line from the child's pickup point to the
/// school, and an ETA from the shared engine. Deliberately shows only
/// *this* child's pickup point — firestore.rules only lets a parent read
/// their own child's student document, so other children on the same route
/// aren't visible here even in principle, and their homes shouldn't be
/// anyway.
///
/// The GoogleMap widget is fully wired up — camera, markers, polyline, live
/// re-centering — backed by a real Maps API key in
/// android/app/src/main/AndroidManifest.xml and web/index.html.
class LiveTripMap extends StatefulWidget {
  const LiveTripMap({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.tripStatus,
    required this.student,
  });

  final String schoolId;
  final String tripId;

  /// The ETA engine refuses to estimate for a trip that isn't running
  /// (returning [EtaUnavailableReason.tripNotActive] instead), so it needs
  /// the trip's own status — this map is also shown while a trip is
  /// starting, paused or in an emergency.
  final TripStatus tripStatus;

  final Student student;

  @override
  State<LiveTripMap> createState() => _LiveTripMapState();
}

class _LiveTripMapState extends State<LiveTripMap> {
  GoogleMapController? _controller;
  bool _hasFitBounds = false;

  @override
  void initState() {
    super.initState();
    AppAnalytics.logTrackingOpened(tripId: widget.tripId);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.student.hasLocation) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: EmptyStateView(
          compact: true,
          icon: Icons.location_off_outlined,
          title: const S(
            "Pickup point isn't set yet",
            'نقطة الاستلام لسه مش متحددة',
          ).of(context),
          message: const S(
            'Ask the school to add it from the Students tab.',
            'كلّم المدرسة تضيفها من تبويب الطلاب.',
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
            final hasBoarded = progress.boardedStudents.contains(
              widget.student.id,
            );
            final hasBeenDroppedOff = progress.droppedOffStudents.contains(
              widget.student.id,
            );

            return StreamBuilder<DatabaseEvent>(
              stream: ParentTrackingRepository().watchTripLocation(
                schoolId: widget.schoolId,
                tripId: widget.tripId,
              ),
              builder: (context, locationSnapshot) {
                if (locationSnapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: AsyncErrorView(compact: true),
                  );
                }

                final busPosition = LiveBusPosition.fromRtdbValue(
                  locationSnapshot.data?.snapshot.value,
                );
                if (busPosition == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: EmptyStateView(
                      compact: true,
                      icon: Icons.directions_bus_outlined,
                      title: const S(
                        'Waiting for the bus',
                        'في انتظار الأتوبيس',
                      ).of(context),
                      message: const S(
                        'The bus has not started broadcasting its '
                            'location yet.',
                        'الأتوبيس لسه ما بدأش يبث موقعه.',
                      ).of(context),
                    ),
                  );
                }

                final latitude = busPosition.latitude;
                final longitude = busPosition.longitude;
                final position = LatLng(latitude, longitude);
                final heading = busPosition.heading;
                final updatedAt = busPosition.updatedAt;
                final speed = busPosition.speedMetersPerSecond;

                final distanceToStudent = haversineMeters(
                  latitude,
                  longitude,
                  studentPoint.latitude,
                  studentPoint.longitude,
                );

                // The shared engine — the same one the driver and admin
                // apps use — instead of this screen's old straight-line
                // one-stop calculation, so every app quotes the same
                // number for the same trip and says the same thing when
                // it can't quote one at all.
                final tripEta = computeParentTripEta(
                  tripStatus: widget.tripStatus,
                  progress: progress,
                  student: widget.student,
                  school: school,
                  busPosition: busPosition,
                );

                final colors = context.appColors;
                final reachedOwnStop = hasBoarded || hasBeenDroppedOff;
                final tone = reachedOwnStop
                    ? StatusTone.success
                    : StatusTone.info;
                final toneColor = tone == StatusTone.success
                    ? colors.success
                    : colors.info;
                final statusText = _statusText(
                  context,
                  hasBoarded: hasBoarded,
                  hasBeenDroppedOff: hasBeenDroppedOff,
                  distanceToStudent: distanceToStudent,
                  tripEta: tripEta,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeviationBanner(
                      schoolId: widget.schoolId,
                      tripId: widget.tripId,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: toneColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            reachedOwnStop
                                ? Icons.check_circle
                                : Icons.directions_bus,
                            size: 18,
                            color: toneColor,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              statusText,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: SizedBox(
                        height: 220,
                        child: TweenAnimationBuilder<LatLng>(
                          tween: _LatLngTween(begin: position, end: position),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeInOut,
                          builder: (context, animatedPosition, child) {
                            if (!_hasFitBounds) {
                              _hasFitBounds = true;
                              WidgetsBinding.instance.addPostFrameCallback((
                                _,
                              ) {
                                _fitBounds(
                                  animatedPosition,
                                  studentPoint,
                                  schoolPoint,
                                );
                              });
                            } else {
                              _controller?.animateCamera(
                                CameraUpdate.newLatLng(animatedPosition),
                              );
                            }

                            return GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: animatedPosition,
                                zoom: 14,
                              ),
                              onMapCreated: (controller) =>
                                  _controller = controller,
                              markers: {
                                Marker(
                                  markerId: const MarkerId('bus'),
                                  position: animatedPosition,
                                  rotation: heading,
                                  flat: true,
                                  anchor: const Offset(0.5, 0.5),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueAzure,
                                  ),
                                  zIndexInt: 1,
                                ),
                                Marker(
                                  markerId: const MarkerId('student'),
                                  position: studentPoint,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueGreen,
                                  ),
                                  infoWindow: InfoWindow(
                                    title: widget.student.name,
                                  ),
                                ),
                                if (schoolPoint != null)
                                  Marker(
                                    markerId: const MarkerId('school'),
                                    position: schoolPoint,
                                    icon:
                                        BitmapDescriptor.defaultMarkerWithHue(
                                          BitmapDescriptor.hueOrange,
                                        ),
                                    infoWindow: const InfoWindow(
                                      title: 'School',
                                    ),
                                  ),
                              },
                              polylines: {
                                if (schoolPoint != null)
                                  Polyline(
                                    polylineId: const PolylineId(
                                      'reference-line',
                                    ),
                                    points: [studentPoint, schoolPoint],
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.5),
                                    width: 3,
                                    patterns: [
                                      PatternItem.dash(12),
                                      PatternItem.gap(8),
                                    ],
                                  ),
                              },
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Coordinates/speed are numeric and stay
                    // left-to-right even inside an Arabic layout, per
                    // design-system/MASTER.md §13.
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        'Lat ${latitude.toStringAsFixed(5)}, '
                        'Lng ${longitude.toStringAsFixed(5)}'
                        '${speed != null ? ' · ${speed.toStringAsFixed(1)} m/s' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    if (updatedAt != null)
                      Text(
                        S(
                          'Updated '
                              '${TimeOfDay.fromDateTime(updatedAt).format(context)}',
                          'آخر تحديث '
                              '${TimeOfDay.fromDateTime(updatedAt).format(context)}',
                        ).of(context),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// The one line at the top of the map. Order matters: what already
  /// happened to *this* child beats any estimate, "the bus is here right
  /// now" beats a number of minutes, and when there's no reliable estimate
  /// left the engine's own reason is shown rather than an empty space.
  String _statusText(
    BuildContext context, {
    required bool hasBoarded,
    required bool hasBeenDroppedOff,
    required double distanceToStudent,
    required ParentTripEta tripEta,
  }) {
    if (hasBoarded) {
      return S(
        '${widget.student.name} boarded the bus',
        '${widget.student.name} ركب الأتوبيس',
      ).of(context);
    }
    if (hasBeenDroppedOff) {
      return S(
        '${widget.student.name} was dropped off',
        '${widget.student.name} نزل من الأتوبيس',
      ).of(context);
    }
    if (distanceToStudent < arrivedProximityMeters) {
      return const S(
        'Bus is arriving at your pickup point now',
        'الأتوبيس واصل نقطة استلامك دلوقتي',
      ).of(context);
    }

    final eta = tripEta.eta.etaToNextStop;
    if (eta == null) {
      final reason = tripEta.eta.unavailableReason;
      return reason == null
          ? const S(
              "No arrival estimate right now",
              'مفيش وقت وصول متوقع دلوقتي',
            ).of(context)
          : etaUnavailableText(reason).of(context);
    }

    final formatted = formatEtaDuration(context, eta);
    if (!tripEta.hasStopPosition) {
      return S(
        'ETA to your pickup point: $formatted',
        'الوقت المتوقع لنقطة استلامك: $formatted',
      ).of(context);
    }
    return S(
      'ETA to your pickup point: $formatted · stop '
          '${tripEta.stopNumber} of ${tripEta.totalStops}',
      'الوقت المتوقع لنقطة استلامك: $formatted · محطة '
          '${tripEta.stopNumber} من ${tripEta.totalStops}',
    ).of(context);
  }

  void _fitBounds(
    LatLng busPosition,
    LatLng studentPoint,
    LatLng? schoolPoint,
  ) {
    final controller = _controller;
    if (controller == null) return;

    final points = [busPosition, studentPoint, ?schoolPoint];
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
        48,
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
        if (!isOffRoute) return const SizedBox.shrink();

        final colors = context.appColors;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.warning.withValues(alpha: 0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.alt_route, color: colors.warning, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(
                        label: const S(
                          'Off usual route',
                          'خارج المسار المعتاد',
                        ).of(context),
                        tone: StatusTone.warning,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        const S(
                          'The bus is temporarily off its usual route — '
                              "you're still tracking it live below. Your "
                              'school has been notified.',
                          'الأتوبيس خارج مساره المعتاد مؤقتًا — لسه بتتابعه '
                              'مباشر تحت. والمدرسة اتبلغت.',
                        ).of(context),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
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
