import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/analytics.dart';
import '../../schools/data/schools_repository.dart';
import '../../trips/data/stop_order_repository.dart';
import '../../../widgets/async_error_view.dart';
import '../data/parent_tracking_repository.dart';
import '../domain/eta_calculator.dart';
import '../domain/live_bus_position.dart';

/// Live map of a trip in progress, personalized to one child: an animated
/// bus marker, a reference line from the child's pickup point to the
/// school, and ETAs to both. Deliberately shows only *this* child's pickup
/// point — firestore.rules only lets a parent read their own child's
/// student document, so other children on the same route aren't visible
/// here even in principle, and their homes shouldn't be anyway.
///
/// The GoogleMap widget is fully wired up — camera, markers, polyline, live
/// re-centering — backed by a real Maps API key in
/// android/app/src/main/AndroidManifest.xml and web/index.html.
class LiveTripMap extends StatefulWidget {
  const LiveTripMap({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.student,
  });

  final String schoolId;
  final String tripId;
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

        return StreamBuilder<List<String>>(
          stream: StopOrderRepository().watchStopOrder(
            schoolId: widget.schoolId,
            tripId: widget.tripId,
          ),
          builder: (context, orderSnapshot) {
            final order = orderSnapshot.data ?? const <String>[];
            final stopIndex = order.indexOf(widget.student.id);

            return StreamBuilder<Set<String>>(
              stream: StopOrderRepository().watchBoardedStudents(
                schoolId: widget.schoolId,
                tripId: widget.tripId,
              ),
              builder: (context, boardedSnapshot) {
                final hasBoarded =
                    boardedSnapshot.data?.contains(widget.student.id) ?? false;

                return StreamBuilder<DatabaseEvent>(
                  stream: ParentTrackingRepository().watchTripLocation(
                    schoolId: widget.schoolId,
                    tripId: widget.tripId,
                  ),
                  builder: (context, locationSnapshot) {
                    if (locationSnapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
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
                    final etaToStudent = estimateEta(
                      distanceMeters: distanceToStudent,
                      reportedSpeedMetersPerSecond: speed,
                    )!;

                    final colors = context.appColors;
                    final tone = hasBoarded
                        ? StatusTone.success
                        : StatusTone.info;
                    final toneColor = tone == StatusTone.success
                        ? colors.success
                        : colors.info;
                    final statusText = hasBoarded
                        ? S(
                            '${widget.student.name} boarded the bus',
                            '${widget.student.name} ركب الأتوبيس',
                          ).of(context)
                        : distanceToStudent < 100
                        ? const S(
                            'Bus is arriving at your pickup point now',
                            'الأتوبيس واصل نقطة استلامك دلوقتي',
                          ).of(context)
                        : stopIndex >= 0
                        ? S(
                            'ETA to your pickup point: '
                                '${_formatEta(context, etaToStudent)} · stop '
                                '${stopIndex + 1} of ${order.length}',
                            'الوقت المتوقع لنقطة استلامك: '
                                '${_formatEta(context, etaToStudent)} · محطة '
                                '${stopIndex + 1} من ${order.length}',
                          ).of(context)
                        : S(
                            'ETA to your pickup point: '
                                '${_formatEta(context, etaToStudent)}',
                            'الوقت المتوقع لنقطة استلامك: '
                                '${_formatEta(context, etaToStudent)}',
                          ).of(context);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                hasBoarded
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
                              tween: _LatLngTween(
                                begin: position,
                                end: position,
                              ),
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
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueAzure,
                                          ),
                                      zIndexInt: 1,
                                    ),
                                    Marker(
                                      markerId: const MarkerId('student'),
                                      position: studentPoint,
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
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

  String _formatEta(BuildContext context, Duration eta) {
    final minutes = eta.inMinutes;
    if (minutes < 1) {
      return const S('under 1 min', 'أقل من دقيقة').of(context);
    }
    if (minutes == 1) return const S('1 min', 'دقيقة واحدة').of(context);
    return S('$minutes min', '$minutes د').of(context);
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
